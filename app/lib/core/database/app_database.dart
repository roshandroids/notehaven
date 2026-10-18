import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Row type for the `notes` table. Text UUID key so Phase 2 sync can create
/// ids offline without collisions.
@DataClassName('NoteRow')
class NotesTable extends Table {
  @override
  String get tableName => 'notes';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Set when the note is deleted (tombstone kept so the delete can sync).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Local write counter; lets sync detect an edit made during a push.
  IntColumn get rev => integer().withDefault(const Constant(0))();

  /// Last-write-wins clock in epoch milliseconds, strictly increasing per
  /// note. [updatedAt] only has second precision, so sync uses this instead.
  IntColumn get clock => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Notes waiting to be pushed: at most one row per note id.
@DataClassName('OutboxRow')
class OutboxTable extends Table {
  @override
  String get tableName => 'outbox';

  TextColumn get noteId => text()();
  DateTimeColumn get queuedAt => dateTime()();

  /// Rejected pushes so far; failing notes sink behind healthy ones.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {noteId};
}

/// Key/value sync metadata (the server-issued pull cursor).
@DataClassName('SyncStateRow')
class SyncStateTable extends Table {
  @override
  String get tableName => 'sync_state';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Local SQLite database (native SQLite on mobile/desktop, WASM on web).
///
/// Web needs `web/sqlite3.wasm` and `web/drift_worker.js`; see README.
@DriftDatabase(tables: [NotesTable, OutboxTable, SyncStateTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the on-device database named `notehaven`.
  AppDatabase.open()
    : super(
        driftDatabase(
          name: 'notehaven',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  /// Bump with every table change and add a step in [migration].
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 -> v2: soft delete, sync clock, outbox, sync state.
        await m.addColumn(notesTable, notesTable.deletedAt);
        await m.addColumn(notesTable, notesTable.rev);
        await m.addColumn(notesTable, notesTable.clock);
        await m.createTable(outboxTable);
        await m.createTable(syncStateTable);
        await customStatement('UPDATE notes SET clock = updated_at * 1000');
        // Every v1 note has never been synced, so queue them all; otherwise
        // notes written before v2 would never reach the server.
        await customStatement(
          'INSERT OR IGNORE INTO outbox (note_id, queued_at, attempts) '
          "SELECT id, CAST(strftime('%s', 'now') AS INTEGER), 0 FROM notes",
        );
      }
    },
  );
}
