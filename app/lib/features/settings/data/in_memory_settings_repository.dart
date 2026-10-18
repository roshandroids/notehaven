import 'package:notehaven_core/notehaven_core.dart';

import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

/// Memory-only [SettingsRepository] for tests and previews.
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([this.settings = const AppSettings()]);

  /// Last saved value; tests assert on it.
  AppSettings settings;

  @override
  AppSettings load() => settings;

  @override
  Future<Result<void>> save(AppSettings s) async {
    settings = s;
    return const Ok(null);
  }
}
