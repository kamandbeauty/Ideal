import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import 'base_repository.dart';

/// Key/value settings stored in SQLite.
///
/// Non-sensitive preferences live here; API credentials are kept separately in
/// the platform keystore (see `SecretStore`).
class SettingsRepository extends BaseRepository {
  SettingsRepository(super.database);

  Future<String?> read(String key) async {
    final database = await db;
    final rows = await database.query(
      AppDatabase.settingsTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<bool> readBool(String key, {required bool fallback}) async {
    final value = await read(key);
    if (value == null) return fallback;
    return value == 'true';
  }

  Future<void> write(String key, String value) async {
    final database = await db;
    await database.insert(
      AppDatabase.settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> writeBool(String key, bool value) => write(key, value.toString());

  Future<void> delete(String key) async {
    final database = await db;
    await database.delete(AppDatabase.settingsTable, where: 'key = ?', whereArgs: [key]);
  }

  Future<Map<String, String>> readAll() async {
    final database = await db;
    final rows = await database.query(AppDatabase.settingsTable);
    return {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
  }
}
