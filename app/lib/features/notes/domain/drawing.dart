import 'dart:convert';
import 'dart:math' as math;

/// One pen stroke. Coordinates are fractions of the canvas (0..1 on both
/// axes) and [width] is a fraction of the canvas width, so a drawing looks the
/// same on a phone and in the desktop split view. [color] is a fixed ARGB int
/// (never a theme color), so a black pen stays visible in dark mode.
class DrawingStroke {
  const DrawingStroke({
    required this.color,
    required this.width,
    required this.points,
    this.highlighter = false,
  });

  final int color;
  final double width;

  /// Flat list `x0, y0, x1, y1, ...`.
  final List<double> points;

  /// Wide, translucent stroke.
  final bool highlighter;

  int get pointCount => points.length ~/ 2;
}

/// A freehand drawing with a versioned JSON format (`{"v":1,...}`).
///
/// Format v1: `{"v":1,"ar":<width/height>,"s":[{"c":argb,"w":w,"h":0|1,"p":[x,y,...]}]}`.
/// Points are rounded to 4 decimals and simplified, and the encoded size is
/// capped ([maxBytes]) because the drawing lives inside a note that is synced
/// and loaded in lists.
class Drawing {
  const Drawing({
    this.aspectRatio = defaultAspectRatio,
    this.strokes = const [],
  });

  /// Current format version.
  static const version = 1;

  /// Default canvas shape (width / height).
  static const defaultAspectRatio = 4 / 3;

  /// Largest encoded drawing accepted by the editor.
  static const maxBytes = 200 * 1024;

  /// Douglas-Peucker tolerance in width units (about 0.15% of the width).
  static const simplifyTolerance = 0.0015;

  static const empty = Drawing();

  /// Canvas width divided by height.
  final double aspectRatio;
  final List<DrawingStroke> strokes;

  bool get isEmpty => strokes.isEmpty;

  /// Parses a stored drawing, or returns null if it is damaged or from a newer
  /// format version (the note then shows a placeholder instead of crashing).
  static Drawing? tryParse(String source) {
    try {
      final json = jsonDecode(source);
      if (json is! Map || json['v'] != version) return null;
      final ar = (json['ar'] as num).toDouble();
      if (ar <= 0 || !ar.isFinite) return null;
      final strokes = <DrawingStroke>[];
      for (final raw in json['s'] as List) {
        final s = raw as Map;
        final points = [for (final p in s['p'] as List) (p as num).toDouble()];
        if (points.length.isOdd) return null;
        strokes.add(
          DrawingStroke(
            color: s['c'] as int,
            width: (s['w'] as num).toDouble(),
            points: points,
            highlighter: s['h'] == 1,
          ),
        );
      }
      return Drawing(aspectRatio: ar, strokes: strokes);
    } on Object {
      return null;
    }
  }

  /// Compact JSON for storage.
  String toJsonString() => jsonEncode({
    'v': version,
    'ar': _round(aspectRatio, 1000),
    's': [
      for (final s in strokes)
        {
          'c': s.color,
          'w': _round(s.width, 10000),
          'h': s.highlighter ? 1 : 0,
          'p': [for (final p in s.points) _round(p, 10000)],
        },
    ],
  });

  /// Whether the encoded drawing fits in [maxBytes].
  bool get fitsSizeLimit => utf8.encode(toJsonString()).length <= maxBytes;

  Drawing copyWith({List<DrawingStroke>? strokes}) =>
      Drawing(aspectRatio: aspectRatio, strokes: strokes ?? this.strokes);

  static double _round(double v, int scale) => (v * scale).round() / scale;

  /// Reduces [points] (flat `x,y` list) with Ramer-Douglas-Peucker, keeping the
  /// first and last point. [aspectRatio] converts y into width units so the
  /// tolerance is isotropic.
  static List<double> simplify(
    List<double> points,
    double aspectRatio, [
    double tolerance = simplifyTolerance,
  ]) {
    final n = points.length ~/ 2;
    if (n <= 2) return List.of(points);
    double x(int i) => points[2 * i];
    double y(int i) => points[2 * i + 1] / aspectRatio;

    final keep = List<bool>.filled(n, false)
      ..[0] = true
      ..[n - 1] = true;
    final stack = <(int, int)>[(0, n - 1)];
    while (stack.isNotEmpty) {
      final (start, end) = stack.removeLast();
      var maxDist = 0.0;
      var index = -1;
      for (var i = start + 1; i < end; i++) {
        final d = distanceToSegment(
          x(i),
          y(i),
          x(start),
          y(start),
          x(end),
          y(end),
        );
        if (d > maxDist) {
          maxDist = d;
          index = i;
        }
      }
      if (index != -1 && maxDist > tolerance) {
        keep[index] = true;
        stack
          ..add((start, index))
          ..add((index, end));
      }
    }
    return [
      for (var i = 0; i < n; i++)
        if (keep[i]) ...[points[2 * i], points[2 * i + 1]],
    ];
  }

  /// Distance from point (px, py) to the segment (ax, ay)-(bx, by).
  static double distanceToSegment(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }
}
