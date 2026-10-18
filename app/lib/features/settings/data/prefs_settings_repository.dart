import 'package:notehaven_core/notehaven_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

/// [SettingsRepository] on `SharedPreferencesWithCache` (in-memory cache,
/// so [load] is synchronous after the one-time bootstrap `create`).
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  /// Opens the preferences store; call once during bootstrap.
  static Future<PrefsSettingsRepository> open() async =>
      PrefsSettingsRepository(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(),
        ),
      );

  static const _themeKey = 'theme_preference';
  static const _schemeKey = 'scheme_name';
  static const _fontKey = 'font_family';

  final SharedPreferencesWithCache _prefs;

  @override
  AppSettings load() {
    final theme = ThemePreference.values
        .asNameMap()[_prefs.getString(_themeKey)];
    return AppSettings(
      themePreference: theme ?? ThemePreference.system,
      schemeName: _prefs.getString(_schemeKey) ?? AppSettings.defaultSchemeName,
      fontFamily: _prefs.getString(_fontKey),
    );
  }

  @override
  Future<Result<void>> save(AppSettings s) async {
    try {
      await _prefs.setString(_themeKey, s.themePreference.name);
      await _prefs.setString(_schemeKey, s.schemeName);
      final font = s.fontFamily;
      if (font == null) {
        await _prefs.remove(_fontKey);
      } else {
        await _prefs.setString(_fontKey, font);
      }
      return const Ok(null);
    } on Object catch (e) {
      return Err(StorageFailure('$e'));
    }
  }
}
