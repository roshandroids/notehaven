import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/app/app.dart';
import 'package:notehaven_app/features/notes/data/in_memory_note_repository.dart';
import 'package:notehaven_app/features/notes/domain/note.dart';
import 'package:notehaven_app/features/notes/presentation/note_document.dart';
import 'package:notehaven_app/features/notes/presentation/note_providers.dart';
import 'package:notehaven_app/features/settings/data/in_memory_settings_repository.dart';
import 'package:notehaven_app/features/settings/presentation/settings_providers.dart';

Note _note({String body = 'plain', String? content}) => Note(
  id: 'n1',
  title: 'T',
  body: body,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  content: content,
);

void main() {
  group('note_document', () {
    test('legacy notes without content open from their plain body', () {
      expect(documentFor(_note(body: 'hello')).toPlainText().trim(), 'hello');
    });

    test('damaged content falls back to the body instead of failing', () {
      final doc = documentFor(_note(body: 'safe', content: '{not json'));
      expect(doc.toPlainText().trim(), 'safe');
    });

    test('an empty document serializes to null content', () {
      final s = serializeDocument(Document());
      expect(s.body, isEmpty);
      expect(s.content, isNull);
    });

    test('plain text keeps no embed placeholders or trailing newline', () {
      final doc = Document()..insert(0, 'abc');
      doc.insert(3, const BlockEmbed('drawing', '{}'));
      final s = serializeDocument(doc);
      expect(s.body, 'abc');
      expect(s.content, isNotNull);
    });

    test('an embed-only document still has content (drawing-only note)', () {
      final doc = Document()..insert(0, const BlockEmbed('drawing', '{}'));
      final s = serializeDocument(doc);
      expect(s.body, isEmpty);
      expect(s.content, isNotNull);
    });

    test('formatting survives a serialize/open round trip', () {
      final doc = Document()..insert(0, 'bold');
      doc.format(0, 4, Attribute.bold);
      final s = serializeDocument(doc);
      final back = documentFor(_note(body: s.body, content: s.content));
      final ops = back.toDelta().toJson();
      expect(jsonEncode(ops), contains('"bold":true'));
    });
  });

  group('editor screen', () {
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

    QuillController controller(WidgetTester tester) => tester
        .widget<QuillEditor>(find.byKey(const Key('note-body')))
        .controller;

    testWidgets('bold formatting is saved as rich content', (tester) async {
      await pump(tester);
      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      final c = controller(tester);
      c.replaceText(0, 0, 'Hello', const TextSelection.collapsed(offset: 5));
      c.formatText(0, 5, Attribute.bold);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      final note = (await repo.watch().first)
          .fold<List<Note>>((v) => v, (f) => throw f)
          .single;
      expect(note.body, 'Hello');
      expect(note.content, contains('"bold":true'));
    });

    testWidgets('reopening a saved note restores its formatting', (
      tester,
    ) async {
      await pump(tester);
      final doc = Document()..insert(0, 'Styled');
      doc.format(0, 6, Attribute.bold);
      final s = serializeDocument(doc);
      await repo.create('Rich', s.body, content: s.content);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rich'));
      await tester.pumpAndSettle();
      final ops = controller(tester).document.toDelta().toJson();
      expect(jsonEncode(ops), contains('"bold":true'));
    });

    testWidgets('a legacy plain note opens with its text', (tester) async {
      await pump(tester);
      await repo.create('Old', 'legacy text');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old'));
      await tester.pumpAndSettle();
      expect(controller(tester).document.toPlainText().trim(), 'legacy text');
    });

    testWidgets('typing with the real keyboard path updates the document', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('note-body')));
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'typed\n',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();
      expect(controller(tester).document.toPlainText().trim(), 'typed');
    });

    testWidgets('Ctrl+S saves while the editor has focus', (tester) async {
      await pump(tester);
      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      final c = controller(tester);
      c.replaceText(
        0,
        0,
        'saved by key',
        const TextSelection.collapsed(offset: 12),
      );
      await tester.tap(find.byKey(const Key('note-body')));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final notes = (await repo.watch().first).fold<List<Note>>(
        (v) => v,
        (f) => throw f,
      );
      expect(notes.single.body, 'saved by key');
    });

    testWidgets('the word count follows the document', (tester) async {
      await pump(tester);
      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      controller(tester).replaceText(
        0,
        0,
        'one two three',
        const TextSelection.collapsed(offset: 13),
      );
      await tester.pump();
      expect(find.textContaining('3 words'), findsOneWidget);
    });
  });
}
