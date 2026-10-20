import 'package:flutter/foundation.dart';

import '../../domain/drawing.dart';

/// Pen, translucent highlighter, or whole-stroke eraser.
enum DrawingTool { pen, highlighter, eraser }

/// Editing state for one drawing: strokes, the stroke being drawn, the current
/// tool, and undo/redo as snapshots of the stroke list (strokes are immutable,
/// so a snapshot is just a list of references).
class DrawingController extends ChangeNotifier {
  DrawingController([Drawing initial = Drawing.empty])
    : _aspectRatio = initial.aspectRatio,
      _history = [List.unmodifiable(initial.strokes)];

  double _aspectRatio;

  /// Canvas width / height; fixed once the first stroke is drawn.
  double get aspectRatio => _aspectRatio;

  /// Lets a brand-new drawing take the shape of the screen. Ignored once any
  /// stroke exists, because stored points are relative to the ratio.
  void adoptAspectRatio(double ratio) {
    if (_history.length > 1 || strokes.isNotEmpty) return;
    _aspectRatio = ratio.clamp(0.5, 2.2);
  }

  /// Most undo steps kept.
  static const maxHistory = 100;

  /// Eraser radius in canvas-width units.
  static const eraserRadius = 0.02;

  /// Palette stored as absolute ARGB values.
  static const palette = <int>[
    0xFF000000,
    0xFFD32F2F,
    0xFF1976D2,
    0xFF388E3C,
    0xFFF57C00,
    0xFF7B1FA2,
  ];

  final List<List<DrawingStroke>> _history;
  var _index = 0;
  List<double>? _activePoints;

  DrawingTool _tool = DrawingTool.pen;
  int _color = palette.first;
  double _width = 0.006;

  DrawingTool get tool => _tool;
  int get color => _color;

  /// Pen width as a fraction of the canvas width.
  double get width => _width;

  void selectTool(DrawingTool value) {
    if (value != DrawingTool.eraser) _lastDrawTool = value;
    _tool = value;
    notifyListeners();
  }

  DrawingTool _lastDrawTool = DrawingTool.pen;

  /// Apple Pencil tap / squeeze: flips between the eraser and the last pen.
  void toggleEraser() => selectTool(
    _tool == DrawingTool.eraser ? _lastDrawTool : DrawingTool.eraser,
  );

  /// Picks a pen color; leaves the eraser for the pen.
  void selectColor(int argb) {
    _color = argb;
    if (_tool == DrawingTool.eraser) _tool = DrawingTool.pen;
    notifyListeners();
  }

  void setWidth(double value) {
    _width = value;
    notifyListeners();
  }

  List<DrawingStroke> get strokes => _history[_index];
  bool get canUndo => _index > 0;
  bool get canRedo => _index < _history.length - 1;

  /// The stroke being drawn right now, or null.
  DrawingStroke? get activeStroke {
    final points = _activePoints;
    if (points == null || tool == DrawingTool.eraser) return null;
    return _make(points);
  }

  Drawing get drawing => Drawing(aspectRatio: aspectRatio, strokes: strokes);

  DrawingStroke _make(List<double> points) {
    final highlighter = tool == DrawingTool.highlighter;
    return DrawingStroke(
      color: color,
      width: highlighter ? width * 3 : width,
      points: points,
      highlighter: highlighter,
    );
  }

  /// Starts a stroke (or erases) at a point given as fractions of the canvas.
  void start(double x, double y) {
    if (tool == DrawingTool.eraser) {
      _activePoints = [];
      _eraseAt(x, y);
    } else {
      _activePoints = [x, y];
    }
    notifyListeners();
  }

  /// Extends the current stroke (or keeps erasing).
  void extend(double x, double y) {
    final points = _activePoints;
    if (points == null) return;
    if (tool == DrawingTool.eraser) {
      _eraseAt(x, y);
    } else {
      points
        ..add(x)
        ..add(y);
    }
    notifyListeners();
  }

  /// Finishes the stroke: simplifies it and records one undo step.
  void end() {
    final points = _activePoints;
    _activePoints = null;
    _erasing = false;
    if (points == null) return;
    if (tool != DrawingTool.eraser && points.isNotEmpty) {
      final single = points.length == 2 ? [...points, ...points] : points;
      final simplified = Drawing.simplify(single, aspectRatio);
      _push([...strokes, _make(simplified)]);
    }
    notifyListeners();
  }

  /// Aborts a stroke in progress without recording it.
  void cancel() {
    _activePoints = null;
    _erasing = false;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _index--;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _index++;
    notifyListeners();
  }

  /// Removes every stroke (undoable).
  void clear() {
    if (strokes.isEmpty) return;
    _push(const []);
    notifyListeners();
  }

  void _push(List<DrawingStroke> next) {
    _history
      ..removeRange(_index + 1, _history.length)
      ..add(List.unmodifiable(next));
    if (_history.length > maxHistory) _history.removeAt(0);
    _index = _history.length - 1;
  }

  /// Erases whole strokes touched by the eraser at (x, y).
  void _eraseAt(double x, double y) {
    final remaining = [
      for (final s in strokes)
        if (!_hits(s, x, y)) s,
    ];
    if (remaining.length == strokes.length) return;
    // One undo step per erase gesture: replace the pending snapshot if this
    // gesture already added one.
    if (_erasing) {
      _history[_index] = List.unmodifiable(remaining);
    } else {
      _push(remaining);
      _erasing = true;
    }
  }

  var _erasing = false;

  bool _hits(DrawingStroke s, double x, double y) {
    final reach = eraserRadius + s.width / 2;
    final px = x;
    final py = y / aspectRatio;
    final p = s.points;
    if (p.length == 2) {
      return Drawing.distanceToSegment(
            px,
            py,
            p[0],
            p[1] / aspectRatio,
            p[0],
            p[1] / aspectRatio,
          ) <=
          reach;
    }
    for (var i = 0; i + 3 < p.length; i += 2) {
      final d = Drawing.distanceToSegment(
        px,
        py,
        p[i],
        p[i + 1] / aspectRatio,
        p[i + 2],
        p[i + 3] / aspectRatio,
      );
      if (d <= reach) return true;
    }
    return false;
  }
}
