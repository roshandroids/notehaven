/// In-memory fakes of both ports, for tests and demos. Pure Dart, no test
/// framework import, so Flutter tests can use it too.
library;

import 'notehaven_sync.dart';

/// Fake server with a monotonically increasing change sequence as its cursor.
///
/// Failure switches let tests simulate outages, rejected notes and a push
/// whose response is lost after the server already stored the note.
class FakeRemoteNoteStore implements RemoteNoteStore {
  final Map<String, ({SyncNote note, int seq})> _items = {};
  int _seq = 0;

  /// Every call fails with a network error while true.
  bool offline = false;

  /// The next push fails (before storing) with this error, once.
  RemoteException? failNextPush;

  /// The next push is stored, then the response is "lost" (network error).
  bool loseNextPushResponse = false;

  /// Pushes of these ids are rejected.
  final Set<String> rejectIds = {};

  /// Called after a push is stored, before its response returns.
  void Function(SyncNote stored)? onPushStored;

  /// Number of push calls received.
  int pushCalls = 0;

  /// Server-side view of a note, or null.
  SyncNote? get(String id) => _items[id]?.note;

  /// Current change sequence (the cursor after the last change).
  int get sequence => _seq;

  /// Writes a note directly on the server (as if another device pushed it).
  void seed(SyncNote note) {
    _items[note.id] = (note: note, seq: ++_seq);
  }

  @override
  Future<PullPage> pull({String? cursor, int limit = 100}) async {
    if (offline) {
      throw const RemoteException(RemoteFailureKind.network, 'offline');
    }
    final after = int.tryParse(cursor ?? '') ?? 0;
    final changed = _items.values.where((e) => e.seq > after).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final page = changed.take(limit).toList();
    return PullPage(
      items: [for (final e in page) e.note],
      nextCursor: page.isEmpty ? cursor : page.last.seq.toString(),
      hasMore: changed.length > page.length,
    );
  }

  @override
  Future<SyncNote> push(SyncNote note) async {
    if (offline) {
      throw const RemoteException(RemoteFailureKind.network, 'offline');
    }
    pushCalls++;
    final fail = failNextPush;
    if (fail != null) {
      failNextPush = null;
      throw fail;
    }
    if (rejectIds.contains(note.id)) {
      throw const RemoteException(RemoteFailureKind.rejected, 'invalid note');
    }
    final existing = _items[note.id]?.note;
    // Idempotent and newer-wins; a tie keeps the server copy.
    final SyncNote winner;
    if (existing != null &&
        existing.updatedAt.millisecondsSinceEpoch >=
            note.updatedAt.millisecondsSinceEpoch) {
      winner = existing;
    } else {
      winner = note;
      _items[note.id] = (note: note, seq: ++_seq);
    }
    onPushStored?.call(winner);
    if (loseNextPushResponse) {
      loseNextPushResponse = false;
      throw const RemoteException(RemoteFailureKind.network, 'response lost');
    }
    return winner;
  }
}

/// Queue-and-notes store with the same rules the Drift store must follow.
class InMemoryLocalSyncStore implements LocalSyncStore {
  final Map<String, ({SyncNote note, int rev})> _rows = {};
  final Map<String, int> _attempts = {}; // insertion order = queue order
  String? _cursor;

  /// The local copy of a note, or null.
  SyncNote? note(String id) => _rows[id]?.note;

  /// Whether [id] waits in the queue.
  bool isQueued(String id) => _attempts.containsKey(id);

  int get queuedCount => _attempts.length;

  /// Last saved cursor.
  String? get cursor => _cursor;

  /// A local create/update: bumps the revision and queues the note.
  void write(SyncNote note) {
    final rev = (_rows[note.id]?.rev ?? 0) + 1;
    _rows[note.id] = (note: note, rev: rev);
    _attempts[note.id] = 0;
  }

  @override
  Future<List<PendingChange>> pendingChanges({required int limit}) async {
    final ids = _attempts.keys.toList()
      ..sort((a, b) => _attempts[a]!.compareTo(_attempts[b]!));
    return [
      for (final id in ids.take(limit))
        PendingChange(note: _rows[id]!.note, rev: _rows[id]!.rev),
    ];
  }

  @override
  Future<void> markPushed(String id, int pushedRev, SyncNote stored) async {
    final row = _rows[id];
    if (row == null || row.rev != pushedRev) return;
    _attempts.remove(id);
    if (stored != row.note) {
      _rows[id] = (note: stored, rev: row.rev + 1);
    }
  }

  @override
  Future<void> recordFailure(String id, String message) async {
    final current = _attempts[id];
    if (current != null) _attempts[id] = current + 1;
  }

  @override
  Future<String?> readCursor() async => _cursor;

  @override
  Future<void> applyPulled(List<SyncNote> remote, String? cursor) async {
    for (final r in remote) {
      final local = _rows[r.id];
      if (resolveConflict(local: local?.note, remote: r) ==
          ConflictResolution.applyRemote) {
        _rows[r.id] = (note: r, rev: (local?.rev ?? 0) + 1);
        _attempts.remove(r.id);
      }
    }
    _cursor = cursor;
  }
}
