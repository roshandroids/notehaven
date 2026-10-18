import 'package:drift/drift.dart';
import 'package:notehaven_core/notehaven_core.dart';

import '../../../core/database/app_database.dart';
import '../domain/note.dart';
import '../domain/note_repository.dart';

/// [NoteRepository] backed by the local Drift database.
///
/// Data flow: widget → repository → SQLite; reads are live queries, so any
/// write re-emits every active [watch]. Storage errors become [StorageFailure].
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
  );

  static NotesTableCompanion _toRow(Note n) => NotesTableCompanion.insert(
    id: n.id,
    title: n.title,
    body: n.body,
    createdAt: n.createdAt,
    updatedAt: n.updatedAt,
  );

  Future<Result<T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Ok(await op());
    } on Object catch (e) {
      return Err(StorageFailure('$e'));
    }
  }

  @override
  Stream<Result<List<Note>>> watch({String query = ''}) async* {
    final q = query.trim();
    final select = _db.select(_db.notesTable)
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
    final row = await (_db.select(
      _db.notesTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toNote(row);
  });

  @override
  Future<Result<Note>> create(String title, String body) async {
    final invalid = Note.validate(title, body);
    if (invalid != null) return Err(invalid);
    final note = Note.create(title, body, now: _now());
    return _guard(() async {
      await _db.into(_db.notesTable).insert(_toRow(note));
      return note;
    });
  }

  @override
  Future<Result<Note>> update(Note note) async {
    final invalid = Note.validate(note.title, note.body);
    if (invalid != null) return Err(invalid);
    final updated = note.copyWith(updatedAt: _now());
    return _guard(() async {
      await _db.into(_db.notesTable).insertOnConflictUpdate(_toRow(updated));
      return updated;
    });
  }

  @override
  Future<Result<void>> delete(String id) => _guard(() async {
    await (_db.delete(_db.notesTable)..where((t) => t.id.equals(id))).go();
  });

  @override
  Future<Result<void>> restore(Note note) => _guard(() async {
    await _db.into(_db.notesTable).insertOnConflictUpdate(_toRow(note));
  });
}
