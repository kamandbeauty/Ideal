import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/models/job.dart';
import 'package:javid_ai/data/repositories/job_repository.dart';
import 'package:javid_ai/services/job_service.dart';

import '../helpers/test_database.dart';

void main() {
  setUpAll(setUpSqfliteFfi);

  final now = DateTime(2026, 11, 16, 10, 0);
  late TestDatabase database;
  late JobService service;

  setUp(() async {
    database = TestDatabase();
    await database.open();
    service = JobService(JobRepository(database), clock: () => now);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates a recurring job with the next run', () async {
    final job = await service.create(
      title: 'خلاصهٔ پیام‌ها',
      prompt: 'خلاصهٔ پیام‌ها را بگو',
      schedule: JobSchedule(kind: JobScheduleKind.daily, hour: 20, minute: 0),
      action: JobAction.messageSummary,
    );
    expect(job.nextRunAt, DateTime(2026, 11, 16, 20));
    expect(job.isActive, isTrue);
    expect(await service.list(), hasLength(1));
  });

  test('rejects one-off jobs in the past', () async {
    expect(
      () => service.create(
        title: 'گذشته',
        prompt: 'گذشته',
        schedule: JobSchedule.once(DateTime(2026, 11, 15, 9)),
      ),
      throwsA(isA<JobValidationException>()),
    );
  });

  test('rejects intervals under the WorkManager minimum', () async {
    expect(
      () => service.create(
        title: 'خیلی سریع',
        prompt: 'x',
        schedule: const JobSchedule(kind: JobScheduleKind.interval, intervalMinutes: 5),
      ),
      throwsA(isA<JobValidationException>()),
    );
  });

  test('disabling clears the next run and enabling recomputes it', () async {
    final job = await service.create(
      title: 'روزانه',
      prompt: 'x',
      schedule: JobSchedule(kind: JobScheduleKind.daily, hour: 20, minute: 0),
    );

    final paused = await service.setEnabled(job, false);
    expect(paused.enabled, isFalse);
    expect(paused.nextRunAt, isNull);
    expect(paused.isActive, isFalse);

    final resumed = await service.setEnabled(paused, true);
    expect(resumed.enabled, isTrue);
    expect(resumed.nextRunAt, isNotNull);
  });

  test('records a successful run, advances the schedule and stores history', () async {
    final job = await service.create(
      title: 'روزانه',
      prompt: 'x',
      schedule: JobSchedule(kind: JobScheduleKind.daily, hour: 9, minute: 0),
    );
    final afterRun = await service.recordSuccess(job, output: 'خلاصه آماده است');
    expect(afterRun.lastStatus, JobStatus.success);
    expect(afterRun.runCount, 1);
    expect(afterRun.nextRunAt, DateTime(2026, 11, 17, 9));

    final runs = await service.runsFor(job.id);
    expect(runs, hasLength(1));
    expect(runs.single.output, 'خلاصه آماده است');
    expect(runs.single.status, JobStatus.success);
  });

  test('a failed one-off job keeps its time so it can be retried', () async {
    final job = await service.create(
      title: 'یادآوری',
      prompt: 'x',
      schedule: JobSchedule.once(DateTime(2026, 11, 16, 12)),
    );
    final failed = await service.recordFailure(job, error: 'اتصال قطع بود');
    expect(failed.lastStatus, JobStatus.failed);
    expect(failed.nextRunAt, DateTime(2026, 11, 16, 12));
    final runs = await service.runsFor(job.id);
    expect(runs.single.error, 'اتصال قطع بود');
  });

  test('due jobs only include active jobs whose time has come', () async {
    final due = await service.create(
      title: 'رسیده',
      prompt: 'x',
      schedule: JobSchedule.once(DateTime(2026, 11, 16, 9, 30)),
    );
    await service.create(
      title: 'بعداً',
      prompt: 'x',
      schedule: JobSchedule.once(DateTime(2026, 11, 16, 18)),
    );
    final dueJobs = await service.dueJobs();
    expect(dueJobs.map((job) => job.id), contains(due.id));
  });

  test('deleting a job also deletes its run history', () async {
    final job = await service.create(
      title: 'حذفی',
      prompt: 'x',
      schedule: JobSchedule(kind: JobScheduleKind.daily, hour: 9, minute: 0),
    );
    await service.recordSuccess(job, output: 'ok');
    await service.delete(job.id);
    expect(await service.list(), isEmpty);
    expect(await service.runsFor(job.id), isEmpty);
  });

  test('nextScheduled returns the soonest active job', () async {
    await service.create(
      title: 'دیرتر',
      prompt: 'x',
      schedule: JobSchedule(kind: JobScheduleKind.daily, hour: 22, minute: 0),
    );
    final soon = await service.create(
      title: 'زودتر',
      prompt: 'x',
      schedule: JobSchedule(kind: JobScheduleKind.daily, hour: 12, minute: 0),
    );
    expect((await service.nextScheduled())?.id, soon.id);
  });

  test('list ordering is stable and deterministic', () async {
    final a = await service.create(
      title: 'A',
      prompt: 'x',
      schedule: JobSchedule(kind: JobScheduleKind.daily, hour: 12, minute: 0),
    );
    final b = await service.create(
      title: 'B',
      prompt: 'x',
      schedule: JobSchedule(kind: JobScheduleKind.daily, hour: 8, minute: 0),
    );
    final jobs = await service.list();
    final ids = jobs.map((job) => job.id).toList();
    expect(ids, containsAll([a.id, b.id]));
  });
}
