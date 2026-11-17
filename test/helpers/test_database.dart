import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:javid_ai/data/local/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory database that uses the exact production DDL.
///
/// Every instance gets a unique `file:…?mode=memory` URI, so test files that the
/// runner executes in parallel never touch the same handle.
class TestDatabase extends AppDatabase {
  TestDatabase() : super(fileName: inMemoryDatabasePath);

  /// On-disk database (data survives `close()`), used by persistence tests.
  TestDatabase.file(String path) : super(fileName: path);
}

/// Opens the in-memory database with the production schema, bypassing the
/// private `open()` path that calls into the sqflite plugin channel.
Future<TestDatabase> openTestDatabase() async {
  final database = TestDatabase();
  addTearDown(database.close);
  await database.attachForTests(
    await databaseFactoryFfiNoIsolate.openDatabase(
      // A distinct path per instance: sqflite keys `:memory:` databases by path
      // with `singleInstance: true`, so two instances with the same name would
      // share one handle and one of them would, on close, drop the other's data
      // (and concurrent access would fail with "database is locked").
      'file:javid_test_${_counter++}?mode=memory&cache=shared',
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => AppDatabase.createSchema(db),
      ),
    ),
  );
  return database;
}

int _counter = 0;

/// Opens a real on-disk database in a temporary directory, for tests that must
/// prove data survives `close()` (an in-memory database cannot).
///
/// Pass [samePath] to reopen the same file.
Future<TestDatabase> openFileDatabase({String? samePath}) async {
  final path = samePath ?? p.join(Directory.systemTemp.path, 'javid_test_${_counter++}.db');
  final database = TestDatabase.file(path);
  addTearDown(() async {
    await database.close();
    if (samePath == null && await File(path).exists()) {
      await File(path).delete();
    }
  });
  await database.attachForTests(
    await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => AppDatabase.createSchema(db),
      ),
    ),
  );
  return database;
}

/// Initialises the FFI factory used by the tests (call in setUpAll).
///
/// The no-isolate factory runs SQLite on the current isolate. That matters for
/// widget tests: `testWidgets` uses a fake async zone, and a future completing
/// on a background isolate can never be awaited there.
void setUpSqfliteFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
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
