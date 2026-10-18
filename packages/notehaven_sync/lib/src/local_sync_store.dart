import 'sync_note.dart';

/// A local note waiting to be pushed, with the revision it had when read.
class PendingChange {
  const PendingChange({required this.note, required this.rev});

  final SyncNote note;

  /// Local write counter. [LocalSyncStore.markPushed] only clears the queue
  /// entry if the note is still at this revision (no edit during the push).
  final int rev;
}

/// What the engine needs from local storage. The app implements it on Drift;
/// tests use an in-memory version.
///
/// Contract: every local create/update/delete/restore bumps the note's
/// revision and queues it in the same transaction as the change (at most one
/// queue entry per note id). Applying remote data never queues anything.
abstract interface class LocalSyncStore {
  /// Queued notes, least-failed and oldest first, at most [limit].
  Future<List<PendingChange>> pendingChanges({required int limit});

  /// Records a successful push of [id] that was read at [pushedRev].
  ///
  /// In one transaction: if the note is still at [pushedRev], clear its queue
  /// entry and, when [stored] (the server's version) is newer than the local
  /// one, adopt it without queueing. If the note changed meanwhile, keep the
  /// entry so the newer edit is pushed next.
  Future<void> markPushed(String id, int pushedRev, SyncNote stored);

  /// Counts a rejected push so the entry sinks behind healthy ones.
  Future<void> recordFailure(String id, String message);

  /// Saved pull cursor, or null before the first pull.
  Future<String?> readCursor();

  /// In one transaction: apply [remote] notes using `resolveConflict`, clear
  /// the queue entry of every note the remote version replaced, and save
  /// [cursor].
  Future<void> applyPulled(List<SyncNote> remote, String? cursor);
}
