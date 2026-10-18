/// Light/dark preference, independent of Flutter's `ThemeMode`.
enum ThemePreference { system, light, dark }

/// Follow the OS motion setting, or always reduce decorative animation.
enum MotionPreference { system, reduced }

/// User-chosen appearance. Pure data so `domain` stays Flutter-free.
class AppSettings {
  const AppSettings({
    this.themePreference = ThemePreference.system,
    this.schemeName = defaultSchemeName,
    this.fontFamily,
    this.hapticsEnabled = true,
    this.soundsEnabled = false,
    this.motion = MotionPreference.system,
  });

  /// `FlexScheme` enum name used until the user picks another.
  static const defaultSchemeName = 'indigo';

  final ThemePreference themePreference;

  /// Name of a `FlexScheme` value (mapped in `presentation`).
  final String schemeName;

  /// A Google Fonts family, or null for the platform default font.
  final String? fontFamily;

  /// Vibration feedback; no effect on platforms without haptics.
  final bool hapticsEnabled;

  /// UI sounds; off until the user opts in.
  final bool soundsEnabled;

  final MotionPreference motion;

  /// Pass `clearFont: true` to go back to the platform default font.
  AppSettings copyWith({
    ThemePreference? themePreference,
    String? schemeName,
    String? fontFamily,
    bool clearFont = false,
    bool? hapticsEnabled,
    bool? soundsEnabled,
    MotionPreference? motion,
  }) => AppSettings(
    themePreference: themePreference ?? this.themePreference,
    schemeName: schemeName ?? this.schemeName,
    fontFamily: clearFont ? null : (fontFamily ?? this.fontFamily),
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    soundsEnabled: soundsEnabled ?? this.soundsEnabled,
    motion: motion ?? this.motion,
  );
}
