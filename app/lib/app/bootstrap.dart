import 'package:flutter_riverpod/misc.dart';

import '../core/database/app_database.dart';
import '../features/notes/data/drift_note_repository.dart';
import '../features/notes/presentation/note_providers.dart';
import '../features/settings/data/prefs_settings_repository.dart';
import '../features/settings/presentation/settings_providers.dart';

/// Composition root: the only place that binds interfaces to implementations.
///
/// Settings are read from disk before the first frame so the saved theme and
/// font apply immediately. The database lives for the whole process, so it is
/// never closed explicitly.
Future<List<Override>> productionOverrides() async => [
  noteRepositoryProvider.overrideWithValue(
    DriftNoteRepository(AppDatabase.open()),
  ),
  settingsRepositoryProvider.overrideWithValue(
    await PrefsSettingsRepository.open(),
  ),
];
