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
        for (final String statement in statements) {
          // The .sql files carry their own PRAGMA lines (the same files are run
          // by tools/db-check against real SQLite). sqflite rejects a PRAGMA
          // through execute(), so those go through rawQuery instead.
          if (statement.toUpperCase().startsWith('PRAGMA')) {
            await txn.rawQuery(statement);
          } else {
            await txn.execute(statement);
          }
        }
        // rawQuery, not execute: the same sqflite rule that broke 0.2.0.
        await txn.rawQuery('PRAGMA user_version = ${migration.version}');
      });
      _log.d('applied migration v${migration.version} (${statements.length} statements)');
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

  /// Splits a migration file into single statements.
  ///
  /// Rule: a statement ends at `;` followed by a newline. This is deliberately
  /// simple and identical to the Python checker, and the schema files are
  /// written so no `;` appears inside a comment or string literal.
  static List<String> splitStatements(String sql) {
    return sql
        .split(RegExp(r';[ \t]*\n'))
        .map((String chunk) => chunk.trim())
        .where((String chunk) => chunk.isNotEmpty)
        .toList(growable: false);
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
