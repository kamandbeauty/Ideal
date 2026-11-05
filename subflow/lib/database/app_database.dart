import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/logger.dart';

/// SQLite access point.
///
/// The schema is *not* duplicated in Dart: the exact .sql files in
/// `assets/db/` are executed here, and the same files are run against a real
/// SQLite by `tools/db-check/check_schema.py`. One source of truth, verified in
/// CI without a device.
///
/// Migration rule: apply every migration whose version is greater than the
/// database's current `user_version`, each inside its own transaction.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? fileName})
      : _factory = factory ?? databaseFactory,
        _fileName = fileName ?? SubFlowInfo.databaseName;

  final DatabaseFactory _factory;
  final String _fileName;
  Database? _db;
  static const SfLog _log = SfLog('db');

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final String dir = p.join(await _factory.getDatabasesPath(), SubFlowInfo.databaseDir);
    final String path = p.join(dir, _fileName);
    final _Manifest manifest = await _loadManifest();
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: manifest.schemaVersion,
        onConfigure: _applyPragmas,
        onCreate: (Database db, int version) async {
          await _applyMigrations(db, manifest, upto: version);
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          _log.d('upgrading schema $oldVersion -> $newVersion');
          await _applyMigrations(db, manifest, upto: newVersion);
        },
      ),
    );
  }

  /// Applies the connection pragmas.
  ///
  /// `PRAGMA journal_mode` returns the resulting mode, and sqflite's `execute()`
  /// rejects statements that produce rows ("Queries can be performed using
  /// SQLiteDatabase query or rawQuery methods only"), so every pragma goes
  /// through `rawQuery`. Each one is also applied independently and a refusal is
  /// logged rather than thrown: a device that dislikes a pragma must not make
  /// the whole app unopenable, which is exactly what happened in 0.2.0.
  static Future<void> _applyPragmas(Database db) async {
    await _tryPragma(db, 'PRAGMA foreign_keys = ON');
    await _tryPragma(db, 'PRAGMA journal_mode = WAL');
    await _tryPragma(db, 'PRAGMA synchronous = NORMAL');
  }

  static Future<void> _tryPragma(Database db, String sql) async {
    try {
      await db.rawQuery(sql);
    } on Object catch (error) {
      _log.e('pragma not applied: $sql', error);
    }
  }

  Future<void> _applyMigrations(
    Database db,
    _Manifest manifest, {
    required int upto,
  }) async {
    final int current = await _currentVersion(db);
    for (final _Migration migration in manifest.migrations) {
      if (migration.version <= current || migration.version > upto) continue;
      final String sql = await rootBundle.loadString(migration.asset);
      final List<String> statements = splitStatements(sql);
      if (statements.isEmpty) {
        throw AppFailure(
          AppErrorCode.database,
          'فایل مهاجرت ${migration.asset} خالی است.',
        );
      }
      await db.transaction((Transaction txn) async {
        for (int i = 0; i < statements.length; i++) {
          await _execute(txn, statements[i], i);
        }
        // sqflite writes user_version itself once the callbacks return; setting
        // it here keeps [_currentVersion] honest for later migrations, and stays
        // best-effort so a device that dislikes the statement cannot brick boot.
        try {
          await txn.rawQuery('PRAGMA user_version = ${migration.version}');
        } on Object catch (error) {
          _log.e('user_version not set inside migration v${migration.version}', error);
        }
      });
      _log.d('applied migration v${migration.version} (${statements.length} statements)');
    }
  }

  /// Runs one migration statement.
  ///
  /// Two Android-only rules are handled here, both learned from devices rather
  /// than from the checker:
  ///   * a `PRAGMA` returns a row, and sqflite's `execute()` rejects that
  ///     ("Queries can be performed using ... rawQuery methods only", the 0.2.0
  ///     crash);
  ///   * a statement that contains no actual SQL — e.g. a chunk made only of
  ///     `--` comments — fails on Android's `execSQL` with "not an error (code 0
  ///     SQLITE_OK)", the 0.2.1 crash. Comment-only chunks are already removed by
  ///     [splitStatements]; this is the belt to that braces.
  static Future<void> _execute(Transaction txn, String statement, int index) async {
    if (statement.toUpperCase().startsWith('PRAGMA')) {
      await txn.rawQuery(statement);
      return;
    }
    try {
      await txn.execute(statement);
    } on DatabaseException catch (error) {
      if (!error.toString().contains('code 0')) rethrow;
      _log.e('statement ${index + 1} retried through rawQuery: '
          '${error.toString().split('\n').first}');
      await txn.rawQuery(statement);
    }
  }

  Future<int> _currentVersion(Database db) async {
    final List<Map<String, Object?>> rows = await db.rawQuery('PRAGMA user_version');
    if (rows.isEmpty) return 0;
    return (rows.first.values.first as int?) ?? 0;
  }

  Future<_Manifest> _loadManifest() async {
    try {
      final String raw = await rootBundle.loadString(SubFlowInfo.migrationManifestAsset);
      return _Manifest.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (error) {
      throw AppFailure(AppErrorCode.database, 'فهرست مهاجرت‌های دیتابیس خوانده نشد.', cause: error);
    }
  }

  /// Splits a migration file into single, executable statements.
  ///
  /// SQL comments are removed and empty fragments dropped *before* a statement
  /// reaches sqflite. This is not cosmetic: the schema header lists its
  /// conventions and ends those lines with `;`, so a naive split on `;` yields a
  /// chunk that is only comments, and Android's `execSQL` answers that with
  /// "not an error (code 0 SQLITE_OK)". That is exactly how 0.2.1 still failed to
  /// launch even though the desktop SQLite used in `flutter test` accepted it.
  ///
  /// The tokenizer understands `'...'`/`"..."`/`` `...` `` quoting (so a `;` or
  /// `--` inside a literal is text, and `''` stays an escaped quote), `--` line
  /// comments and `/* ... */` block comments.
  static List<String> splitStatements(String sql) {
    final List<String> statements = <String>[];
    final StringBuffer current = StringBuffer();
    String? quote;
    bool inLineComment = false;
    bool inBlockComment = false;

    void flush() {
      final String statement = current.toString().trim();
      current.clear();
      if (statement.isNotEmpty) statements.add(statement);
    }

    for (int i = 0; i < sql.length; i++) {
      final String char = sql[i];
      final String next = i + 1 < sql.length ? sql[i + 1] : '';

      if (inLineComment) {
        if (char == '\n') {
          inLineComment = false;
          current.write('\n');
        }
        continue;
      }
      if (inBlockComment) {
        if (char == '*' && next == '/') {
          inBlockComment = false;
          i++;
        }
        continue;
      }
      if (quote != null) {
        current.write(char);
        if (char == quote) {
          if (next == quote) {
            current.write(next);
            i++;
          } else {
            quote = null;
          }
        }
        continue;
      }
      if (char == "'" || char == '"' || char == '`') {
        quote = char;
        current.write(char);
        continue;
      }
      if (char == '-' && next == '-') {
        inLineComment = true;
        i++;
        continue;
      }
      if (char == '/' && next == '*') {
        inBlockComment = true;
        i++;
        continue;
      }
      if (char == ';') {
        flush();
        continue;
      }
      current.write(char);
    }
    flush();
    return List<String>.unmodifiable(statements);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

class _Migration {
  const _Migration(this.version, this.asset);

  final int version;
  final String asset;
}

class _Manifest {
  const _Manifest(this.schemaVersion, this.migrations);

  final int schemaVersion;
  final List<_Migration> migrations;

  factory _Manifest.fromJson(Map<String, Object?> json) {
    final List<Object?> raw = (json['migrations'] as List<Object?>?) ?? const <Object?>[];
    final List<_Migration> migrations = raw
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> entry) => _Migration(
              (entry['version'] as num).toInt(),
              entry['file']! as String,
            ))
        .toList(growable: false);
    return _Manifest((json['schemaVersion'] as num?)?.toInt() ?? migrations.length, migrations);
  }
}
