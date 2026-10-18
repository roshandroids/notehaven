import 'package:flutter/material.dart';

import '../../domain/drawing.dart';
import 'drawing_controller.dart';
import 'drawing_painter.dart';

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
class DrawingEditorScreen extends StatefulWidget {
  const DrawingEditorScreen({this.initial, super.key});

  final Drawing? initial;

  @override
  State<DrawingEditorScreen> createState() => _DrawingEditorScreenState();
}

class _DrawingEditorScreenState extends State<DrawingEditorScreen> {
  late final DrawingController _controller = DrawingController(
    widget.initial ?? Drawing.empty,
  );
  int? _pointer;

  @override
  void dispose() {
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
    Navigator.of(context).pop(drawing);
  }

  Future<void> _confirmDiscard() async {
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
    if (_pointer != null) return; // ignore extra fingers / palm
    _pointer = e.pointer;
    final p = _normalize(e.localPosition, size);
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
    e is PointerCancelEvent ? _controller.cancel() : _controller.end();
  }

  Offset _normalize(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return PopScope(
          canPop: !_controller.canUndo,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmDiscard();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Drawing'),
              actions: [
                IconButton(
                  tooltip: 'Undo',
                  icon: const Icon(Icons.undo),
                  onPressed: _controller.canUndo ? _controller.undo : null,
                ),
                IconButton(
                  tooltip: 'Redo',
                  icon: const Icon(Icons.redo),
                  onPressed: _controller.canRedo ? _controller.redo : null,
                ),
                IconButton(
                  tooltip: 'Clear drawing',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: _controller.strokes.isEmpty
                      ? null
                      : _controller.clear,
                ),
                IconButton(
                  tooltip: 'Save drawing',
                  icon: const Icon(Icons.check),
                  onPressed: _save,
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: _Canvas(
                          controller: _controller,
                          onDown: _pointerDown,
                          onMove: _pointerMove,
                          onUp: _pointerUp,
                        ),
                      ),
                    ),
                  ),
                ),
                _Tools(controller: _controller),
              ],
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
      child: Material(
        elevation: 2,
        child: AspectRatio(
          aspectRatio: controller.aspectRatio,
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
        ),
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({required this.controller});

  final DrawingController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            SegmentedButton<DrawingTool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: DrawingTool.pen,
                  icon: Icon(Icons.edit),
                  tooltip: 'Pen',
                ),
                ButtonSegment(
                  value: DrawingTool.highlighter,
                  icon: Icon(Icons.highlight),
                  tooltip: 'Highlighter',
                ),
                ButtonSegment(
                  value: DrawingTool.eraser,
                  icon: Icon(Icons.cleaning_services_outlined),
                  tooltip: 'Eraser (removes whole strokes)',
                ),
              ],
              selected: {controller.tool},
              onSelectionChanged: (s) => controller.selectTool(s.first),
            ),
            Wrap(
              spacing: 4,
              children: [
                for (final c in DrawingController.palette)
                  _Swatch(
                    argb: c,
                    selected: controller.color == c,
                    onTap: () => controller.selectColor(c),
                  ),
              ],
            ),
            SizedBox(
              width: 180,
              child: Semantics(
                label: 'Pen width',
                child: Slider(
                  min: 0.002,
                  max: 0.03,
                  value: controller.width,
                  onChanged: controller.setWidth,
                ),
              ),
            ),
          ],
        ),
      ),
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
