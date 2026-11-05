import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/database/app_database.dart';

/// The migration splitter is the one piece of database plumbing that can be
/// tested without an Android runtime, and the exact same rule is re-verified
/// against real SQLite by `tools/db-check/check_schema.py`.
void main() {
  test('splits SQL statements on ";" + newline only', () {
    const String sql = 'CREATE TABLE a (x INTEGER);\n\nCREATE INDEX i ON a(x);\n';
    final List<String> statements = AppDatabase.splitStatements(sql);
    expect(statements.length, 2);
    expect(statements.first, startsWith('CREATE TABLE a'));
    expect(statements.last, startsWith('CREATE INDEX i'));
  });

  test('keeps multi-line statements intact', () {
    const String sql = 'CREATE TABLE t (\n  id TEXT,\n  n INTEGER\n);\n';
    final List<String> statements = AppDatabase.splitStatements(sql);
    expect(statements.length, 1);
    expect(statements.first.contains('n INTEGER'), isTrue);
  });

  test('ignores empty trailing chunks', () {
    expect(AppDatabase.splitStatements(''), isEmpty);
    expect(AppDatabase.splitStatements(';\n'), isEmpty);
  });

  test('migration files on disk are non-empty and end with user_version', () {
    final Directory dbDir = Directory('assets/db');
    expect(dbDir.existsSync(), isTrue);
    for (final FileSystemEntity entity in dbDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.sql')) continue;
      final List<String> statements =
          AppDatabase.splitStatements(File(entity.path).readAsStringSync());
      expect(statements.length, greaterThan(3), reason: entity.path);
      expect(statements.last, contains('PRAGMA user_version'), reason: entity.path);
    }
  });
}
