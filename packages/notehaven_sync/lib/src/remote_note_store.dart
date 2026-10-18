import 'sync_note.dart';

/// Why a remote call failed; decides whether the engine retries.
enum RemoteFailureKind {
  /// Offline, timeout or DNS failure. Retry later.
  network,

  /// 401/403. Retry after the token is refreshed.
  auth,

  /// 5xx or an unreadable response. Retry later.
  server,

  /// The server refused this one note (validation). Other notes continue.
  rejected,
}

/// Failure reported by a [RemoteNoteStore].
class RemoteException implements Exception {
  const RemoteException(this.kind, this.message);

  final RemoteFailureKind kind;
  final String message;

  @override
  String toString() => 'RemoteException(${kind.name}: $message)';
}

/// One page of remote changes, oldest first.
class PullPage {
  const PullPage({required this.items, this.nextCursor, this.hasMore = false});

  /// Changed notes, including tombstones.
  final List<SyncNote> items;

  /// Opaque server-issued position to pass to the next pull. Never a client
  /// timestamp (device clocks drift). Null means "unchanged".
  final String? nextCursor;

  final bool hasMore;
}

/// The only thing a backend must implement. No SDK types cross this line, so
/// Supabase, Firebase, a REST API or a file share can all sit behind it.
abstract interface class RemoteNoteStore {
  /// Changes after [cursor] (null = from the beginning), at most [limit].
  /// Throws [RemoteException].
  Future<PullPage> pull({String? cursor, int limit = 100});

  /// Stores [note] (create or update, keyed by `note.id`) and returns the
  /// version the server now holds. Must be idempotent: sending the same note
  /// twice changes nothing. If the server already holds a newer version it
  /// returns that one instead. Throws [RemoteException].
  Future<SyncNote> push(SyncNote note);
}
