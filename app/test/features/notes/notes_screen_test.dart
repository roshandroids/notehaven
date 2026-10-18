import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/app/app.dart';
import 'package:notehaven_app/features/notes/data/in_memory_note_repository.dart';
import 'package:notehaven_app/features/notes/presentation/note_providers.dart';

void main() {
  Widget app() => ProviderScope(
    overrides: [
      noteRepositoryProvider.overrideWithValue(InMemoryNoteRepository()),
    ],
    child: const App(),
  );

  testWidgets('adds an entry and shows it', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('No notes yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Buy paper');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Buy paper'), findsOneWidget);
  });

  testWidgets('blank title shows a validation message', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Title is empty'), findsOneWidget);
  });
}
