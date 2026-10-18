import 'package:notehaven_core/notehaven_core.dart';

import 'note.dart';

/// Source of truth for notes. Implementations live in `data/`.
abstract interface class NoteRepository {
  /// Notes matching [query] (title or body, case-insensitive), newest edit
  /// first. Emits again whenever the notes change.
  Stream<Result<List<Note>>> watch({String query = ''});

  /// The note with [id], or null if it does not exist.
  Future<Result<Note?>> get(String id);

  /// Creates a note; fails with [ValidationFailure] if title and body are blank.
  Future<Result<Note>> create(String title, String body);

  /// Saves changes to [note] and stamps a new `updatedAt`.
  Future<Result<Note>> update(Note note);

  /// Removes the note with [id]. Deleting a missing id succeeds.
  Future<Result<void>> delete(String id);

  /// Brings [note] back (used by "undo delete") with a fresh edit time, so the
  /// restore wins over the earlier delete when devices sync.
  Future<Result<void>> restore(Note note);
}
