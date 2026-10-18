import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/feedback/ui_feedback.dart';
import '../../../../shared/layout/layout.dart';
import '../../domain/drawing.dart';
import 'drawing_controller.dart';
import 'drawing_painter.dart';
import 'pencil_channel.dart';

/// Opens the drawing editor above everything (covering the split-view shell).
/// Resolves to the drawing when saved, or null when cancelled. Saving with no
/// strokes returns an empty drawing, which callers treat as "remove".
Future<Drawing?> openDrawingEditor(BuildContext context, [Drawing? initial]) =>
    Navigator.of(context, rootNavigator: true).push<Drawing>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DrawingEditorScreen(initial: initial),
      ),
    );

/// Full-screen sketch pad: pen, highlighter, stroke eraser, colors, width,
/// undo/redo and clear.
class DrawingEditorScreen extends ConsumerStatefulWidget {
  const DrawingEditorScreen({this.initial, super.key});

  final Drawing? initial;

  @override
  ConsumerState<DrawingEditorScreen> createState() =>
      _DrawingEditorScreenState();
}

class _DrawingEditorScreenState extends ConsumerState<DrawingEditorScreen> {
  late final DrawingController _controller = DrawingController(
    widget.initial ?? Drawing.empty,
  );
  int? _pointer;

  /// Once a stylus is seen, finger touches stop drawing (palm rejection).
  bool _stylusSeen = false;
  final _focus = FocusNode();

  UiFeedback get _feedback => ref.read(feedbackProvider);

  @override
  void initState() {
    super.initState();
    PencilChannel.attach(() {
      _feedback.play(FeedbackEvent.select);
      _controller.toggleEraser();
    });
  }

  @override
  void dispose() {
    PencilChannel.detach();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final drawing = _controller.drawing;
    if (!drawing.fitsSizeLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This drawing is too large to save. Erase or simplify some strokes.',
          ),
        ),
      );
      return;
    }
    _feedback.play(FeedbackEvent.success);
    Navigator.of(context).pop(drawing);
  }

  void _undo() {
    _feedback.play(FeedbackEvent.undo);
    _controller.undo();
  }

  void _redo() {
    _feedback.play(FeedbackEvent.undo);
    _controller.redo();
  }

  /// Clears everything, with a snackbar to bring it back (clear is one undo step).
  void _clear() {
    _feedback.play(FeedbackEvent.delete);
    _controller.clear();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Drawing cleared'),
          persist: false,
          action: SnackBarAction(label: 'Undo', onPressed: _undo),
        ),
      );
  }

  Future<void> _confirmDiscard() async {
    _feedback.play(FeedbackEvent.warning);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep drawing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _pointerDown(PointerDownEvent e, Size size) {
    if (e.kind == PointerDeviceKind.stylus) _stylusSeen = true;
    if (_stylusSeen && e.kind == PointerDeviceKind.touch) return;
    if (_pointer != null) return; // ignore extra fingers / palm
    _pointer = e.pointer;
    final p = _normalize(e.localPosition, size);
    _feedback.play(FeedbackEvent.strokeStart);
    _controller.start(p.dx, p.dy);
  }

  void _pointerMove(PointerMoveEvent e, Size size) {
    if (e.pointer != _pointer) return;
    final p = _normalize(e.localPosition, size);
    _controller.extend(p.dx, p.dy);
  }

  void _pointerUp(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (e is PointerCancelEvent) {
      _controller.cancel();
    } else {
      _feedback.play(FeedbackEvent.strokeEnd);
      _controller.end();
    }
  }

  Offset _normalize(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  void _tool(DrawingTool t) {
    _feedback.play(FeedbackEvent.select);
    _controller.selectTool(t);
  }

  void _nudgeWidth(double d) =>
      _controller.setWidth((_controller.width + d).clamp(0.002, 0.03));

  /// Keyboard / Pencil-keyboard shortcuts, shown in the tooltips.
  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        _redo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        _redo,
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
    const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
    const SingleActivator(LogicalKeyboardKey.keyP): () =>
        _tool(DrawingTool.pen),
    const SingleActivator(LogicalKeyboardKey.keyH): () =>
        _tool(DrawingTool.highlighter),
    const SingleActivator(LogicalKeyboardKey.keyE): _controller.toggleEraser,
    const SingleActivator(LogicalKeyboardKey.bracketLeft): () =>
        _nudgeWidth(-0.002),
    const SingleActivator(LogicalKeyboardKey.bracketRight): () =>
        _nudgeWidth(0.002),
    for (var i = 0; i < DrawingController.palette.length; i++)
      SingleActivator(
        LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
      ): () =>
          _controller.selectColor(DrawingController.palette[i]),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return PopScope(
          canPop: !_controller.canUndo,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmDiscard();
          },
          child: CallbackShortcuts(
            bindings: _shortcuts,
            child: Focus(
              focusNode: _focus,
              autofocus: true,
              child: Scaffold(
                backgroundColor: scheme.surfaceContainerLow,
                appBar: AppBar(
                  leading: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  title: const Text('Drawing'),
                  actions: [
                    IconButton.outlined(
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo),
                      onPressed: _controller.canUndo ? _undo : null,
                    ),
                    IconButton.outlined(
                      tooltip: 'Redo',
                      icon: const Icon(Icons.redo),
                      onPressed: _controller.canRedo ? _redo : null,
                    ),
                    IconButton.outlined(
                      tooltip: 'Clear drawing',
                      icon: const Icon(Icons.delete_sweep_outlined),
                      onPressed: _controller.strokes.isEmpty ? null : _clear,
                    ),
                    IconButton.filled(
                      tooltip: 'Save drawing',
                      icon: const Icon(Icons.check),
                      onPressed: _save,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                floatingActionButton: _ToolFab(
                  controller: _controller,
                  feedback: _feedback,
                ),
                // The whole body is the page: a new drawing takes its shape.
                body: LayoutBuilder(
                  builder: (context, box) {
                    if (widget.initial == null || widget.initial!.isEmpty) {
                      _controller.adoptAspectRatio(
                        box.maxWidth / box.maxHeight,
                      );
                    }
                    return Center(
                      child: AspectRatio(
                        aspectRatio: _controller.aspectRatio,
                        child: _Canvas(
                          controller: _controller,
                          onDown: _pointerDown,
                          onMove: _pointerMove,
                          onUp: _pointerUp,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.controller,
    required this.onDown,
    required this.onMove,
    required this.onUp,
  });

  final DrawingController controller;
  final void Function(PointerDownEvent, Size) onDown;
  final void Function(PointerMoveEvent, Size) onMove;
  final void Function(PointerEvent) onUp;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Drawing canvas. Freehand drawing needs a touch screen, pen or mouse.',
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          return Listener(
            key: const Key('drawing-canvas'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => onDown(e, size),
            onPointerMove: (e) => onMove(e, size),
            onPointerUp: onUp,
            onPointerCancel: onUp,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: drawingPaper),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: CommittedStrokesPainter(controller.strokes),
                    ),
                  ),
                  CustomPaint(painter: ActiveStrokePainter(controller)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Speed-dial FAB: shows the current tool and color; tapping fans out the
/// tools, colors and width, like the Apple Pencil palette.
class _ToolFab extends StatefulWidget {
  const _ToolFab({required this.controller, required this.feedback});

  final DrawingController controller;
  final UiFeedback feedback;

  @override
  State<_ToolFab> createState() => _ToolFabState();
}

class _ToolFabState extends State<_ToolFab> {
  bool _open = false;

  /// Color and width popups, shown by tapping the already-active tool.
  bool _options = false;

  static const _icons = {
    DrawingTool.pen: (Icons.edit, 'Pen'),
    DrawingTool.highlighter: (Icons.highlight, 'Highlighter'),
    DrawingTool.eraser: (
      Icons.cleaning_services_outlined,
      'Eraser (removes whole strokes)',
    ),
  };

  void _toggle() {
    widget.feedback.play(FeedbackEvent.tap);
    setState(() {
      _open = !_open;
      _options = false;
    });
  }

  Widget _reveal(BuildContext context, int i, Widget child) =>
      reduceMotion(context)
      ? child
      : child
            .animate(delay: (40 * i).ms)
            .fadeIn(duration: 160.ms)
            .slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack)
            .scale(begin: const Offset(0.8, 0.8));

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    final (icon, _) = _icons[c.tool]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open && _options) ...[
          _reveal(
            context,
            3,
            Card(
              elevation: 3,
              color: scheme.surface.withValues(alpha: 0.95),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 220,
                  child: Semantics(
                    label: 'Pen width',
                    child: Slider(
                      min: 0.002,
                      max: 0.03,
                      value: c.width,
                      onChanged: c.setWidth,
                      onChangeEnd: (_) =>
                          widget.feedback.play(FeedbackEvent.select),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _reveal(
            context,
            2,
            Card(
              elevation: 3,
              color: scheme.surface.withValues(alpha: 0.95),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final color in DrawingController.palette)
                      _Swatch(
                        argb: color,
                        selected: c.color == color,
                        onTap: () {
                          widget.feedback.play(FeedbackEvent.select);
                          c.selectColor(color);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_open) ...[
          for (final (i, t) in DrawingTool.values.reversed.indexed) ...[
            _reveal(
              context,
              i,
              FloatingActionButton.small(
                heroTag: 'tool-${t.name}',
                tooltip: _icons[t]!.$2,
                backgroundColor: c.tool == t
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHigh,
                foregroundColor: c.tool == t
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface,
                onPressed: () {
                  widget.feedback.play(FeedbackEvent.select);
                  final again = c.tool == t && t != DrawingTool.eraser;
                  c.selectTool(t);
                  setState(() => _options = again && !_options);
                },
                child: Icon(_icons[t]!.$1),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        FloatingActionButton(
          heroTag: 'tool-main',
          tooltip: _open ? 'Hide tools' : 'Drawing tools',
          onPressed: _toggle,
          child: AnimatedSwitcher(
            duration: 200.ms,
            transitionBuilder: (w, a) => RotationTransition(
              turns: Tween(begin: 0.75, end: 1.0).animate(a),
              child: FadeTransition(opacity: a, child: w),
            ),
            child: _open
                ? const Icon(Icons.close, key: ValueKey('close'))
                : Stack(
                    key: const ValueKey('tool'),
                    alignment: Alignment.center,
                    children: [
                      Icon(icon),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(c.color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.onPrimaryContainer,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.argb,
    required this.selected,
    required this.onTap,
  });

  final int argb;
  final bool selected;
  final VoidCallback onTap;

  static const _names = {
    0xFF000000: 'black',
    0xFFD32F2F: 'red',
    0xFF1976D2: 'blue',
    0xFF388E3C: 'green',
    0xFFF57C00: 'orange',
    0xFF7B1FA2: 'purple',
  };

  @override
  Widget build(BuildContext context) {
    final color = Color(argb);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color ${_names[argb] ?? 'custom'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: selected ? 32 : 26,
              height: selected ? 32 : 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: selected ? 3 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
