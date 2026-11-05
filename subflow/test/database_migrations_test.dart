import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/database/app_database.dart';

/// The migration splitter feeds raw SQL to sqflite, and two device-only rules
/// bite here:
///   * a statement that returns a row (a `PRAGMA`) must not go through
///     `execute()` (0.2.0 crash);
///   * a statement that contains no SQL at all — a chunk made only of `--`
///     comments — makes Android's `execSQL` fail with "not an error (code 0
///     SQLITE_OK)" (0.2.1 crash).
/// Desktop SQLite used in `flutter test` accepts both, which is why these are
/// tested on the splitter output rather than only by opening a database.
void main() {
  test('splits SQL statements on ";"', () {
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

  test('ignores empty fragments', () {
    expect(AppDatabase.splitStatements(''), isEmpty);
    expect(AppDatabase.splitStatements(';\n'), isEmpty);
    expect(AppDatabase.splitStatements(';;\n;\n'), isEmpty);
  });

  test('drops a comment-only header instead of sending it to execSQL', () {
    const String sql = '-- schema v1\n'
        '--   * columns end with a semicolon;\n'
        '--   * nothing else;\n'
        'CREATE TABLE a (x INTEGER);\n';
    final List<String> statements = AppDatabase.splitStatements(sql);
    expect(statements, <String>['CREATE TABLE a (x INTEGER)']);
    expect(statements.any((String s) => s.trimLeft().startsWith('--')), isFalse);
  });

  test('strips trailing and inline comments', () {
    const String sql = 'CREATE TABLE a ( -- inline note\n  x INTEGER -- trailing\n);\n';
    final List<String> statements = AppDatabase.splitStatements(sql);
    expect(statements.length, 1);
    expect(statements.single.contains('--'), isFalse);
    expect(statements.single.contains('x INTEGER'), isTrue);
  });

  test('strips block comments, including multi-line ones', () {
    const String sql = '/* header\n   spanning; lines */\nCREATE TABLE a (x INTEGER);\n/* tail */';
    final List<String> statements = AppDatabase.splitStatements(sql);
    expect(statements.length, 1);
    expect(statements.single, 'CREATE TABLE a (x INTEGER)');
  });

  test('a ";" inside a string literal does not split the statement', () {
    const String sql = "INSERT INTO a (x) VALUES ('one; two');\n";
    final List<String> statements = AppDatabase.splitStatements(sql);
    expect(statements.length, 1);
    expect(statements.single.contains("'one; two'"), isTrue);
  });

  test('"--" inside a string literal is text, not a comment', () {
    const String sql = "INSERT INTO a (x) VALUES ('-- not a comment; really');\n";
    final List<String> statements = AppDatabase.splitStatements(sql);
    expect(statements.length, 1);
    expect(statements.single.contains('really'), isTrue);
  });

  test('doubled quotes stay inside the literal', () {
    const String sql = "INSERT INTO a (x) VALUES ('it''s; fine');\n";
    final List<String> statements = AppDatabase.splitStatements(sql);
    expect(statements.length, 1);
    expect(statements.single.contains("it''s; fine"), isTrue);
  });

  test('migration files split into executable statements only', () {
    final Directory dbDir = Directory('assets/db');
    expect(dbDir.existsSync(), isTrue);
    int checked = 0;
    for (final FileSystemEntity entity in dbDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.sql')) continue;
      final List<String> statements =
          AppDatabase.splitStatements(File(entity.path).readAsStringSync());
      expect(statements.length, greaterThan(3), reason: entity.path);
      // The 0.2.1 crash in one assertion: nothing comment-only may reach sqflite.
      for (final String statement in statements) {
        expect(statement.trimLeft().startsWith('--'), isFalse,
            reason: '${entity.path}: statement starts with a comment: '
                '${statement.substring(0, statement.length < 40 ? statement.length : 40)}');
        expect(statement.contains('--'), isFalse, reason: '${entity.path}: leftover comment');
        expect(RegExp(r'^[A-Za-z]+').hasMatch(statement), isTrue,
            reason: '${entity.path}: statement does not start with a keyword');
      }
      expect(statements.last, contains('PRAGMA user_version'), reason: entity.path);
      checked += 1;
    }
    expect(checked, greaterThanOrEqualTo(2));
  });

  test('every schema object of the v1 file survives the split', () {
    final List<String> statements =
        AppDatabase.splitStatements(File('assets/db/001_init.sql').readAsStringSync());
    expect(statements.where((String s) => s.startsWith('CREATE TABLE')).length, 15);
    expect(statements.where((String s) => s.startsWith('CREATE INDEX')).length, greaterThan(5));
    expect(statements.first, 'PRAGMA foreign_keys = ON');
  });
}
