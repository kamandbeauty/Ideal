import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';

/// Shared base for repositories: lazily opens the database and exposes a
/// typed-error-free insert helper.
abstract class BaseRepository {
  BaseRepository(this.database);

  final AppDatabase database;

  Future<Database> get db => database.open();

  Future<int> insertRow(String table, Map<String, Object?> values) async {
    final database = await db;
    return database.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
