import 'package:flutter_riverpod/misc.dart';

import '../features/notes/data/in_memory_note_repository.dart';
import '../features/notes/presentation/note_providers.dart';

/// Composition root: the only place that binds interfaces to implementations.
///
/// Phase 1 replaces the in-memory repository with Drift + sync.
final List<Override> productionOverrides = [
  noteRepositoryProvider.overrideWithValue(InMemoryNoteRepository()),
];
