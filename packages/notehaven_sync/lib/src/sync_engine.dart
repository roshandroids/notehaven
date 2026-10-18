import 'dart:async';

import 'local_sync_store.dart';
import 'remote_note_store.dart';

/// Result of one [SyncEngine.syncOnce] run.
class SyncReport {
  const SyncReport({
    this.pushed = 0,
    this.pulled = 0,
    this.rejected = 0,
    this.error,
  });

  final int pushed;
  final int pulled;

  /// Notes the server refused (they stay queued and are retried later).
  final int rejected;

  /// Why the run stopped early, or null when it finished.
  final Object? error;

  bool get ok => error == null;
}

/// Pushes local changes, then pulls remote ones. One run at a time.
///
/// Push goes first so a local delete is not undone by an older remote copy.
/// Idempotent pushes plus a server-issued cursor make every step safe to
/// retry after a crash or a lost response.
class SyncEngine {
  SyncEngine({
    required this._local,
    required this._remote,
    this.pageSize = 100,
  });

  final LocalSyncStore _local;
  final RemoteNoteStore _remote;
  final int pageSize;

  Future<SyncReport>? _running;

  /// Runs a sync, or joins the one already in progress.
  Future<SyncReport> syncOnce() => _running ??= _run().whenComplete(() {
    _running = null;
  });

  Future<SyncReport> _run() async {
    var pushed = 0;
    var pulled = 0;
    var rejected = 0;
    try {
      // Push phase. A note the server rejected is skipped for the rest of this
      // run so it neither blocks the others nor is counted twice.
      final rejectedIds = <String>{};
      var progressed = true;
      while (progressed) {
        progressed = false;
        final batch = await _local.pendingChanges(limit: pageSize);
        for (final change in batch) {
          if (rejectedIds.contains(change.note.id)) continue;
          try {
            final stored = await _remote.push(change.note);
            await _local.markPushed(change.note.id, change.rev, stored);
            pushed++;
            progressed = true;
          } on RemoteException catch (e) {
            if (e.kind != RemoteFailureKind.rejected) rethrow;
            await _local.recordFailure(change.note.id, e.message);
            rejectedIds.add(change.note.id);
            rejected++;
          }
        }
      }

      // Pull phase.
      var cursor = await _local.readCursor();
      while (true) {
        final page = await _remote.pull(cursor: cursor, limit: pageSize);
        final next = page.nextCursor ?? cursor;
        if (page.hasMore && next == cursor) {
          throw const RemoteException(
            RemoteFailureKind.server,
            'server reported more pages but did not advance the cursor',
          );
        }
        await _local.applyPulled(page.items, next);
        pulled += page.items.length;
        cursor = next;
        if (!page.hasMore) break;
      }
    } on Object catch (e) {
      return SyncReport(
        pushed: pushed,
        pulled: pulled,
        rejected: rejected,
        error: e,
      );
    }
    return SyncReport(pushed: pushed, pulled: pulled, rejected: rejected);
  }
}
