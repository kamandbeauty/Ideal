import 'package:sqflite/sqflite.dart';

import '../../models/ai_model.dart';

/// Offline model registry (whisper variants, translation engines).
class ModelDao {
  const ModelDao(this._db);

  final Database _db;

  Future<List<AiModel>> all() async {
    final List<Map<String, Object?>> rows =
        await _db.query('ai_models', orderBy: 'kind ASC, size_bytes ASC');
    return rows.map(AiModel.fromMap).toList(growable: false);
  }

  Future<void> upsert(AiModel model) async {
    await _db.insert('ai_models', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AiModel?> defaultOf(String kindDbValue) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'ai_models',
      where: 'kind = ? AND is_default = 1 AND state = ?',
      whereArgs: <Object?>[kindDbValue, 'installed'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AiModel.fromMap(rows.first);
  }
}
