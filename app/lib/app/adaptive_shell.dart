import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/notes/presentation/notes_screen.dart';
import '../shared/layout/layout.dart';

/// Wraps the notes routes. Narrow windows show one screen at a time; wide
/// windows (see [splitViewMinWidth]) keep the list on the left and show the
/// routed screen (editor or placeholder) on the right.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({required this.state, required this.child, super.key});

  final GoRouterState state;
  final Widget child;

  /// Note id when the location is `/notes/<id>` (including `new`), else null.
  String? get _selectedId {
    final segments = state.uri.pathSegments;
    return segments.length == 2 && segments.first == 'notes'
        ? segments[1]
        : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!isSplitView(context)) return child;
    return Row(
      children: [
        SizedBox(
          width: listPaneWidth,
          child: NotesScreen(selectedId: _selectedId),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: child),
      ],
    );
  }
}

/// Right-hand pane when no note is open in split view.
class SelectNotePlaceholder extends StatelessWidget {
  const SelectNotePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 72,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('Select a note', style: theme.textTheme.titleMedium),
            const Text('or press Ctrl/Cmd+N to write a new one.'),
          ],
        ),
      ),
    );
  }
}
