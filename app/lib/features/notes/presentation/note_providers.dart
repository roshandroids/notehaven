import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/note.dart';
import '../domain/note_repository.dart';

/// Bound to a concrete repository in `app/bootstrap.dart` (or test overrides).
final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => throw UnimplementedError('Override noteRepositoryProvider'),
);

/// Text typed into the search bar on the notes list.
class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  /// Replaces the current query.
  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);

/// Live list of notes matching [searchQueryProvider]; errors surface as
/// `AsyncError` carrying the `Failure`.
final notesProvider = StreamProvider.autoDispose<List<Note>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref
      .watch(noteRepositoryProvider)
      .watch(query: query)
      .map((r) => r.fold<List<Note>>((notes) => notes, (f) => throw f));
});

/// One note by id for the editor; null if missing.
final noteProvider = FutureProvider.autoDispose.family<Note?, String>((
  ref,
  id,
) async {
  final result = await ref.watch(noteRepositoryProvider).get(id);
  return result.fold<Note?>((note) => note, (f) => throw f);
});
