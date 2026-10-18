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

  @override
  Set<Column> get primaryKey => {id};
}

/// Local SQLite database (native SQLite on mobile/desktop, WASM on web).
///
/// Web needs `web/sqlite3.wasm` and `web/drift_worker.js`; see README.
@DriftDatabase(tables: [NotesTable])
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

  /// Bump with every table change and add a step in a `MigrationStrategy`.
  @override
  int get schemaVersion => 1;
}
