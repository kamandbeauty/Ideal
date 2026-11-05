import 'package:sqflite/sqflite.dart';

import '../../core/ids.dart';
import '../../core/time_us.dart';
import '../../models/enums.dart';
import '../../models/project.dart';

/// All project-level queries. Soft delete only: the row and every child stay in
/// the database until the user confirms permanent deletion.
class ProjectDao {
  const ProjectDao(this._db);

  final Database _db;

  Future<List<Project>> listRecent({int limit = 50}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'projects',
      where: 'deleted_at_ms IS NULL',
      orderBy: 'CASE WHEN last_opened_at_ms IS NULL THEN 1 ELSE 0 END, '
          'last_opened_at_ms DESC, updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(Project.fromMap).toList(growable: false);
  }

  Future<List<Project>> listDeleted() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'projects',
      where: 'deleted_at_ms IS NOT NULL',
      orderBy: 'deleted_at_ms DESC',
    );
    return rows.map(Project.fromMap).toList(growable: false);
  }

  Future<Project?> findById(String id) async {
    final List<Map<String, Object?>> rows =
        await _db.query('projects', where: 'id = ?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return null;
    return Project.fromMap(rows.first);
  }

  Future<int> countActive() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM projects WHERE deleted_at_ms IS NULL',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> insert(Project project) async {
    await _db.insert('projects', project.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> update(Project project) async {
    await _db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[project.id],
    );
  }

  Future<void> rename(String id, String name) async {
    await _db.update(
      'projects',
      <String, Object?>{'name': name, 'updated_at_ms': Ids.nowMs()},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> setStatus(String id, ProjectStatus status, {String? lastEditLabel}) async {
    await _db.update(
      'projects',
      <String, Object?>{
        'status': status.dbValue,
        if (lastEditLabel != null) 'last_edit_label': lastEditLabel,
        'updated_at_ms': Ids.nowMs(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> touchOpened(String id) async {
    await _db.update(
      'projects',
      <String, Object?>{'last_opened_at_ms': Ids.nowMs()},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Soft delete. Returns the timestamp used so an "undo" toast can restore it.
  Future<int> softDelete(String id) async {
    final int now = Ids.nowMs();
    await _db.update(
      'projects',
      <String, Object?>{'deleted_at_ms': now},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return now;
  }

  Future<void> restore(String id) async {
    await _db.update(
      'projects',
      <String, Object?>{'deleted_at_ms': null},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Permanent deletion - callers must have shown a confirmation dialog.
  Future<void> hardDelete(String id) async {
    await _db.delete('projects', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<String> suggestCopyName(String sourceId) async {
    final Project? source = await findById(sourceId);
    if (source == null) return 'کپی پروژه';
    final String base = '${source.name} (کپی)';
    final List<Map<String, Object?>> rows = await _db.query(
      'projects',
      columns: <String>['name'],
      where: 'name LIKE ?',
      whereArgs: <Object?>['$base%'],
    );
    if (rows.isEmpty) return base;
    return '$base ${rows.length + 1}';
  }

  /// Last-edit summary used on the project card.
  static String humanizeEdit(int? lastOpenedAtMs) {
    if (lastOpenedAtMs == null) return 'باز نشده';
    final int deltaMs = Ids.nowMs() - lastOpenedAtMs;
    if (deltaMs < TimeUs.perMinute ~/ 1000) return 'همین حالا';
    final int minutes = deltaMs ~/ (TimeUs.perMinute ~/ 1000);
    if (minutes < 60) return '$minutes دقیقه پیش';
    final int hours = minutes ~/ 60;
    if (hours < 24) return '$hours ساعت پیش';
    return '${hours ~/ 24} روز پیش';
  }
}
