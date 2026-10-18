import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/note_repository.dart';

/// Bound to a concrete repository in `app/bootstrap.dart` (or test overrides).
final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => throw UnimplementedError('Override noteRepositoryProvider'),
);
