/// Bulk note operations offered from Settings ("Delete all notes").
///
/// Settings must not import the notes feature, so this port is declared here
/// and bound to a notes-backed implementation in the composition root.
abstract interface class NotesMaintenance {
  /// Soft-deletes every note and returns how many were removed.
  Future<int> deleteAll();

  /// Restores the notes removed by the most recent [deleteAll].
  Future<void> undoDeleteAll();
}
