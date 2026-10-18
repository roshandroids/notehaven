import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/app/app.dart';
import 'package:notehaven_app/features/notes/data/in_memory_note_repository.dart';
import 'package:notehaven_app/features/notes/presentation/note_providers.dart';
import 'package:notehaven_app/features/settings/data/in_memory_settings_repository.dart';
import 'package:notehaven_app/features/settings/presentation/settings_providers.dart';

void main() {
  late InMemoryNoteRepository repo;

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = InMemoryNoteRepository();
    await repo.create('Groceries', 'milk and eggs');
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

  group('responsive layout', () {
    testWidgets('narrow: list only, no detail pane', (tester) async {
      await pumpApp(tester, const Size(500, 900));
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Select a note'), findsNothing);
    });

    testWidgets('wide: list and detail pane side by side', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Select a note'), findsOneWidget);
    });

    testWidgets('wide: opening a note keeps the list visible', (tester) async {
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-title')), findsOneWidget);
      expect(find.text('New note'), findsOneWidget); // list FAB still there
      expect(find.text('Select a note'), findsNothing);
    });

    testWidgets('wide: saving a new note returns to the empty pane', (
      tester,
    ) async {
      await pumpApp(tester, const Size(1400, 900));
      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('note-title')), 'Plan');
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Select a note'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('note card is one labeled stop with copy/delete actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const Size(500, 900));
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Groceries.*milk and eggs.*Edited')),
      );
      final data = node.getSemanticsData();
      expect(data.customSemanticsActionIds, hasLength(2));
      handle.dispose();
    });

    testWidgets('tap targets are large enough and labeled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const Size(500, 900));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
