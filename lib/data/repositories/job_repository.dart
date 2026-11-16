import '../local/app_database.dart';
import '../models/job.dart';
import '../models/job_run.dart';
import 'base_repository.dart';

/// Persistence for scheduled jobs and their execution history.
class JobRepository extends BaseRepository {
  JobRepository(super.database);

  Future<List<Job>> list() async {
    final database = await db;
    final rows = await database.query(
      AppDatabase.jobsTable,
      orderBy: 'enabled DESC, next_run_at IS NULL, next_run_at ASC',
    );
    return rows.map(Job.fromMap).toList(growable: false);
  }

  Future<Job?> findById(String id) async {
    final database = await db;
    final rows = await database.query(
      AppDatabase.jobsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Job.fromMap(rows.first);
  }

  /// Jobs whose next run is due at or before [now] and that are still active.
  Future<List<Job>> dueJobs(DateTime now) async {
    final database = await db;
    final rows = await database.query(
      AppDatabase.jobsTable,
      where: 'enabled = 1 AND next_run_at IS NOT NULL AND next_run_at <= ?',
      whereArgs: [now.millisecondsSinceEpoch],
      orderBy: 'next_run_at ASC',
    );
    return rows.map(Job.fromMap).toList(growable: false);
  }

  Future<void> upsert(Job job) => insertRow(AppDatabase.jobsTable, job.toMap());

  Future<void> delete(String id) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete(AppDatabase.jobRunsTable, where: 'job_id = ?', whereArgs: [id]);
      await txn.delete(AppDatabase.jobsTable, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> addRun(JobRun run) => insertRow(AppDatabase.jobRunsTable, run.toMap());

  Future<List<JobRun>> runsFor(String jobId, {int limit = 20}) async {
    final database = await db;
    final rows = await database.query(
      AppDatabase.jobRunsTable,
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(JobRun.fromMap).toList(growable: false);
  }

  Future<List<JobRun>> recentRuns({int limit = 30}) async {
    final database = await db;
    final rows = await database.query(
      AppDatabase.jobRunsTable,
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(JobRun.fromMap).toList(growable: false);
  }

  Future<int> purgeRunsBefore(DateTime cutoff) async {
    final database = await db;
    return database.delete(
      AppDatabase.jobRunsTable,
      where: 'started_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }
}
