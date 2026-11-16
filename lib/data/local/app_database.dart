import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Thin wrapper around the application SQLite database.
///
/// The schema is managed with explicit, ordered migrations so that upgrades on
/// a user's phone never destroy data. A fresh install creates every table at
/// [schemaVersion]; existing installs run only the migrations they need.
class AppDatabase {
  AppDatabase({this.fileName = 'javid_ai.db'});

  /// Overridable for tests, which use an in-memory database instead.
  final String fileName;

  static const int schemaVersion = 1;

  /// Table names (kept in one place so repositories and tests share them).
  static const notesTable = 'notes';
  static const jobsTable = 'jobs';
  static const jobRunsTable = 'job_runs';
  static const assistantMessagesTable = 'assistant_messages';
  static const notificationsTable = 'notifications';
  static const settingsTable = 'settings';

  Database? _database;
  Future<Database>? _opening;

  /// The opened database. Call [open] first (done by [databaseProvider]).
  Database get db {
    final database = _database;
    if (database == null) {
      throw StateError('AppDatabase.open() must complete before use.');
    }
    return database;
  }

  bool get isOpen => _database != null;

  Future<Database> open() {
    if (_database != null) return Future.value(_database);
    return _opening ??= _openDatabase().then((database) {
      _database = database;
      _opening = null;
      return database;
    });
  }

  @protected
  Future<Database> _openDatabase() async {
    final path = p.join(await getDatabasesPath(), fileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) => createSchema(database),
      onUpgrade: (database, oldVersion, newVersion) async {
        await migrate(database, from: oldVersion, to: newVersion);
      },
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Creates the whole schema. Public so that tests can build a database with
  /// the exact same DDL (sqflite_common_ffi in memory).
  static Future<void> createSchema(Database database) async {
    final batch = database.batch();
    for (final statement in schemaStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  /// Ordered migrations; each entry upgrades from its index to index + 1.
  static const List<List<String>> migrations = <List<String>>[];

  static Future<void> migrate(
    Database database, {
    required int from,
    required int to,
  }) async {
    for (var version = from; version < to; version++) {
      final index = version - 1;
      if (index < 0 || index >= migrations.length) {
        throw StateError('Missing migration from schema v$version to v${version + 1}');
      }
      for (final statement in migrations[index]) {
        await database.execute(statement);
      }
    }
  }

  static const List<String> schemaStatements = <String>[
    '''
    CREATE TABLE $notesTable (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      body TEXT NOT NULL DEFAULT '',
      category TEXT NOT NULL DEFAULT 'general',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_pinned INTEGER NOT NULL DEFAULT 0,
      source TEXT NOT NULL DEFAULT 'text'
    )
    ''',
    'CREATE INDEX idx_notes_updated ON $notesTable (updated_at DESC)',
    'CREATE INDEX idx_notes_category ON $notesTable (category)',
    '''
    CREATE TABLE $jobsTable (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      prompt TEXT NOT NULL DEFAULT '',
      kind TEXT NOT NULL DEFAULT 'reminder',
      schedule TEXT NOT NULL DEFAULT '{}',
      action TEXT NOT NULL DEFAULT 'reminder',
      next_run_at INTEGER,
      created_at INTEGER NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      notify INTEGER NOT NULL DEFAULT 1,
      run_count INTEGER NOT NULL DEFAULT 0,
      last_run_at INTEGER,
      last_status TEXT NOT NULL DEFAULT 'pending',
      last_error TEXT,
      work_id INTEGER
    )
    ''',
    'CREATE INDEX idx_jobs_next_run ON $jobsTable (next_run_at)',
    '''
    CREATE TABLE $jobRunsTable (
      id TEXT PRIMARY KEY NOT NULL,
      job_id TEXT NOT NULL,
      started_at INTEGER NOT NULL,
      finished_at INTEGER,
      status TEXT NOT NULL DEFAULT 'pending',
      output TEXT,
      error TEXT,
      trigger TEXT NOT NULL DEFAULT 'scheduled',
      FOREIGN KEY (job_id) REFERENCES $jobsTable (id) ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX idx_job_runs_job ON $jobRunsTable (job_id, started_at DESC)',
    '''
    CREATE TABLE $assistantMessagesTable (
      id TEXT PRIMARY KEY NOT NULL,
      text TEXT NOT NULL,
      role TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      source TEXT NOT NULL DEFAULT 'text',
      meta TEXT
    )
    ''',
    'CREATE INDEX idx_messages_created ON $assistantMessagesTable (created_at DESC)',
    '''
    CREATE TABLE $notificationsTable (
      id TEXT PRIMARY KEY NOT NULL,
      package_name TEXT NOT NULL,
      app_label TEXT NOT NULL DEFAULT '',
      sender TEXT NOT NULL DEFAULT '',
      text TEXT NOT NULL DEFAULT '',
      posted_at INTEGER NOT NULL,
      captured_at INTEGER NOT NULL,
      dedupe_key TEXT NOT NULL,
      is_group_summary INTEGER NOT NULL DEFAULT 0,
      is_read INTEGER NOT NULL DEFAULT 0,
      is_urgent INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE UNIQUE INDEX idx_notifications_dedupe ON $notificationsTable (dedupe_key)',
    'CREATE INDEX idx_notifications_posted ON $notificationsTable (posted_at DESC)',
    '''
    CREATE TABLE $settingsTable (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL
    )
    ''',
  ];
}
