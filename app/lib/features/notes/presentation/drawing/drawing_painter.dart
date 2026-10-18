import 'package:flutter/material.dart';

import '../../domain/drawing.dart';
import 'drawing_controller.dart';

/// Paper color. Fixed (not themed) so absolute pen colors stay readable in
/// dark mode.
const drawingPaper = Color(0xFFFFFFFF);

/// Paints one [stroke] scaled to [size].
void paintStroke(Canvas canvas, Size size, DrawingStroke stroke) {
  final p = stroke.points;
  if (p.length < 2) return;
  final color = Color(
    stroke.color,
  ).withValues(alpha: stroke.highlighter ? 0.35 : 1);
  final width = stroke.width * size.width;
  if (p.length < 4) {
    canvas.drawCircle(
      Offset(p[0] * size.width, p[1] * size.height),
      width / 2,
      Paint()..color = color,
    );
    return;
  }
  final path = Path()..moveTo(p[0] * size.width, p[1] * size.height);
  for (var i = 2; i + 1 < p.length; i += 2) {
    path.lineTo(p[i] * size.width, p[i + 1] * size.height);
  }
  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width,
  );
}

/// Finished strokes. Repaints only when the stroke list changes, and sits in
/// its own repaint boundary so drawing a new stroke never repaints it.
class CommittedStrokesPainter extends CustomPainter {
  const CommittedStrokesPainter(this.strokes);

  final List<DrawingStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      paintStroke(canvas, size, s);
    }
  }

  @override
  bool shouldRepaint(CommittedStrokesPainter old) =>
      !identical(old.strokes, strokes);
}

/// The stroke being drawn; repaints on every pointer move.
class ActiveStrokePainter extends CustomPainter {
  ActiveStrokePainter(this.controller) : super(repaint: controller);

  final DrawingController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final s = controller.activeStroke;
    if (s != null) paintStroke(canvas, size, s);
  }

  @override
  bool shouldRepaint(ActiveStrokePainter old) => old.controller != controller;
}

/// Read-only preview of a [Drawing] at any size.
class DrawingThumbnail extends StatelessWidget {
  const DrawingThumbnail({required this.drawing, super.key});

  final Drawing drawing;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: drawing.aspectRatio,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: drawingPaper),
        child: RepaintBoundary(
          child: CustomPaint(painter: CommittedStrokesPainter(drawing.strokes)),
        ),
      ),
    );
  }
}
