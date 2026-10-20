import 'package:flutter_riverpod/misc.dart';
import 'package:notehaven_sync/notehaven_sync.dart';

import '../core/database/app_database.dart';
import '../core/sync/drift_local_sync_store.dart';
import '../core/sync/sync_providers.dart';
import 'feedback_wiring.dart';
import 'notes_maintenance_wiring.dart';
import '../features/notes/data/drift_note_repository.dart';
import '../features/notes/presentation/note_providers.dart';
import '../features/settings/data/prefs_settings_repository.dart';
import '../features/settings/presentation/settings_providers.dart';

/// Composition root: the only place that binds interfaces to implementations.
///
/// Settings are read from disk before the first frame so the saved theme and
/// font apply immediately. The database lives for the whole process, so it is
/// never closed explicitly.
///
/// Sync is off unless a [remote] is given. To enable it, pass any
/// [RemoteNoteStore], for example
/// `RestRemoteNoteStore(baseUrl: ..., client: http.Client(), headers: ...)`
/// from `notehaven_sync_rest`. See `documentation/sync_protocol.md`.
Future<List<Override>> productionOverrides({RemoteNoteStore? remote}) async {
  final db = AppDatabase.open();
  final overrides = <Override>[
    feedbackPrefsOverride,
    notesMaintenanceOverride,
    noteRepositoryProvider.overrideWithValue(DriftNoteRepository(db)),
    settingsRepositoryProvider.overrideWithValue(
      await PrefsSettingsRepository.open(),
    ),
  ];
  if (remote != null) {
    final scheduler = SyncScheduler(
      SyncEngine(local: DriftLocalSyncStore(db), remote: remote),
    );
    // Any change to the outbox (a local write) asks for a debounced sync. The
    // subscription lives as long as the process, like the database.
    db.select(db.outboxTable).watch().listen((rows) {
      if (rows.isNotEmpty) scheduler.requestSync();
    });
    scheduler.start();
    overrides.add(syncSchedulerProvider.overrideWithValue(scheduler));
  }
  return overrides;
}
