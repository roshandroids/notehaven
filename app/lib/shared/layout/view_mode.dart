import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Grid (staggered cards) or one-column list on the notes pane.
///
/// Shared because the notes list renders it and Settings toggles it.
// shortcut: lives for the session only, persist it in settings if it should survive restarts.
class GridViewMode extends Notifier<bool> {
  @override
  bool build() => true;

  /// Flips between grid and list.
  void toggle() => state = !state;
}

/// True for the staggered grid, false for the one-column list.
final gridViewProvider = NotifierProvider<GridViewMode, bool>(GridViewMode.new);
