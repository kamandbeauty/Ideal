import 'dart:async';

import '../data/models/app_notification.dart';
import '../data/models/job.dart';
import 'briefing_service.dart';
import 'job_service.dart';
import 'native_bridge.dart';

/// The outcome of one scheduler tick, for the UI and for tests.
class JobTickResult {
  const JobTickResult({
    required this.ran,
    required this.failed,
    this.nextRunAt,
  });

  const JobTickResult.idle()
      : ran = const [],
        failed = const [],
        nextRunAt = null;

  final List<Job> ran;
  final List<Job> failed;

  /// When the soonest remaining job is due, used to re-arm the timer.
  final DateTime? nextRunAt;

  bool get isEmpty => ran.isEmpty && failed.isEmpty;
}

/// Keeps the Android alarm in sync with a job definition.
///
/// Kept separate from [JobService] so the service stays free of platform code
/// (and unit tests can run without a bridge).
class JobAlarm {
  const JobAlarm(this._bridge);

  final NativeBridge _bridge;

  /// Arms the alarm for [job]'s next run, or cancels it when there is none.
  Future<void> arm(Job job, {String? body}) async {
    final next = job.nextRunAt;
    if (next == null || !job.enabled) {
      await _bridge.cancelReminder(notificationIdFor(job.id));
      return;
    }
    await _bridge.scheduleReminder(
      reminderId: notificationIdFor(job.id),
      title: job.title,
      body: body ?? defaultBody(job),
      fireAt: next,
    );
  }

  /// Posts an in-app reminder notification for a finished run.
  Future<void> notify(Job job, String body) => _bridge.showNotification(
        id: notificationIdFor(job.id),
        title: job.title,
        body: body,
      );

  Future<void> cancel(String jobId) =>
      _bridge.cancelReminder(notificationIdFor(jobId));

  static String defaultBody(Job job) {
    switch (job.action) {
      case JobAction.reminder:
        return job.prompt.isEmpty ? job.title : job.prompt;
      case JobAction.dailyBriefing:
        return 'خلاصهٔ روزانه آماده است. برای شنیدن، جویده را باز کن.';
      case JobAction.messageSummary:
        return 'خلاصهٔ پیام‌ها آماده است.';
      case JobAction.assistantPrompt:
        return 'وظیفهٔ زمان‌بندی‌شده آماده اجراست.';
    }
  }

  /// Stable, positive 31-bit id derived from the job id (AlarmManager needs int).
  static int notificationIdFor(String jobId) {
    var hash = 0;
    for (final unit in jobId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}

/// Executes due jobs and keeps the in-app timer armed.
///
/// There are two triggers, and they are deliberately layered:
///
/// 1. **The native alarm** ([JobAlarm]) posts the notification even when the app
///    is dead. That path cannot call Dart code, so the alarm is re-armed after
///    every run to point at the *next* slot.
/// 2. **The in-app timer** ([JobScheduler]) runs the Dart side of the job
///    (briefing text, assistant answer) while the app is alive, then advances
///    the schedule and writes the history row.
///
/// A job that came due while the app was closed is not lost: it stays in `jobs`
/// with `next_run_at` in the past, and [runDue] catches up on the next start (or
/// resume) and records the run in history.
class JobRunner {
  JobRunner({
    required JobService jobs,
    required BriefingService briefing,
    required JobAlarm alarm,
    required Future<List<CapturedNotification>> Function() notifications,
    DateTime Function()? clock,
  })  : _jobs = jobs,
        _briefing = briefing,
        _alarm = alarm,
        _notifications = notifications,
        _clock = clock ?? DateTime.now;

  final JobService _jobs;
  final BriefingService _briefing;
  final JobAlarm _alarm;
  final Future<List<CapturedNotification>> Function() _notifications;
  final DateTime Function() _clock;

  /// Runs every job whose `nextRunAt` has passed and returns what happened.
  Future<JobTickResult> runDue() async {
    final due = await _jobs.dueJobs();
    if (due.isEmpty) {
      return JobTickResult(ran: const [], failed: const [], nextRunAt: await nextRunAt());
    }

    final now = _clock();
    final ran = <Job>[];
    final failed = <Job>[];

    for (final job in due) {
      Job updated;
      try {
        await _jobs.markRunning(job);
        final output = await _execute(job, now);
        updated = await _jobs.recordSuccess(job, output: output);
        ran.add(updated);
        if (job.notify) await _alarm.notify(updated, output);
      } catch (error) {
        // JobService advances recurring schedules on failure, so a broken job
        // can never spin forever; one-off jobs keep their slot for a retry.
        updated = await _jobs.recordFailure(job, error: '$error');
        failed.add(updated);
      }
      // Re-arm only this job so we never clobber another job's alarm.
      await _alarm.arm(updated);
    }

    return JobTickResult(
      ran: ran,
      failed: failed,
      nextRunAt: await nextRunAt(),
    );
  }

  /// Arms the alarm for the soonest job and returns when it is due.
  ///
  /// Called on start and after every change to the job list, so an alarm always
  /// exists for the next thing that will happen even if the app is killed.
  Future<DateTime?> nextRunAt() async {
    final job = await _jobs.nextScheduled();
    if (job == null) return null;
    await _alarm.arm(job);
    return job.nextRunAt;
  }

  /// Runs one job and returns the Persian text to show and speak.
  Future<String> _execute(Job job, DateTime now) async {
    switch (job.action) {
      case JobAction.reminder:
        return job.prompt.isEmpty ? job.title : job.prompt;
      case JobAction.dailyBriefing:
        final notifications = await _notifications();
        final all = await _jobs.list();
        return _briefing.build(
          now: now,
          notifications: notifications,
          jobs: all,
        );
      case JobAction.messageSummary:
        final notifications = await _notifications();
        final all = await _jobs.list();
        return _briefing.summarize(
          now: now,
          notifications: notifications,
          jobs: all,
        );
      case JobAction.assistantPrompt:
        // Custom prompts stay local. Without a configured cloud provider the app
        // says so instead of fabricating an answer.
        return '${job.prompt}\n'
            '(برای پاسخ آزاد، سرویس هوش مصنوعی را در تنظیمات روشن کن.)';
    }
  }
}

/// Keeps [JobRunner] ticking while the app is in the foreground.
///
/// The timer only fires for the soonest job (never a busy loop) and is capped at
/// one minute so a changed clock or a resumed app converges quickly.
class JobScheduler {
  JobScheduler(this._runner, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final JobRunner _runner;
  final DateTime Function() _clock;

  Timer? _timer;
  bool _running = false;

  static const _maxDelay = Duration(minutes: 1);
  static const _catchUpDelay = Duration(milliseconds: 250);

  /// Starts periodic execution. Safe to call twice.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    await tick();
  }

  /// Runs one tick; returns null when the scheduler is stopped.
  Future<JobTickResult?> tick() async {
    if (!_running) return null;
    JobTickResult? result;
    try {
      result = await _runner.runDue();
    } catch (_) {
      // A tick must never kill the timer: the next one retries.
    }
    await _scheduleNext(result?.nextRunAt ?? await _safeNext());
    return result;
  }

  Future<DateTime?> _safeNext() async {
    try {
      return await _runner.nextRunAt();
    } catch (_) {
      return null;
    }
  }

  Future<void> _scheduleNext(DateTime? nextRunAt) async {
    _timer?.cancel();
    if (!_running) return;
    var delay = _maxDelay;
    if (nextRunAt != null) {
      final until = nextRunAt.difference(_clock());
      if (until <= Duration.zero) {
        // Catch up just after the current frame instead of spinning.
        delay = _catchUpDelay;
      } else if (until < delay) {
        delay = until;
      }
    }
    _timer = Timer(delay, () => unawaited(tick()));
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  bool get isRunning => _running;
}
