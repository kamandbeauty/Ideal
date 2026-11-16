import 'package:javid_ai/data/local/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory database that uses the exact production DDL.
///
/// Each instance gets its own connection. sqflite's `:memory:` database is
/// shared by path, so tests must close every instance (see `tearDown`) to keep
/// suites isolated – the shared helper documents that contract.
class TestDatabase extends AppDatabase {
  TestDatabase() : super(fileName: inMemoryDatabasePath);
}

/// Opens the in-memory database with the production schema, bypassing the
/// private `open()` path that calls into the sqflite plugin channel.
Future<TestDatabase> openTestDatabase() async {
  final database = TestDatabase();
  await database.attachForTests(
    await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => AppDatabase.createSchema(db),
      ),
    ),
  );
  return database;
}

/// Initialises the FFI factory used by the in-memory database (call in setUpAll).
void setUpSqfliteFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Opens a clean in-memory database and wipes any rows left by a previous test.
///
/// sqflite identifies in-memory databases by path, so the schema survives
/// between `close()` calls in the same process. Opening the same handle again
/// and deleting every row gives each test a deterministic empty state without
/// needing a distinct file per test.
Future<TestDatabase> openCleanDatabase() async {
  final database = await openTestDatabase();
  final db = await database.open();
  for (final table in const [
    'assistant_messages',
    'job_runs',
    'jobs',
    'notifications',
    'notes',
    'settings',
  ]) {
    await db.delete(table);
  }
  return database;
}
