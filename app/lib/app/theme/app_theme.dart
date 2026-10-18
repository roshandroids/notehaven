import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/settings/domain/app_settings.dart';
import '../../features/settings/presentation/settings_providers.dart';

/// Light and dark [ThemeData] for one [AppSettings] value.
class AppThemes {
  const AppThemes({required this.light, required this.dark});

  final ThemeData light;
  final ThemeData dark;
}

/// Maps a stored scheme name to a [FlexScheme]; unknown names fall back to
/// the default so a stale preference never crashes the app.
FlexScheme flexSchemeFor(String name) {
  final scheme = FlexScheme.values.asNameMap()[name];
  return scheme == null || scheme == FlexScheme.custom
      ? FlexScheme.indigo
      : scheme;
}

/// Builds both themes from [settings]. Fonts that are not Google Fonts fall
/// back to the platform default.
AppThemes buildThemes(AppSettings settings) {
  final scheme = flexSchemeFor(settings.schemeName);
  final font = settings.fontFamily;
  final useFont = font != null && GoogleFonts.asMap().containsKey(font);

  // Keep-style minimal chrome: flat bars, outlined cards, no tint or shadow.
  ThemeData minimal(ThemeData base) => base.copyWith(
    appBarTheme: const AppBarTheme(
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: base.colorScheme.outlineVariant),
      ),
    ),
    dividerTheme: const DividerThemeData(space: 1, thickness: 0.5),
  );

  ThemeData withFont(ThemeData base) => minimal(
    useFont
        ? base.copyWith(
            textTheme: GoogleFonts.getTextTheme(font, base.textTheme),
            primaryTextTheme: GoogleFonts.getTextTheme(
              font,
              base.primaryTextTheme,
            ),
          )
        : base,
  );

  return AppThemes(
    light: withFont(FlexThemeData.light(scheme: scheme, useMaterial3: true)),
    dark: withFont(FlexThemeData.dark(scheme: scheme, useMaterial3: true)),
  );
}

/// Built once per settings change and cached by Riverpod, so unrelated
/// rebuilds never recompute themes.
final appThemesProvider = Provider<AppThemes>(
  (ref) => buildThemes(ref.watch(settingsProvider)),
);

/// Flutter [ThemeMode] for the current preference.
final themeModeProvider = Provider<ThemeMode>(
  (ref) =>
      switch (ref.watch(settingsProvider.select((s) => s.themePreference))) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
);
