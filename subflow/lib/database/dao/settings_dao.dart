import 'package:sqflite/sqflite.dart';

import '../../core/ids.dart';

/// Key/value settings. One storage story for the whole app: no SharedPreferences
/// means settings survive with the project database and are trivially testable.
class SettingsDao {
  const SettingsDao(this._db);

  final Database _db;

  Future<String?> get(String key) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'app_settings',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await _db.insert(
      'app_settings',
      <String, Object?>{'key': key, 'value': value, 'updated_at_ms': Ids.nowMs()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> getBool(String key, {bool fallback = false}) async {
    final String? raw = await get(key);
    if (raw == null) return fallback;
    return raw == '1' || raw == 'true';
  }

  Future<void> setBool(String key, bool value) => set(key, value ? '1' : '0');
}
