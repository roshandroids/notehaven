import 'package:drift/drift.dart';
import 'package:notehaven_sync/notehaven_sync.dart';

import '../database/app_database.dart';

/// [LocalSyncStore] on the Drift database.
///
/// Follows the store contract in `notehaven_sync`: remote data is written
/// without queueing, and a queue entry is cleared only when no local edit
/// happened since the push began (`rev` still matches).
class DriftLocalSyncStore implements LocalSyncStore {
  DriftLocalSyncStore(this._db);

  final AppDatabase _db;

  static const _cursorKey = 'pullCursor';

  static SyncNote _toSync(NoteRow r) => SyncNote(
    id: r.id,
    title: r.title,
    body: r.body,
    createdAt: r.createdAt.toUtc(),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.clock, isUtc: true),
    deletedAt: r.deletedAt?.toUtc(),
    content: r.content,
  );

  Future<NoteRow?> _row(String id) => (_db.select(
    _db.notesTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Writes a remote version without touching the outbox.
  Future<void> _writeRemote(SyncNote remote, NoteRow? previous) => _db
      .into(_db.notesTable)
      .insertOnConflictUpdate(
        NotesTableCompanion(
          id: Value(remote.id),
          title: Value(remote.title),
          body: Value(remote.body),
          content: Value(remote.content),
          createdAt: Value(previous?.createdAt ?? remote.createdAt),
          updatedAt: Value(remote.updatedAt),
          deletedAt: Value(remote.deletedAt),
          rev: Value((previous?.rev ?? 0) + 1),
          clock: Value(remote.updatedAt.millisecondsSinceEpoch),
        ),
      );

  @override
  Future<List<PendingChange>> pendingChanges({required int limit}) async {
    final outbox = _db.outboxTable;
    final notes = _db.notesTable;
    final query =
        _db.select(outbox).join([
            innerJoin(notes, notes.id.equalsExp(outbox.noteId)),
          ])
          ..orderBy([
            OrderingTerm.asc(outbox.attempts),
            OrderingTerm.asc(outbox.queuedAt),
          ])
          ..limit(limit);
    final rows = await query.get();
    return [
      for (final r in rows)
        PendingChange(
          note: _toSync(r.readTable(notes)),
          rev: r.readTable(notes).rev,
        ),
    ];
  }

  @override
  Future<void> markPushed(String id, int pushedRev, SyncNote stored) =>
      _db.transaction(() async {
        final row = await _row(id);
        if (row == null || row.rev != pushedRev) return; // edited meanwhile
        await (_db.delete(
          _db.outboxTable,
        )..where((t) => t.noteId.equals(id))).go();
        if (stored != _toSync(row)) await _writeRemote(stored, row);
      });

  @override
  Future<void> recordFailure(String id, String message) =>
      (_db.update(_db.outboxTable)..where((t) => t.noteId.equals(id))).write(
        OutboxTableCompanion.custom(
          attempts: _db.outboxTable.attempts + const Constant(1),
        ),
      );

  @override
  Future<String?> readCursor() async {
    final row = await (_db.select(
      _db.syncStateTable,
    )..where((t) => t.key.equals(_cursorKey))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> applyPulled(List<SyncNote> remote, String? cursor) =>
      _db.transaction(() async {
        for (final r in remote) {
          final local = await _row(r.id);
          final resolution = resolveConflict(
            local: local == null ? null : _toSync(local),
            remote: r,
          );
          if (resolution == ConflictResolution.keepLocal) continue;
          await _writeRemote(r, local);
          await (_db.delete(
            _db.outboxTable,
          )..where((t) => t.noteId.equals(r.id))).go();
        }
        if (cursor != null) {
          await _db
              .into(_db.syncStateTable)
              .insertOnConflictUpdate(
                SyncStateTableCompanion.insert(key: _cursorKey, value: cursor),
              );
        }
      });
}
