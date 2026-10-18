import 'sync_note.dart';

/// Outcome of comparing a pulled note with the local copy.
enum ConflictResolution { applyRemote, keepLocal }

/// Last-write-wins on [SyncNote.updatedAt]; a tie goes to the remote copy
/// (the server is the arbiter, so every device converges on its choice).
///
/// A [local] of null means the note is new to this device.
ConflictResolution resolveConflict({
  required SyncNote? local,
  required SyncNote remote,
}) {
  if (local == null) return ConflictResolution.applyRemote;
  return remote.updatedAt.millisecondsSinceEpoch >=
          local.updatedAt.millisecondsSinceEpoch
      ? ConflictResolution.applyRemote
      : ConflictResolution.keepLocal;
}
