import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/app/app.dart';
import 'package:notehaven_app/features/notes/data/in_memory_note_repository.dart';
import 'package:notehaven_app/features/notes/domain/drawing.dart';
import 'package:notehaven_app/features/notes/domain/note.dart';
import 'package:notehaven_app/features/notes/presentation/drawing/drawing_editor_screen.dart';
import 'package:notehaven_app/features/notes/presentation/drawing/drawing_painter.dart';
import 'package:notehaven_app/features/notes/presentation/note_providers.dart';
import 'package:notehaven_app/features/settings/data/in_memory_settings_repository.dart';
import 'package:notehaven_app/features/settings/presentation/settings_providers.dart';
import 'package:notehaven_app/shared/feedback/ui_feedback.dart';

import '../../../support/fake_feedback.dart';

Future<void> scribble(WidgetTester tester) async {
  final canvas = find.byKey(const Key('drawing-canvas'));
  final center = tester.getCenter(canvas);
  final gesture = await tester.startGesture(center);
  await gesture.moveBy(const Offset(40, 10));
  await gesture.moveBy(const Offset(40, 30));
  await gesture.up();
  await tester.pump();
}

void main() {
  group('DrawingEditorScreen', () {
    late Drawing? result;
    var returned = false;
    final feedback = FakeUiFeedback();
    setUp(feedback.events.clear);

    Future<void> open(WidgetTester tester, [Drawing? initial]) async {
      result = null;
      returned = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [feedbackProvider.overrideWithValue(feedback)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      result = await openDrawingEditor(context, initial);
                      returned = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('drawing then saving returns one stroke', (tester) async {
      await open(tester);
      await scribble(tester);
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result!.strokes, hasLength(1));
    });

    testWidgets('strokes, tools and save give feedback; clear is undoable', (
      tester,
    ) async {
      await open(tester);
      await scribble(tester);
      await tester.tap(find.byTooltip('Drawing tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Highlighter'));
      await tester.tap(find.byTooltip('Clear drawing'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Drawing cleared'), findsOneWidget);
      tester
          .widget<SnackBarAction>(find.widgetWithText(SnackBarAction, 'Undo'))
          .onPressed();
      await tester.pump();
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();
      expect(result!.strokes, hasLength(1), reason: 'snackbar undo restored');
      expect(feedback.events, [
        FeedbackEvent.strokeStart,
        FeedbackEvent.strokeEnd,
        FeedbackEvent.tap,
        FeedbackEvent.select,
        FeedbackEvent.delete,
        FeedbackEvent.undo,
        FeedbackEvent.success,
      ]);
    });

    testWidgets('undo, redo and clear update the buttons', (tester) async {
      await open(tester);
      IconButton button(String tooltip) => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, tooltipIcon(tooltip)),
      );
      await scribble(tester);
      expect(button('Undo').onPressed, isNotNull);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(button('Undo').onPressed, isNull);
      expect(button('Redo').onPressed, isNotNull);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pump();
      await tester.tap(find.byTooltip('Clear drawing'));
      await tester.pump();
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();
      expect(
        result!.isEmpty,
        isTrue,
        reason: 'saving an empty drawing means remove',
      );
    });

    testWidgets('leaving after drawing asks before discarding', (tester) async {
      await open(tester);
      await scribble(tester);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep drawing'));
      await tester.pumpAndSettle();
      expect(returned, isFalse);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, isNull);
    });

    testWidgets('a second finger is ignored while one stroke is active', (
      tester,
    ) async {
      await open(tester);
      final center = tester.getCenter(find.byKey(const Key('drawing-canvas')));
      final first = await tester.startGesture(center, pointer: 1);
      final second = await tester.startGesture(
        center + const Offset(60, 0),
        pointer: 2,
      );
      await first.moveBy(const Offset(30, 0));
      await second.moveBy(const Offset(0, 50));
      await second.up();
      await first.up();
      await tester.pump();
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();
      expect(result!.strokes, hasLength(1));
    });

    testWidgets('tools are labeled for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      await tester.tap(find.byTooltip('Drawing tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pen')); // active tool again -> options
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Color red')), findsOneWidget);
      expect(find.byTooltip('Pen'), findsOneWidget);
      expect(find.byTooltip('Eraser (removes whole strokes)'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Drawing canvas')), findsOneWidget);
      handle.dispose();
    });
  });

  group('drawing inside a note', () {
    late InMemoryNoteRepository repo;

    Future<void> pump(WidgetTester tester) async {
      repo = InMemoryNoteRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            noteRepositoryProvider.overrideWithValue(repo),
            settingsRepositoryProvider.overrideWithValue(
              InMemorySettingsRepository(),
            ),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('insert a drawing, save a drawing-only note, reopen it', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Insert drawing'));
      await tester.pumpAndSettle();
      await scribble(tester);
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();
      expect(find.byType(DrawingThumbnail), findsOneWidget);

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      final notes = (await repo.watch().first).fold<List<Note>>(
        (v) => v,
        (f) => throw f,
      );
      expect(notes, hasLength(1), reason: 'a drawing-only note is valid');
      expect(notes.single.body, isEmpty);
      expect(notes.single.content, contains('"drawing"'));

      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();
      expect(find.byType(DrawingThumbnail), findsOneWidget);
    });

    testWidgets('editing a drawing in place replaces it', (tester) async {
      await pump(tester);
      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Insert drawing'));
      await tester.pumpAndSettle();
      await scribble(tester);
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DrawingThumbnail));
      await tester.pumpAndSettle();
      await scribble(tester); // second stroke
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();

      final editor = tester.widget<QuillEditor>(
        find.byKey(const Key('note-body')),
      );
      final embeds = editor.controller.document
          .toDelta()
          .toList()
          .where((op) => op.data is Map)
          .toList();
      expect(embeds, hasLength(1), reason: 'edited in place, not duplicated');
      final data = (embeds.single.data! as Map)['drawing'] as String;
      expect(Drawing.tryParse(data)!.strokes, hasLength(2));
    });

    testWidgets('clearing a drawing removes it from the note', (tester) async {
      await pump(tester);
      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Insert drawing'));
      await tester.pumpAndSettle();
      await scribble(tester);
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DrawingThumbnail));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear drawing'));
      await tester.pump();
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();
      expect(find.byType(DrawingThumbnail), findsNothing);
    });

    testWidgets('a damaged drawing shows a placeholder instead of crashing', (
      tester,
    ) async {
      await pump(tester);
      final doc = Document()..insert(0, const BlockEmbed('drawing', '{broken'));
      await repo.create(
        'Broken',
        '',
        content: '[{"insert":{"drawing":"{broken"}},{"insert":"\\n"}]',
      );
      await tester.pumpAndSettle();
      expect(doc.length, greaterThan(0));
      await tester.tap(find.text('Broken'));
      await tester.pumpAndSettle();
      expect(find.text("Drawing can't be shown"), findsOneWidget);
    });

    testWidgets(
      'the thumbnail is one labeled, tappable stop for screen readers',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester);
        final drawing = Drawing(
          strokes: [
            const DrawingStroke(
              color: 0xFF000000,
              width: 0.006,
              points: [0.1, 0.1, 0.9, 0.9],
            ),
          ],
        );
        final doc = Document()
          ..insert(0, BlockEmbed('drawing', drawing.toJsonString()));
        await repo.create(
          'Sketch',
          '',
          content: jsonEncode(doc.toDelta().toJson()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sketch'));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel('Drawing. Double tap to edit.'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );
  });
}

IconData tooltipIcon(String tooltip) => switch (tooltip) {
  'Undo' => Icons.undo,
  'Redo' => Icons.redo,
  _ => throw ArgumentError(tooltip),
};
