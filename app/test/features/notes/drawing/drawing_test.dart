import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/features/notes/domain/drawing.dart';
import 'package:notehaven_app/features/notes/presentation/drawing/drawing_controller.dart';

DrawingStroke stroke(List<double> points, {int color = 0xFF000000}) =>
    DrawingStroke(color: color, width: 0.006, points: points);

void main() {
  group('Drawing format', () {
    test('round-trips strokes, colors and aspect ratio', () {
      final d = Drawing(
        aspectRatio: 1.5,
        strokes: [
          stroke([0.1, 0.2, 0.3, 0.4], color: 0xFFD32F2F),
          const DrawingStroke(
            color: 0xFF1976D2,
            width: 0.018,
            points: [0.5, 0.5, 0.6, 0.6],
            highlighter: true,
          ),
        ],
      );
      final back = Drawing.tryParse(d.toJsonString())!;
      expect(back.aspectRatio, 1.5);
      expect(back.strokes, hasLength(2));
      expect(back.strokes[0].color, 0xFFD32F2F);
      expect(back.strokes[1].highlighter, isTrue);
      expect(back.strokes[1].points, [0.5, 0.5, 0.6, 0.6]);
    });

    test('the stored format is versioned', () {
      final json = jsonDecode(const Drawing().toJsonString()) as Map;
      expect(json['v'], Drawing.version);
    });

    test('points are rounded to 4 decimals', () {
      final d = Drawing(
        strokes: [
          stroke([0.123456789, 0.987654321]),
        ],
      );
      final json = jsonDecode(d.toJsonString()) as Map;
      expect(((json['s'] as List).single as Map)['p'], [0.1235, 0.9877]);
    });

    test('damaged or unsupported input parses to null instead of throwing', () {
      expect(Drawing.tryParse('not json'), isNull);
      expect(Drawing.tryParse('[]'), isNull);
      expect(
        Drawing.tryParse('{"v":2,"ar":1.3,"s":[]}'),
        isNull,
        reason: 'newer version',
      );
      expect(Drawing.tryParse('{"v":1,"ar":0,"s":[]}'), isNull);
      expect(
        Drawing.tryParse(
          '{"v":1,"ar":1.3,"s":[{"c":1,"w":0.1,"h":0,"p":[0.1]}]}',
        ),
        isNull,
        reason: 'odd number of coordinates',
      );
      expect(Drawing.tryParse('{"v":1,"ar":1.3}'), isNull);
    });

    test('an oversized drawing does not fit the size limit', () {
      final points = [for (var i = 0; i < 60000; i++) (i % 1000) / 1000];
      final big = Drawing(strokes: [stroke(points)]);
      expect(big.fitsSizeLimit, isFalse);
      expect(const Drawing().fitsSizeLimit, isTrue);
    });
  });

  group('simplify', () {
    test('keeps the end points and drops collinear ones', () {
      final line = <double>[0, 0, 0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1, 1];
      expect(Drawing.simplify(line, 1), [0, 0, 1, 1]);
    });

    test('keeps a corner', () {
      final corner = <double>[0, 0, 0.5, 0, 0.5, 0.5];
      expect(Drawing.simplify(corner, 1), corner);
    });

    test('two points are left untouched', () {
      expect(Drawing.simplify([0.1, 0.1, 0.2, 0.2], 1), [0.1, 0.1, 0.2, 0.2]);
    });
  });

  group('DrawingController', () {
    DrawingController draw(DrawingController c, List<double> points) {
      c.start(points[0], points[1]);
      for (var i = 2; i + 1 < points.length; i += 2) {
        c.extend(points[i], points[i + 1]);
      }
      c.end();
      return c;
    }

    test('a stroke becomes one undoable step', () {
      final c = draw(DrawingController(), [0.1, 0.1, 0.5, 0.5, 0.9, 0.2]);
      expect(c.strokes, hasLength(1));
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.strokes, isEmpty);
      c.redo();
      expect(c.strokes, hasLength(1));
    });

    test('drawing after an undo drops the redo history', () {
      final c = draw(DrawingController(), [0.1, 0.1, 0.5, 0.5]);
      c.undo();
      draw(c, [0.2, 0.2, 0.6, 0.6]);
      expect(c.canRedo, isFalse);
    });

    test('a tap leaves a dot', () {
      final c = DrawingController()
        ..start(0.5, 0.5)
        ..end();
      expect(c.strokes.single.pointCount, greaterThanOrEqualTo(1));
    });

    test('highlighter strokes are wider and flagged', () {
      final c = DrawingController()..selectTool(DrawingTool.highlighter);
      draw(c, [0.1, 0.1, 0.9, 0.1]);
      expect(c.strokes.single.highlighter, isTrue);
      expect(c.strokes.single.width, closeTo(c.width * 3, 1e-9));
    });

    test('the eraser removes only the touched stroke, in one undo step', () {
      final c = DrawingController();
      draw(c, [0.1, 0.1, 0.4, 0.1]); // top line
      draw(c, [0.1, 0.9, 0.4, 0.9]); // bottom line
      c.selectTool(DrawingTool.eraser);
      draw(c, [0.2, 0.1, 0.25, 0.1, 0.3, 0.1]); // sweep across the top line
      expect(c.strokes, hasLength(1));
      expect(c.strokes.single.points[1], closeTo(0.9, 1e-9));
      c.undo();
      expect(
        c.strokes,
        hasLength(2),
        reason: 'one undo restores the erased stroke',
      );
    });

    test('clear is undoable', () {
      final c = draw(DrawingController(), [0.1, 0.1, 0.5, 0.5]);
      c.clear();
      expect(c.strokes, isEmpty);
      c.undo();
      expect(c.strokes, hasLength(1));
    });

    test('picking a color switches the eraser back to the pen', () {
      final c = DrawingController()..selectTool(DrawingTool.eraser);
      c.selectColor(0xFFD32F2F);
      expect(c.tool, DrawingTool.pen);
    });

    test('undo history is capped', () {
      final c = DrawingController();
      for (var i = 0; i < DrawingController.maxHistory + 20; i++) {
        draw(c, [0.1, 0.1, 0.2, 0.2]);
      }
      var undos = 0;
      while (c.canUndo) {
        c.undo();
        undos++;
      }
      expect(undos, lessThan(DrawingController.maxHistory));
    });

    test('the canvas aspect ratio comes from the drawing', () {
      expect(DrawingController(const Drawing(aspectRatio: 2)).aspectRatio, 2);
    });
  });
}
