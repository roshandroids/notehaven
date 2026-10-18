import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notehaven_core/notehaven_core.dart';

import '../domain/note.dart';
import 'note_providers.dart';

/// Holds the note list for [NotesScreen]; `add` refreshes it on success.
class NoteController extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() => _load();

  Future<List<Note>> _load() async {
    final result = await ref.read(noteRepositoryProvider).list();
    return result.fold((v) => v, (f) => throw f);
  }

  /// Returns the failure to show, or null on success.
  Future<Failure?> add(String title) async {
    final result = await ref.read(noteRepositoryProvider).add(title);
    switch (result) {
      case Err(:final failure):
        return failure;
      case Ok():
        final notes = await _load();
        if (ref.mounted) state = AsyncData(notes);
        return null;
    }
  }
}

final noteControllerProvider =
    AsyncNotifierProvider<NoteController, List<Note>>(NoteController.new);
