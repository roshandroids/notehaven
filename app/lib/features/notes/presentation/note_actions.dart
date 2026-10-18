import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notehaven_core/notehaven_core.dart';

import '../domain/note.dart';
import '../domain/note_repository.dart';
import 'note_providers.dart';

/// Write operations used by screens. Each returns the failure to show, or
/// null on success.
class NoteActions {
  NoteActions(this._repository);

  final NoteRepository _repository;

  /// Creates a note, or updates [existing] when given. [body] is the plain-text
  /// mirror; [content] is the rich document (null for an empty one).
  Future<Failure?> save({
    Note? existing,
    required String title,
    required String body,
    String? content,
  }) async {
    final result = existing == null
        ? await _repository.create(title, body, content: content)
        : await _repository.update(
            existing.copyWith(
              title: title.trim(),
              body: body,
              content: content,
              clearContent: content == null,
            ),
          );
    return result.fold<Failure?>((_) => null, (f) => f);
  }

  /// Creates a copy of [note] titled "<title> (copy)".
  Future<Failure?> duplicate(Note note) async {
    final title = note.title.isEmpty ? 'Untitled' : note.title;
    final result = await _repository.create(
      '$title (copy)',
      note.body,
      content: note.content,
    );
    return result.fold<Failure?>((_) => null, (f) => f);
  }

  /// Deletes the note with [id].
  Future<Failure?> delete(String id) async =>
      (await _repository.delete(id)).fold<Failure?>((_) => null, (f) => f);

  /// Deletes every note (soft delete, so it syncs) and returns them for undo.
  Future<List<Note>> deleteAll() async {
    final notes = (await _repository.watch().first).fold(
      (list) => list,
      (_) => <Note>[],
    );
    for (final n in notes) {
      await _repository.delete(n.id);
    }
    return notes;
  }

  /// Puts a deleted [note] back unchanged.
  Future<Failure?> restore(Note note) async =>
      (await _repository.restore(note)).fold<Failure?>((_) => null, (f) => f);
}

final noteActionsProvider = Provider<NoteActions>(
  (ref) => NoteActions(ref.watch(noteRepositoryProvider)),
);
