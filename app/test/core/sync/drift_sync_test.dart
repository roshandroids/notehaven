import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notehaven_app/core/database/app_database.dart';
import 'package:notehaven_app/core/sync/drift_local_sync_store.dart';
import 'package:notehaven_app/features/notes/data/drift_note_repository.dart';
import 'package:notehaven_app/features/notes/domain/note.dart';
import 'package:notehaven_core/notehaven_core.dart';
import 'package:notehaven_sync/fakes.dart';
import 'package:notehaven_sync/notehaven_sync.dart';

T ok<T>(Object result) =>
    (result as dynamic).fold((v) => v, (f) => throw f) as T;

void main() {
  late AppDatabase db;
  late DriftNoteRepository repo;
  late DriftLocalSyncStore store;
  var tick = 0;
  DateTime nextTime() =>
      DateTime.utc(2026, 1, 1).add(Duration(minutes: tick++));

  setUp(() {
    tick = 0;
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftNoteRepository(db, clock: nextTime);
    store = DriftLocalSyncStore(db);
    addTearDown(db.close);
  });

  Future<List<OutboxRow>> outbox() => db.select(db.outboxTable).get();
  Future<NoteRow> row(String id) =>
      (db.select(db.notesTable)..where((t) => t.id.equals(id))).getSingle();

  group('v1 -> v2 migration', () {
    test('keeps notes, backfills the sync clock and queues everything', () async {
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE notes (id TEXT NOT NULL PRIMARY KEY, '
              'title TEXT NOT NULL, body TEXT NOT NULL, '
              'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
            );
            raw.execute(
              "INSERT INTO notes VALUES ('a','Alpha','one',1700000000,1700000100)",
            );
            raw.execute(
              "INSERT INTO notes VALUES ('b','Beta','two',1700000200,1700000300)",
            );
            raw.execute('PRAGMA user_version = 1');
          },
        ),
      );
      addTearDown(old.close);

      final notes = await DriftNoteRepository(old).watch().first;
      expect(ok<List<Note>>(notes).map((n) => n.title).toSet(), {
        'Alpha',
        'Beta',
      });
      final a = await (old.select(
        old.notesTable,
      )..where((t) => t.id.equals('a'))).getSingle();
      expect(a.clock, 1700000100 * 1000);
      expect(a.rev, 0);
      expect(a.deletedAt, isNull);
      final queued = await old.select(old.outboxTable).get();
      expect(queued.map((q) => q.noteId).toSet(), {'a', 'b'});
      expect(await (old.select(old.syncStateTable)).get(), isEmpty);
    });
  });

  group('v2 -> v3 migration', () {
    test('adds a null content column and keeps existing notes', () async {
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE notes (id TEXT NOT NULL PRIMARY KEY, '
              'title TEXT NOT NULL, body TEXT NOT NULL, '
              'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
              'deleted_at INTEGER, rev INTEGER NOT NULL DEFAULT 0, '
              'clock INTEGER NOT NULL DEFAULT 0)',
            );
            raw.execute(
              'CREATE TABLE outbox (note_id TEXT NOT NULL PRIMARY KEY, '
              'queued_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0)',
            );
            raw.execute(
              'CREATE TABLE sync_state (key TEXT NOT NULL PRIMARY KEY, '
              'value TEXT NOT NULL)',
            );
            raw.execute(
              "INSERT INTO notes VALUES ('a','Alpha','one',1700000000,1700000100,NULL,4,1700000100000)",
            );
            raw.execute("INSERT INTO outbox VALUES ('a',1700000100,2)");
            raw.execute('PRAGMA user_version = 2');
          },
        ),
      );
      addTearDown(old.close);

      final notes = ok<List<Note>>(
        await DriftNoteRepository(old).watch().first,
      );
      expect(notes.single.title, 'Alpha');
      expect(notes.single.content, isNull);
      final r = await (old.select(
        old.notesTable,
      )..where((t) => t.id.equals('a'))).getSingle();
      expect(r.rev, 4);
      expect(r.clock, 1700000100000);
      final queued = await old.select(old.outboxTable).get();
      expect(queued.single.attempts, 2, reason: 'queue survives the upgrade');
    });
  });

  group('rich content', () {
    const delta = '[{"insert":"hi\\n"}]';

    test('is stored, returned and kept across update and restore', () async {
      final n = ok<Note>(await repo.create('A', 'hi', content: delta));
      expect(n.content, delta);
      expect(ok<Note?>(await repo.get(n.id))!.content, delta);

      await repo.update(n.copyWith(body: 'hi!'));
      expect(ok<Note?>(await repo.get(n.id))!.content, delta);

      await repo.delete(n.id);
      await repo.restore(n);
      expect(ok<Note?>(await repo.get(n.id))!.content, delta);
    });

    test('a drawing-only note (empty text, has content) is valid', () async {
      final n = await repo.create('', '', content: delta);
      expect(n, isA<Ok<Note>>());
      expect(await repo.create('', ''), isA<Err<Note>>());
    });

    test('reaches the sync store and applyPulled writes it back', () async {
      final n = ok<Note>(await repo.create('A', 'x', content: delta));
      final pending = (await store.pendingChanges(limit: 5)).single;
      expect(pending.note.content, delta);

      await store.applyPulled([
        SyncNote(
          id: n.id,
          title: 'A',
          body: 'x',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2030),
          content: '[{"insert":"remote\\n"}]',
        ),
      ], 'c9');
      expect(
        ok<Note?>(await repo.get(n.id))!.content,
        '[{"insert":"remote\\n"}]',
      );
    });
  });

  group('repository sync contract', () {
    test('create queues one outbox entry', () async {
      final n = ok<Note>(await repo.create('A', 'x'));
      expect((await outbox()).single.noteId, n.id);
      expect((await row(n.id)).rev, 1);
    });

    test('repeat edits coalesce into one entry and bump rev', () async {
      final n = ok<Note>(await repo.create('A', 'x'));
      await repo.update(n.copyWith(body: 'y'));
      await repo.update(n.copyWith(body: 'z'));
      expect(await outbox(), hasLength(1));
      expect((await row(n.id)).rev, 3);
    });

    test(
      'delete is soft: hidden from reads, kept as a queued tombstone',
      () async {
        final n = ok<Note>(await repo.create('A', 'x'));
        await repo.delete(n.id);
        expect(ok<List<Note>>(await repo.watch().first), isEmpty);
        expect(ok<Note?>(await repo.get(n.id)), isNull);
        final r = await row(n.id);
        expect(r.deletedAt, isNotNull);
        expect(await outbox(), hasLength(1));
      },
    );

    test('restore stamps a newer clock so it beats the delete', () async {
      final n = ok<Note>(await repo.create('A', 'x'));
      await repo.delete(n.id);
      final deletedClock = (await row(n.id)).clock;
      await repo.restore(n);
      final r = await row(n.id);
      expect(r.deletedAt, isNull);
      expect(r.clock, greaterThan(deletedClock));
      expect(ok<List<Note>>(await repo.watch().first).single.id, n.id);
    });

    test('the sync clock rises even when the wall clock does not', () async {
      final fixed = DateTime.utc(2026, 1, 1);
      final r = DriftNoteRepository(db, clock: () => fixed);
      final n = ok<Note>(await r.create('A', 'x'));
      final c1 = (await row(n.id)).clock;
      await r.update(n.copyWith(body: 'y'));
      final c2 = (await row(n.id)).clock;
      expect(c2, greaterThan(c1));
    });

    test('deleting an unknown or already deleted note is a no-op', () async {
      await repo.delete('nope');
      final n = ok<Note>(await repo.create('A', 'x'));
      await repo.delete(n.id);
      final rev = (await row(n.id)).rev;
      await repo.delete(n.id);
      expect((await row(n.id)).rev, rev);
    });
  });

  group('DriftLocalSyncStore', () {
    test('pendingChanges returns notes with their revision', () async {
      final n = ok<Note>(await repo.create('A', 'x'));
      final pending = await store.pendingChanges(limit: 10);
      expect(pending.single.note.id, n.id);
      expect(pending.single.rev, 1);
    });

    test(
      'markPushed clears the entry when the revision still matches',
      () async {
        final n = ok<Note>(await repo.create('A', 'x'));
        final p = (await store.pendingChanges(limit: 10)).single;
        await store.markPushed(n.id, p.rev, p.note);
        expect(await outbox(), isEmpty);
      },
    );

    test(
      'markPushed keeps the entry if the note was edited meanwhile',
      () async {
        final n = ok<Note>(await repo.create('A', 'x'));
        final p = (await store.pendingChanges(limit: 10)).single;
        await repo.update(n.copyWith(body: 'edited during push'));
        await store.markPushed(n.id, p.rev, p.note);
        expect(await outbox(), hasLength(1));
      },
    );

    test('recordFailure sinks an entry behind healthy ones', () async {
      final bad = ok<Note>(await repo.create('bad', 'x'));
      final good = ok<Note>(await repo.create('good', 'y'));
      await store.recordFailure(bad.id, 'rejected');
      final order = (await store.pendingChanges(
        limit: 10,
      )).map((c) => c.note.id);
      expect(order.toList(), [good.id, bad.id]);
    });

    test(
      'applyPulled applies a newer remote, clears the queue, saves the cursor',
      () async {
        final n = ok<Note>(await repo.create('local', 'x'));
        final remote = SyncNote(
          id: n.id,
          title: 'remote',
          body: 'r',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2030),
        );
        await store.applyPulled([remote], 'c1');
        expect((await row(n.id)).title, 'remote');
        expect(await outbox(), isEmpty, reason: 'remote must not echo back');
        expect(await store.readCursor(), 'c1');
      },
    );

    test('applyPulled keeps a newer local edit and its queue entry', () async {
      final n = ok<Note>(await repo.create('local', 'x'));
      final remote = SyncNote(
        id: n.id,
        title: 'stale remote',
        body: 'r',
        createdAt: DateTime.utc(2020),
        updatedAt: DateTime.utc(2020),
      );
      await store.applyPulled([remote], 'c2');
      expect((await row(n.id)).title, 'local');
      expect(await outbox(), hasLength(1));
      expect(await store.readCursor(), 'c2');
    });

    test('a remote tombstone hides the note locally', () async {
      final n = ok<Note>(await repo.create('A', 'x'));
      await store.applyPulled([
        SyncNote(
          id: n.id,
          title: 'A',
          body: 'x',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2030),
          deletedAt: DateTime.utc(2030),
        ),
      ], 'c3');
      expect(ok<List<Note>>(await repo.watch().first), isEmpty);
    });
  });

  test('two Drift devices converge through a fake server', () async {
    final server = FakeRemoteNoteStore();
    final dbB = AppDatabase(NativeDatabase.memory());
    addTearDown(dbB.close);
    final repoB = DriftNoteRepository(dbB, clock: nextTime);
    final engineA = SyncEngine(local: store, remote: server);
    final engineB = SyncEngine(local: DriftLocalSyncStore(dbB), remote: server);

    final n = ok<Note>(await repo.create('From A', 'hello'));
    expect((await engineA.syncOnce()).ok, isTrue);
    expect((await engineB.syncOnce()).ok, isTrue);
    expect(ok<List<Note>>(await repoB.watch().first).single.title, 'From A');

    await repoB.update(
      ok<Note?>(await repoB.get(n.id))!.copyWith(title: 'B edited'),
    );
    await engineB.syncOnce();
    await engineA.syncOnce();
    expect(ok<List<Note>>(await repo.watch().first).single.title, 'B edited');

    await repo.delete(n.id);
    await engineA.syncOnce();
    await engineB.syncOnce();
    expect(ok<List<Note>>(await repoB.watch().first), isEmpty);
    expect(await outbox(), isEmpty);
    expect(await dbB.select(dbB.outboxTable).get(), isEmpty);
  });
}
