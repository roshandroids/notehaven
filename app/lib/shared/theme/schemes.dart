import 'package:flex_color_scheme/flex_color_scheme.dart';

/// Maps a stored scheme name to a [FlexScheme]; unknown names fall back to
/// the default so a stale preference never crashes the app.
FlexScheme flexSchemeFor(String name) {
  final scheme = FlexScheme.values.asNameMap()[name];
  return scheme == null || scheme == FlexScheme.custom
      ? FlexScheme.indigo
      : scheme;
}
