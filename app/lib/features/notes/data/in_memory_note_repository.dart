import 'dart:async';

import 'package:notehaven_core/notehaven_core.dart';

import '../domain/note.dart';
import '../domain/note_repository.dart';

/// Memory-only [NoteRepository] for tests and previews.
class InMemoryNoteRepository implements NoteRepository {
  final Map<String, Note> _notes = {};
  final Set<void Function()> _listeners = {};

  List<Note> _snapshot(String query) {
    final q = query.trim().toLowerCase();
    final list =
        _notes.values
            .where(
              (n) =>
                  q.isEmpty ||
                  n.title.toLowerCase().contains(q) ||
                  n.body.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  void _notify() {
    for (final l in [..._listeners]) {
      l();
    }
  }

  @override
  Stream<Result<List<Note>>> watch({String query = ''}) {
    late final StreamController<Result<List<Note>>> controller;
    void emit() => controller.add(Ok(_snapshot(query)));
    controller = StreamController(
      onListen: () {
        _listeners.add(emit);
        emit();
      },
      onCancel: () => _listeners.remove(emit),
    );
    return controller.stream;
  }

  @override
  Future<Result<Note?>> get(String id) async => Ok(_notes[id]);

  @override
  Future<Result<Note>> create(String title, String body) async {
    final invalid = Note.validate(title, body);
    if (invalid != null) return Err(invalid);
    final note = Note.create(title, body);
    _notes[note.id] = note;
    _notify();
    return Ok(note);
  }

  @override
  Future<Result<Note>> update(Note note) async {
    final invalid = Note.validate(note.title, note.body);
    if (invalid != null) return Err(invalid);
    final updated = note.copyWith(updatedAt: DateTime.now());
    _notes[note.id] = updated;
    _notify();
    return Ok(updated);
  }

  @override
  Future<Result<void>> delete(String id) async {
    _notes.remove(id);
    _notify();
    return const Ok(null);
  }

  @override
  Future<Result<void>> restore(Note note) async {
    _notes[note.id] = note;
    _notify();
    return const Ok(null);
  }
}
