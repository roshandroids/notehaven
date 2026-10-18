import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:notehaven_core/notehaven_core.dart';

import '../../../core/database/app_database.dart';
import '../domain/note.dart';
import '../domain/note_repository.dart';

/// [NoteRepository] backed by the local Drift database.
///
/// Data flow: widget → repository → SQLite; reads are live queries, so any
/// write re-emits every active [watch]. Storage errors become [StorageFailure].
///
/// Sync contract: every write bumps the note's `rev` and `clock` and queues it
/// in the outbox inside the same transaction (one outbox row per note). Deletes
/// are soft (tombstones) so they can reach the server; tombstones never leave
/// this class as [Note]s.
///
/// shortcut: tombstones are kept forever; add a purge once a delete is acked
/// and old enough if the table grows.
class DriftNoteRepository implements NoteRepository {
  DriftNoteRepository(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  static Note _toNote(NoteRow r) => Note(
    id: r.id,
    title: r.title,
    body: r.body,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    content: r.content,
  );

  Future<Result<T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Ok(await op());
    } on Object catch (e) {
      return Err(StorageFailure('$e'));
    }
  }

  /// Next sync clock for a note: wall time, but always above the previous value.
  int _nextClock(DateTime now, NoteRow? previous) =>
      math.max(now.millisecondsSinceEpoch, (previous?.clock ?? 0) + 1);

  Future<NoteRow?> _row(String id) => (_db.select(
    _db.notesTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> _enqueue(String id, DateTime now) => _db
      .into(_db.outboxTable)
      .insertOnConflictUpdate(
        OutboxTableCompanion.insert(
          noteId: id,
          queuedAt: now,
          attempts: const Value(0),
        ),
      );

  /// Writes [title]/[body] for [id] (create or update), un-deleting it, and
  /// queues it for sync. Returns the stored note.
  Future<Note> _upsert({
    required String id,
    required String title,
    required String body,
    required String? content,
    required DateTime createdAt,
  }) => _db.transaction(() async {
    final now = _now();
    final previous = await _row(id);
    await _db
        .into(_db.notesTable)
        .insertOnConflictUpdate(
          NotesTableCompanion(
            id: Value(id),
            title: Value(title),
            body: Value(body),
            content: Value(content),
            createdAt: Value(previous?.createdAt ?? createdAt),
            updatedAt: Value(now),
            deletedAt: const Value(null),
            rev: Value((previous?.rev ?? 0) + 1),
            clock: Value(_nextClock(now, previous)),
          ),
        );
    await _enqueue(id, now);
    return Note(
      id: id,
      title: title,
      body: body,
      createdAt: previous?.createdAt ?? createdAt,
      updatedAt: now,
      content: content,
    );
  });

  @override
  Stream<Result<List<Note>>> watch({String query = ''}) async* {
    final q = query.trim();
    final select = _db.select(_db.notesTable)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (q.isNotEmpty) {
      select.where((t) => t.title.contains(q) | t.body.contains(q));
    }
    try {
      await for (final rows in select.watch()) {
        yield Ok(rows.map(_toNote).toList());
      }
    } on Object catch (e) {
      yield Err(StorageFailure('$e'));
    }
  }

  @override
  Future<Result<Note?>> get(String id) => _guard(() async {
    final row = await _row(id);
    return row == null || row.deletedAt != null ? null : _toNote(row);
  });

  @override
  Future<Result<Note>> create(
    String title,
    String body, {
    String? content,
  }) async {
    final invalid = Note.validate(title, body, content: content);
    if (invalid != null) return Err(invalid);
    final draft = Note.create(title, body, content: content, now: _now());
    return _guard(
      () => _upsert(
        id: draft.id,
        title: draft.title,
        body: draft.body,
        content: draft.content,
        createdAt: draft.createdAt,
      ),
    );
  }

  @override
  Future<Result<Note>> update(Note note) async {
    final invalid = Note.validate(note.title, note.body, content: note.content);
    if (invalid != null) return Err(invalid);
    return _guard(
      () => _upsert(
        id: note.id,
        title: note.title,
        body: note.body,
        content: note.content,
        createdAt: note.createdAt,
      ),
    );
  }

  @override
  Future<Result<void>> delete(String id) => _guard(
    () => _db.transaction(() async {
      final previous = await _row(id);
      if (previous == null || previous.deletedAt != null) return;
      final now = _now();
      await (_db.update(_db.notesTable)..where((t) => t.id.equals(id))).write(
        NotesTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          rev: Value(previous.rev + 1),
          clock: Value(_nextClock(now, previous)),
        ),
      );
      await _enqueue(id, now);
    }),
  );

  @override
  Future<Result<void>> restore(Note note) async {
    final result = await _guard(
      () => _upsert(
        id: note.id,
        title: note.title,
        body: note.body,
        content: note.content,
        createdAt: note.createdAt,
      ),
    );
    return result.fold<Result<void>>((_) => const Ok(null), Err.new);
  }
}
