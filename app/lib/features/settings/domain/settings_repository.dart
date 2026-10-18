import 'package:notehaven_core/notehaven_core.dart';

import 'app_settings.dart';

/// Persists [AppSettings]. Reads are synchronous so the first frame already
/// uses the saved theme (no flash of the default theme).
abstract interface class SettingsRepository {
  /// Saved settings, or defaults when nothing is saved.
  AppSettings load();

  /// Persists [settings].
  Future<Result<void>> save(AppSettings settings);
}
