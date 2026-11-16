import 'job.dart';

/// One execution record in a job's history.
class JobRun {
  const JobRun({
    required this.id,
    required this.jobId,
    required this.startedAt,
    required this.status,
    this.finishedAt,
    this.output,
    this.error,
    this.trigger = JobRunTrigger.scheduled,
  });

  final String id;
  final String jobId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final JobStatus status;
  final String? output;
  final String? error;
  final JobRunTrigger trigger;

  Duration? get duration =>
      finishedAt == null ? null : finishedAt!.difference(startedAt);

  Map<String, Object?> toMap() => {
        'id': id,
        'job_id': jobId,
        'started_at': startedAt.millisecondsSinceEpoch,
        'finished_at': finishedAt?.millisecondsSinceEpoch,
        'status': status.name,
        'output': output,
        'error': error,
        'trigger': trigger.name,
      };

  static JobRun fromMap(Map<String, Object?> map) => JobRun(
        id: map['id']! as String,
        jobId: map['job_id']! as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at']! as int),
        finishedAt: map['finished_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['finished_at']! as int),
        status: JobStatus.values.firstWhere(
          (status) => status.name == map['status'],
          orElse: () => JobStatus.pending,
        ),
        output: map['output'] as String?,
        error: map['error'] as String?,
        trigger: JobRunTrigger.values.firstWhere(
          (trigger) => trigger.name == map['trigger'],
          orElse: () => JobRunTrigger.scheduled,
        ),
      );
}

enum JobRunTrigger { scheduled, manual, retry }
