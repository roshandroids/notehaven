/// Single home for design constants. Colors live in the theme
/// (`app_theme.dart`); shapes, spacing and timing live here so every screen
/// moves and rounds the same way.
library;

/// Corner radii.
abstract final class AppRadius {
  static const double card = 14;
  static const double field = 16;
  static const double sheet = 24;
}

/// Spacing scale.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
}

/// Animation durations.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}
