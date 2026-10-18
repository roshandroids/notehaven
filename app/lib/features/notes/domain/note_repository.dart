import 'package:notehaven_core/notehaven_core.dart';

import 'note.dart';

/// Source of truth for notes. Implementations live in `data/`.
abstract interface class NoteRepository {
  /// Notes, newest first.
  Future<Result<List<Note>>> list();

  /// Adds a note; fails with [ValidationFailure] if [title] is blank.
  Future<Result<Note>> add(String title);
}
