import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

/// Bound in `app/bootstrap.dart` (or test overrides).
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('Override settingsRepositoryProvider'),
);

/// Current appearance settings; every setter updates the UI immediately and
/// then persists.
///
/// shortcut: a failed save is ignored (settings last for this session only);
/// surface it in the UI if persistence failures turn out to matter.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsRepositoryProvider).load();

  void setThemePreference(ThemePreference value) =>
      _update(state.copyWith(themePreference: value));

  void setScheme(String schemeName) =>
      _update(state.copyWith(schemeName: schemeName));

  /// Pass null for the platform default font.
  void setFont(String? family) => _update(
    family == null
        ? state.copyWith(clearFont: true)
        : state.copyWith(fontFamily: family),
  );

  void _update(AppSettings next) {
    state = next;
    ref.read(settingsRepositoryProvider).save(next);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
