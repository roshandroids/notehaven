import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/notes/presentation/notes_screen.dart';
import '../shared/layout/layout.dart';
import '../shared/widgets/illustration.dart';
import '../l10n/l10n.dart';

/// Wraps the notes routes. Narrow windows show one screen at a time; wide
/// windows (see [splitViewMinWidth]) keep the list on the left and show the
/// routed screen (editor or placeholder) on the right.
class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({required this.state, required this.child, super.key});

  final GoRouterState state;
  final Widget child;

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  // shortcut: width resets on restart; persist it in settings if wanted.
  double _paneWidth = listPaneWidth;

  /// Note id when the location is `/notes/<id>` (including `new`), else null.
  String? get _selectedId {
    final segments = widget.state.uri.pathSegments;
    return segments.length == 2 && segments.first == 'notes'
        ? segments[1]
        : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!isSplitView(context)) return widget.child;
    return Row(
      children: [
        SizedBox(
          width: _paneWidth,
          child: NotesScreen(selectedId: _selectedId),
        ),
        // Drag to resize the list pane; the editor keeps at least 400 px.
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (d) => setState(
              () => _paneWidth = (_paneWidth + d.delta.dx).clamp(
                260.0,
                MediaQuery.sizeOf(context).width - 400,
              ),
            ),
            child: const SizedBox(
              width: 8,
              child: VerticalDivider(width: 8, indent: 0),
            ),
          ),
        ),
        // Own messenger: a shared one shows each snackbar in both Scaffolds.
        Expanded(child: ScaffoldMessenger(child: widget.child)),
      ],
    );
  }
}

/// Right-hand pane when no note is open in split view.
class SelectNotePlaceholder extends StatelessWidget {
  const SelectNotePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IllustratedMessage(
        kind: IllustrationKind.select,
        title: context.l10n.selectNote,
        subtitle: context.l10n.selectNoteHint,
      ),
    );
  }
}
