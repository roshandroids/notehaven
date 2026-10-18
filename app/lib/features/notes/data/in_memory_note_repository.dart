import 'package:notehaven_core/notehaven_core.dart';

import '../domain/note.dart';
import '../domain/note_repository.dart';

/// Placeholder repository (memory only). Replaced by Drift in Phase 1.
class InMemoryNoteRepository implements NoteRepository {
  final List<Note> _entries = [];

  @override
  Future<Result<List<Note>>> list() async =>
      Ok(List.unmodifiable(_entries.reversed));

  @override
  Future<Result<Note>> add(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return const Err(ValidationFailure('Title is empty'));
    final entry = Note(
      id: '${_entries.length + 1}',
      title: trimmed,
      createdAt: DateTime.now(),
    );
    _entries.add(entry);
    return Ok(entry);
  }
}
