import '../core/utils/id_gen.dart';
import '../data/models/job.dart';
import '../data/models/job_run.dart';
import '../data/repositories/job_repository.dart';

/// Thrown when a job definition cannot be executed as requested.
class JobValidationException implements Exception {
  JobValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Scheduling and bookkeeping for the job manager.
///
/// The service owns the *policy* (what a job does, when it fires next, how
/// failures are retried); the WorkManager bridge owns the *transport* (asking
/// Android to wake the app up).
class JobService {
  JobService(
    this._repository, {
    DateTime Function()? clock,
    this.onScheduleChanged,
  }) : _clock = clock ?? DateTime.now;

  final JobRepository _repository;
  final DateTime Function() _clock;

  /// Called after a job's schedule changes so Android can be re-armed.
  /// Optional: unit tests and the repository-only path leave it null.
  final Future<void> Function(Job job)? onScheduleChanged;

  /// WorkManager cannot schedule periodic work more often than every 15 min.
  static const minimumIntervalMinutes = 15;

  static const maxRetries = 3;

  Future<List<Job>> list() => _repository.list();

  Future<Job?> findById(String id) => _repository.findById(id);

  Future<List<JobRun>> runsFor(String jobId, {int limit = 20}) =>
      _repository.runsFor(jobId, limit: limit);

  Future<List<JobRun>> recentRuns() => _repository.recentRuns();

  /// Creates and stores a job, computing its first run time.
  Future<Job> create({
    required String title,
    required String prompt,
    required JobSchedule schedule,
    JobAction action = JobAction.reminder,
    JobKind kind = JobKind.custom,
    bool notify = true,
    bool enabled = true,
  }) async {
    _validateSchedule(schedule);
    final now = _clock();
    final nextRun = enabled ? schedule.nextRun(now) : null;
    if (enabled && nextRun == null) {
      throw JobValidationException('زمان اجرای این وظیفه در گذشته است.');
    }
    final job = Job(
      id: newId(),
      title: title.trim().isEmpty ? _titleFromPrompt(prompt) : title.trim(),
      prompt: prompt.trim(),
      kind: kind,
      schedule: schedule,
      action: action,
      nextRunAt: nextRun,
      createdAt: now,
      enabled: enabled,
      notify: notify,
      workId: null,
    );
    await _repository.upsert(job);
    await onScheduleChanged?.call(job);
    return job;
  }

  /// Enables or disables a job. Re-enabling recomputes the next run so a job
  /// that was paused for days does not fire a burst of missed runs.
  Future<Job> setEnabled(Job job, bool enabled, {int? workId}) async {
    final now = _clock();
    final DateTime? nextRun;
    if (enabled) {
      nextRun = job.schedule.nextRun(now);
      if (nextRun == null) {
        throw JobValidationException('این وظیفه زمان اجرای بعدی ندارد.');
      }
    } else {
      nextRun = null;
    }
    final updated = job.copyWith(
      enabled: enabled,
      nextRunAt: nextRun,
      clearNextRunAt: nextRun == null,
      lastStatus: enabled ? JobStatus.pending : job.lastStatus,
      workId: workId,
      clearWorkId: workId == null,
    );
    await _repository.upsert(updated);
    await onScheduleChanged?.call(updated);
    return updated;
  }

  Future<void> delete(String id) => _repository.delete(id);

  /// Records a successful run and advances the schedule.
  Future<Job> recordSuccess(Job job, {required String output}) async {
    final now = _clock();
    final nextRun = job.schedule.nextRun(now);
    final runCount = job.runCount + 1;
    final updated = job.copyWith(
      runCount: runCount,
      lastRunAt: now,
      lastStatus: JobStatus.success,
      clearLastError: true,
      nextRunAt: nextRun,
      clearNextRunAt: nextRun == null,
    );
    await _repository.upsert(updated);
    await _repository.addRun(
      JobRun(
        id: newId(),
        jobId: job.id,
        startedAt: now,
        finishedAt: _clock(),
        status: JobStatus.success,
        output: output,
      ),
    );
    await _repository.purgeRunsBefore(now.subtract(const Duration(days: 30)));
    return updated;
  }

  /// Records a failed run. One-off jobs keep their time so the user can retry;
  /// recurring jobs move on to their next slot.
  Future<Job> recordFailure(Job job, {required String error}) async {
    final now = _clock();
    final nextRun = job.isRecurring ? job.schedule.nextRun(now) : job.nextRunAt;
    final updated = job.copyWith(
      runCount: job.runCount + 1,
      lastRunAt: now,
      lastStatus: JobStatus.failed,
      lastError: error,
      nextRunAt: nextRun,
      clearNextRunAt: nextRun == null,
    );
    await _repository.upsert(updated);
    await _repository.addRun(
      JobRun(
        id: newId(),
        jobId: job.id,
        startedAt: now,
        finishedAt: _clock(),
        status: JobStatus.failed,
        error: error,
      ),
    );
    return updated;
  }

  /// Marks a job as currently running (shown as a spinner in the UI).
  Future<Job> markRunning(Job job) async {
    final updated = job.copyWith(lastStatus: JobStatus.running);
    await _repository.upsert(updated);
    return updated;
  }

  /// Persists which WorkManager request currently owns the job.
  Future<Job> attachWork(Job job, int? workId) async {
    final updated = job.copyWith(workId: workId, clearWorkId: workId == null);
    await _repository.upsert(updated);
    return updated;
  }

  /// Jobs due at [now] – used by the in-app scheduler when the app is resumed.
  Future<List<Job>> dueJobs() => _repository.dueJobs(_clock());

  Future<Job?> nextScheduled() async {
    final jobs = await _repository.list();
    final active = jobs.where((job) => job.isActive && job.nextRunAt != null).toList()
      ..sort((a, b) => a.nextRunAt!.compareTo(b.nextRunAt!));
    return active.isEmpty ? null : active.first;
  }

  static void _validateSchedule(JobSchedule schedule) {
    if (!schedule.isValid) {
      throw JobValidationException('تعریف زمان‌بندی کامل نیست.');
    }
    if (schedule.kind == JobScheduleKind.interval &&
        (schedule.intervalMinutes ?? 0) < minimumIntervalMinutes) {
      throw JobValidationException(
        'اندروید اجرای دوره‌ای کمتر از پانزده دقیقه را اجازه نمی‌دهد.',
      );
    }
  }

  static String _titleFromPrompt(String prompt) {
    final firstLine = prompt.trim().split('\n').first.trim();
    if (firstLine.isEmpty) return 'وظیفهٔ بدون عنوان';
    if (firstLine.length <= 40) return firstLine;
    return '${firstLine.substring(0, 40).trimRight()}…';
  }
}
