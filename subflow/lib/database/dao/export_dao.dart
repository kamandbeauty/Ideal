import 'package:sqflite/sqflite.dart';

import '../../core/ids.dart';
import '../../models/export_job.dart';

class ExportJobDao {
  const ExportJobDao(this._db);

  final Database _db;

  Future<void> insert(ExportJob job) async {
    await _db.insert('export_jobs', job.toMap());
  }

  Future<List<ExportJob>> historyOfProject(String projectId, {int limit = 20}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'export_jobs',
      where: 'project_id = ?',
      whereArgs: <Object?>[projectId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(ExportJob.fromMap).toList(growable: false);
  }

  Future<void> finish(
    String jobId, {
    required String status,
    String? outputPath,
    String? errorCode,
  }) async {
    await _db.update(
      'export_jobs',
      <String, Object?>{
        'status': status,
        'output_path': outputPath,
        'error_code': errorCode,
        'finished_at_ms': Ids.nowMs(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[jobId],
    );
  }
}
