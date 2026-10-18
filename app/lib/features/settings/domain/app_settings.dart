/// Light/dark preference, independent of Flutter's `ThemeMode`.
enum ThemePreference { system, light, dark }

/// User-chosen appearance. Pure data so `domain` stays Flutter-free.
class AppSettings {
  const AppSettings({
    this.themePreference = ThemePreference.system,
    this.schemeName = defaultSchemeName,
    this.fontFamily,
  });

  /// `FlexScheme` enum name used until the user picks another.
  static const defaultSchemeName = 'indigo';

  final ThemePreference themePreference;

  /// Name of a `FlexScheme` value (mapped in `presentation`).
  final String schemeName;

  /// A Google Fonts family, or null for the platform default font.
  final String? fontFamily;

  /// Pass `clearFont: true` to go back to the platform default font.
  AppSettings copyWith({
    ThemePreference? themePreference,
    String? schemeName,
    String? fontFamily,
    bool clearFont = false,
  }) => AppSettings(
    themePreference: themePreference ?? this.themePreference,
    schemeName: schemeName ?? this.schemeName,
    fontFamily: clearFont ? null : (fontFamily ?? this.fontFamily),
  );
}
