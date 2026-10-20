import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_settings.dart';
import '../domain/notes_maintenance.dart';
import '../domain/settings_repository.dart';

/// Bound in `app/bootstrap.dart` (or test overrides).
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('Override settingsRepositoryProvider'),
);

/// Bulk note operations used by the "Delete all notes" tile; bound in
/// `app/bootstrap.dart` so Settings never imports the notes feature.
final notesMaintenanceProvider = Provider<NotesMaintenance>(
  (ref) => throw UnimplementedError('Override notesMaintenanceProvider'),
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

  void setHaptics(bool value) => _update(state.copyWith(hapticsEnabled: value));

  void setSounds(bool value) => _update(state.copyWith(soundsEnabled: value));

  void setMotion(MotionPreference value) =>
      _update(state.copyWith(motion: value));

  void setTextScale(double value) => _update(state.copyWith(textScale: value));

  /// Pass null to follow the system language.
  void setLocale(String? code) => _update(
    code == null
        ? state.copyWith(clearLocale: true)
        : state.copyWith(localeCode: code),
  );

  void _update(AppSettings next) {
    state = next;
    ref.read(settingsRepositoryProvider).save(next);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
