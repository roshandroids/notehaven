import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/app/app.dart';
import 'package:notehaven_app/features/notes/data/in_memory_note_repository.dart';
import 'package:notehaven_app/features/notes/presentation/note_providers.dart';
import 'package:notehaven_app/features/settings/data/in_memory_settings_repository.dart';
import 'package:notehaven_app/features/settings/presentation/settings_providers.dart';
import 'package:notehaven_app/shared/feedback/ui_feedback.dart';

import '../../support/fake_feedback.dart';

void main() {
  late InMemoryNoteRepository repo;
  final feedback = FakeUiFeedback();
  setUp(feedback.events.clear);

  Future<void> pumpApp(WidgetTester tester) async {
    repo = InMemoryNoteRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          settingsRepositoryProvider.overrideWithValue(
            InMemorySettingsRepository(),
          ),
          feedbackProvider.overrideWithValue(feedback),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addNote(WidgetTester tester, String title, String body) async {
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), title);
    // QuillEditor is not an EditableText, so write through its controller.
    final editor = tester.widget<QuillEditor>(
      find.byKey(const Key('note-body')),
    );
    editor.controller.replaceText(
      0,
      0,
      body,
      TextSelection.collapsed(offset: body.length),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state', (tester) async {
    await pumpApp(tester);
    expect(find.text('Notes you add appear here'), findsOneWidget);
  });

  testWidgets('creates a note and lists it', (tester) async {
    await pumpApp(tester);
    await addNote(tester, 'Groceries', 'milk, eggs');
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('milk, eggs'), findsOneWidget);
  });

  testWidgets('saving an empty note shows a validation message', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Note is empty'), findsOneWidget);
  });

  testWidgets('search filters the list', (tester) async {
    await pumpApp(tester);
    await addNote(tester, 'Groceries', 'milk');
    await addNote(tester, 'Work', 'standup');
    await tester.enterText(find.byKey(const Key('search')), 'gro');
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Work'), findsNothing);
  });

  testWidgets('swipe Copy duplicates the note', (tester) async {
    await pumpApp(tester);
    await addNote(tester, 'Plan', 'body');
    // Swipe actions exist in list view only; grid cards use the long-press menu.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('List view'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.text('Plan'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(find.text('Plan (copy)'), findsOneWidget);
  });

  testWidgets('delete removes the note and undo restores it', (tester) async {
    await pumpApp(tester);
    await addNote(tester, 'Temp', 'x');
    // Swipe actions exist in list view only; grid cards use the long-press menu.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('List view'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.text('Temp'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    // Not pumpAndSettle: the snackbar auto-dismisses after 4s.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Temp'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Temp'), findsOneWidget);
  });

  testWidgets('saving confirms with feedback and a snackbar', (tester) async {
    await pumpApp(tester);
    await addNote(tester, 'Groceries', 'milk');
    expect(feedback.events, [FeedbackEvent.success]);
    expect(find.text('Note saved'), findsOneWidget);
  });

  testWidgets('long-press menu deletes and undo restores', (tester) async {
    await pumpApp(tester);
    await addNote(tester, 'Groceries', 'milk');
    feedback.events.clear();

    await tester.longPress(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete note'));
    // Not pumpAndSettle: the snackbar auto-dismisses after 4s.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Note deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    expect(feedback.events, [
      FeedbackEvent.tap,
      FeedbackEvent.delete,
      FeedbackEvent.undo,
    ]);
  });

  testWidgets('long-press menu copies a note', (tester) async {
    await pumpApp(tester);
    await addNote(tester, 'Groceries', 'milk');
    await tester.longPress(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy note'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries (copy)'), findsOneWidget);
    expect(find.text('Note copied'), findsOneWidget);
  });
}
