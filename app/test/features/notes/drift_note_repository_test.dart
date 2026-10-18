import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/core/database/app_database.dart';
import 'package:notehaven_app/features/notes/data/drift_note_repository.dart';
import 'package:notehaven_app/features/notes/domain/note.dart';
import 'package:notehaven_core/notehaven_core.dart';

void main() {
  late AppDatabase db;
  late DriftNoteRepository repo;
  var tick = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // Strictly increasing clock so ordering by updatedAt is deterministic.
    repo = DriftNoteRepository(
      db,
      clock: () => DateTime(2026, 1, 1).add(Duration(minutes: tick++)),
    );
    addTearDown(db.close);
  });

  Future<List<Note>> all([String query = '']) async =>
      (await repo.watch(query: query).first).fold((v) => v, (f) => throw f);

  test('create then list, newest edit first', () async {
    await repo.create('First', 'a');
    await repo.create('Second', 'b');
    expect((await all()).map((n) => n.title), ['Second', 'First']);
  });

  test('search matches title or body, case-insensitively', () async {
    await repo.create('Groceries', 'milk');
    await repo.create('Work', 'Call BOB');
    expect((await all('gro')).map((n) => n.title), ['Groceries']);
    expect((await all('bob')).map((n) => n.title), ['Work']);
    expect(await all('zzz'), isEmpty);
  });

  test('update changes content and moves the note to the top', () async {
    final first = (await repo.create(
      'First',
      'a',
    )).fold((v) => v, (f) => throw f);
    await repo.create('Second', 'b');
    await repo.update(first.copyWith(body: 'edited'));
    final notes = await all();
    expect(notes.first.title, 'First');
    expect(notes.first.body, 'edited');
  });

  test('delete removes the note and restore brings it back', () async {
    final note = (await repo.create(
      'Gone',
      'x',
    )).fold((v) => v, (f) => throw f);
    await repo.delete(note.id);
    expect(await all(), isEmpty);
    await repo.restore(note);
    expect((await all()).single.id, note.id);
  });

  test('blank note is rejected with ValidationFailure', () async {
    final result = await repo.create('  ', '');
    expect(result, isA<Err<Note>>());
    expect((result as Err<Note>).failure, isA<ValidationFailure>());
  });

  test('get returns null for an unknown id', () async {
    final result = await repo.get('nope');
    expect(result.fold((v) => v, (f) => throw f), isNull);
  });
}
