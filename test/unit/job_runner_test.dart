import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/models/app_notification.dart';
import 'package:javid_ai/data/models/job.dart';
import 'package:javid_ai/data/repositories/job_repository.dart';
import 'package:javid_ai/data/repositories/notification_repository.dart';
import 'package:javid_ai/services/briefing_service.dart';
import 'package:javid_ai/services/job_runner.dart';
import 'package:javid_ai/services/job_service.dart';
import 'package:javid_ai/services/native_bridge.dart';

import '../helpers/test_database.dart';

/// Records every bridge call instead of touching a platform channel.
class RecordingBridge extends NativeBridge {
  final alarms = <({int id, String title, DateTime at})>[];
  final posted = <({int id, String title, String body})>[];
  final cancelled = <int>[];

  @override
  Future<bool> scheduleReminder({
    required int reminderId,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    alarms.add((id: reminderId, title: title, at: fireAt));
    return true;
  }

  @override
  Future<bool> cancelReminder(int reminderId) async {
    cancelled.add(reminderId);
    return true;
  }

  @override
  Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    posted.add((id: id, title: title, body: body));
    return true;
  }
}

void main() {
  setUpAll(setUpSqfliteFfi);

  late TestDatabase database;
  late JobService jobs;
  late NotificationRepository notifications;
  late RecordingBridge bridge;
  late DateTime now;
  late JobRunner runner;

  setUp(() async {
    database = await openCleanDatabase();
    now = DateTime(2026, 11, 16, 9, 30);
    jobs = JobService(JobRepository(database), clock: () => now);
    notifications = NotificationRepository(database);
    bridge = RecordingBridge();
    runner = JobRunner(
      jobs: jobs,
      briefing: const BriefingService(),
      alarm: JobAlarm(bridge),
      notifications: notifications.list,
      clock: () => now,
    );
  });

  tearDown(() async {
    await database.close();
  });

  /// Writes a job directly so it can already be due (create() rejects the past).
  Future<Job> dueJob({String title = 'تماس با مادر', JobAction? action}) async {
    final job = Job(
      id: 'due-${title.hashCode}',
      title: title,
      prompt: 'به مادر زنگ بزن',
      kind: JobKind.reminder,
      schedule: JobSchedule.once(DateTime(2026, 11, 16, 9)),
      action: action ?? JobAction.reminder,
      nextRunAt: DateTime(2026, 11, 16, 9),
      createdAt: DateTime(2026, 11, 15, 20),
    );
    await JobRepository(database).upsert(job);
    return job;
  }

  test('a due reminder runs, posts a notification and records history',
      () async {
    final job = await dueJob();

    final result = await runner.runDue();

    expect(result.ran, hasLength(1));
    expect(result.ran.single.id, job.id);
    expect(result.failed, isEmpty);
    expect(bridge.posted, hasLength(1));
    expect(bridge.posted.single.title, 'تماس با مادر');
    expect(bridge.posted.single.body, 'به مادر زنگ بزن');

    final history = await jobs.runsFor(job.id);
    expect(history, hasLength(1));
    expect(history.single.output, 'به مادر زنگ بزن');

    // A one-off job has no next run, so its alarm must be cancelled.
    expect(bridge.cancelled, contains(JobAlarm.notificationIdFor(job.id)));
  });

  test('nothing happens when no job is due', () async {
    now = DateTime(2026, 11, 16, 8);
    await jobs.create(
      title: 'بعداً',
      prompt: 'x',
      schedule: JobSchedule.once(DateTime(2026, 11, 16, 10)),
    );

    final result = await runner.runDue();

    expect(result.ran, isEmpty);
    expect(result.failed, isEmpty);
    expect(result.nextRunAt, DateTime(2026, 11, 16, 10));
    expect(bridge.alarms.single.at, DateTime(2026, 11, 16, 10));
  });

  test('a recurring job advances to its next slot after running', () async {
    final job = Job(
      id: 'daily',
      title: 'خلاصهٔ روزانه',
      prompt: 'خلاصه بده',
      kind: JobKind.briefing,
      schedule: const JobSchedule(kind: JobScheduleKind.daily, hour: 9, minute: 0),
      action: JobAction.dailyBriefing,
      nextRunAt: DateTime(2026, 11, 16, 9),
      createdAt: DateTime(2026, 11, 10),
    );
    await JobRepository(database).upsert(job);

    final result = await runner.runDue();

    expect(result.ran.single.nextRunAt, DateTime(2026, 11, 17, 9));
    // The briefing is built from real rows — here, none — and never invents.
    expect(bridge.posted.single.body, contains('خلاصه'));
    expect(bridge.posted.single.body, isNot(contains('null')));
    // The alarm points at tomorrow, not at the run that just happened.
    expect(
      bridge.alarms.where((call) => call.at == DateTime(2026, 11, 17, 9)),
      isNotEmpty,
    );
  });

  test('the briefing summarises captured notifications instead of inventing',
      () async {
    await notifications.insertIfNew(
      CapturedNotification(
        id: 'n1',
        packageName: 'com.whatsapp',
        appLabel: 'واتساپ',
        sender: 'سارا',
        text: 'فردا جلسه داریم',
        postedAt: DateTime(2026, 11, 16, 8, 40),
        capturedAt: DateTime(2026, 11, 16, 8, 40),
        dedupeKey: 'com.whatsapp|سارا|فردا جلسه داریم',
      ),
    );
    await dueJob(title: 'خلاصه', action: JobAction.dailyBriefing);

    await runner.runDue();

    expect(bridge.posted.single.body, contains('پیام'));
    expect(bridge.posted.single.body, isNot(contains('پیام تازه‌ای ثبت نشده')));
  });

  test('a failing job is recorded as failed and does not throw', () async {
    await dueJob();
    final broken = JobRunner(
      jobs: jobs,
      briefing: const BriefingService(),
      alarm: JobAlarm(bridge),
      notifications: () async => throw StateError('db down'),
      clock: () => now,
    );
    // A reminder job does not touch the notification repository, so use the
    // briefing action to exercise the failure path.
    final job = Job(
      id: 'broken',
      title: 'خلاصه',
      prompt: 'خلاصه بده',
      kind: JobKind.briefing,
      schedule: const JobSchedule(kind: JobScheduleKind.daily, hour: 9, minute: 0),
      action: JobAction.dailyBriefing,
      nextRunAt: DateTime(2026, 11, 16, 9),
      createdAt: DateTime(2026, 11, 10),
    );
    await JobRepository(database).upsert(job);

    final result = await broken.runDue();

    expect(result.failed, isNotEmpty);
    final failed = result.failed.firstWhere((item) => item.id == 'broken');
    expect(failed.lastStatus, JobStatus.failed);
    expect(failed.lastError, isNotNull);
  });

  test('the scheduler ticks, then stops cleanly', () async {
    await dueJob();
    final scheduler = JobScheduler(runner, clock: () => now);
    expect(scheduler.isRunning, isFalse);

    await scheduler.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final ran = await jobs.runsFor('due-${'تماس با مادر'.hashCode}');
    expect(ran, hasLength(1));

    scheduler.stop();
    expect(scheduler.isRunning, isFalse);
    expect(await scheduler.tick(), isNull);
  });
}
