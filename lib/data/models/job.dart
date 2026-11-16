/// A scheduled assistant job (one-off reminder or recurring routine).
class Job {
  const Job({
    required this.id,
    required this.title,
    required this.prompt,
    required this.kind,
    required this.schedule,
    required this.action,
    required this.nextRunAt,
    required this.createdAt,
    this.enabled = true,
    this.notify = true,
    this.runCount = 0,
    this.lastRunAt,
    this.lastStatus = JobStatus.pending,
    this.lastError,
    this.workId,
  });

  final String id;

  /// Short Persian label shown in lists, e.g. «خلاصهٔ اخبار».
  final String title;

  /// Instruction handed to the assistant when the job fires.
  final String prompt;

  final JobKind kind;
  final JobSchedule schedule;
  final JobAction action;

  /// When the job should next fire (local time); null for disabled/expired jobs.
  final DateTime? nextRunAt;

  final DateTime createdAt;
  final bool enabled;

  /// Whether a local notification should be posted when the job runs.
  final bool notify;

  final int runCount;
  final DateTime? lastRunAt;
  final JobStatus lastStatus;
  final String? lastError;

  /// WorkManager id of the enqueued unique work, if any.
  final int? workId;

  bool get isRecurring => schedule.kind != JobScheduleKind.once;

  /// True when a one-off job has already fired and cannot run again.
  bool get isExpired => !isRecurring && runCount > 0;

  /// Whether the job should currently be treated as "live".
  bool get isActive => enabled && !isExpired;

  /// Human readable schedule, e.g. «هر روز ساعت ۰۸:۰۰».
  String get scheduleLabel => schedule.label;

  Job copyWith({
    String? title,
    String? prompt,
    JobSchedule? schedule,
    JobAction? action,
    DateTime? nextRunAt,
    bool clearNextRunAt = false,
    bool? enabled,
    bool? notify,
    int? runCount,
    DateTime? lastRunAt,
    JobStatus? lastStatus,
    String? lastError,
    bool clearLastError = false,
    int? workId,
    bool clearWorkId = false,
  }) =>
      Job(
        id: id,
        title: title ?? this.title,
        prompt: prompt ?? this.prompt,
        kind: schedule?.kind ?? kind,
        schedule: schedule ?? this.schedule,
        action: action ?? this.action,
        nextRunAt: clearNextRunAt ? null : (nextRunAt ?? this.nextRunAt),
        createdAt: createdAt,
        enabled: enabled ?? this.enabled,
        notify: notify ?? this.notify,
        runCount: runCount ?? this.runCount,
        lastRunAt: lastRunAt ?? this.lastRunAt,
        lastStatus: lastStatus ?? this.lastStatus,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
        workId: clearWorkId ? null : (workId ?? this.workId),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'prompt': prompt,
        'kind': kind.name,
        'schedule': schedule.toJson(),
        'action': action.name,
        'next_run_at': nextRunAt?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'enabled': enabled ? 1 : 0,
        'notify': notify ? 1 : 0,
        'run_count': runCount,
        'last_run_at': lastRunAt?.millisecondsSinceEpoch,
        'last_status': lastStatus.name,
        'last_error': lastError,
        'work_id': workId,
      };

  static Job fromMap(Map<String, Object?> map) => Job(
        id: map['id']! as String,
        title: (map['title'] as String?) ?? '',
        prompt: (map['prompt'] as String?) ?? '',
        kind: JobKind.values.firstWhere(
          (kind) => kind.name == map['kind'],
          orElse: () => JobKind.custom,
        ),
        schedule: JobSchedule.fromJson((map['schedule'] as String?) ?? '{}'),
        action: JobAction.values.firstWhere(
          (action) => action.name == map['action'],
          orElse: () => JobAction.reminder,
        ),
        nextRunAt: map['next_run_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['next_run_at']! as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
        enabled: (map['enabled'] as int? ?? 1) == 1,
        notify: (map['notify'] as int? ?? 1) == 1,
        runCount: (map['run_count'] as int?) ?? 0,
        lastRunAt: map['last_run_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['last_run_at']! as int),
        lastStatus: JobStatus.values.firstWhere(
          (status) => status.name == map['last_status'],
          orElse: () => JobStatus.pending,
        ),
        lastError: map['last_error'] as String?,
        workId: map['work_id'] as int?,
      );
}

/// What kind of routine the job represents (drives the default action/prompt).
enum JobKind { reminder, briefing, summary, custom }

enum JobAction { reminder, dailyBriefing, messageSummary, assistantPrompt }

enum JobStatus { pending, running, success, failed }

enum JobScheduleKind { once, daily, weekly, interval }

/// Schedule definition. All times are local wall-clock times so that «هر روز
/// ساعت ۸» keeps meaning 08:00 after DST changes (Iran has none, but the app
/// must not assume that).
class JobSchedule {
  const JobSchedule({
    required this.kind,
    this.hour,
    this.minute,
    this.weekday,
    this.intervalMinutes,
    this.anchor,
  });

  const JobSchedule.once(DateTime at)
      : kind = JobScheduleKind.once,
        hour = null,
        minute = null,
        weekday = null,
        intervalMinutes = null,
        anchor = at;

  final JobScheduleKind kind;

  /// Hour/minute of daily and weekly schedules.
  final int? hour;
  final int? minute;

  /// 1 = Monday … 7 = Sunday (DateTime.weekday convention).
  final int? weekday;

  /// Fixed interval in minutes (must be >= 15, the WorkManager minimum).
  final int? intervalMinutes;

  /// For one-off jobs: the exact fire time. For intervals: the first fire time.
  final DateTime? anchor;

  bool get isValid {
    switch (kind) {
      case JobScheduleKind.once:
        return anchor != null;
      case JobScheduleKind.daily:
        return hour != null && minute != null;
      case JobScheduleKind.weekly:
        return hour != null && minute != null && weekday != null;
      case JobScheduleKind.interval:
        return intervalMinutes != null && intervalMinutes! >= 15;
    }
  }

  /// Computes the next fire time strictly after [from].
  DateTime? nextRun(DateTime from) {
    switch (kind) {
      case JobScheduleKind.once:
        final at = anchor;
        if (at == null) return null;
        return at.isAfter(from) ? at : null;
      case JobScheduleKind.daily:
        if (hour == null || minute == null) return null;
        var candidate = DateTime(from.year, from.month, from.day, hour!, minute!);
        if (!candidate.isAfter(from)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return candidate;
      case JobScheduleKind.weekly:
        if (hour == null || minute == null || weekday == null) return null;
        var candidate = DateTime(from.year, from.month, from.day, hour!, minute!);
        while (candidate.weekday != weekday || !candidate.isAfter(from)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return candidate;
      case JobScheduleKind.interval:
        final minutes = intervalMinutes;
        if (minutes == null) return null;
        final base = anchor ?? from;
        if (base.isAfter(from)) return base;
        final elapsedMinutes = from.difference(base).inMinutes;
        final periods = (elapsedMinutes ~/ minutes) + 1;
        return base.add(Duration(minutes: periods * minutes));
    }
  }

  String get label {
    final hh = (hour ?? 0).toString().padLeft(2, '0');
    final mm = (minute ?? 0).toString().padLeft(2, '0');
    switch (kind) {
      case JobScheduleKind.once:
        return 'یک‌بار';
      case JobScheduleKind.daily:
        return 'هر روز ساعت $hh:$mm';
      case JobScheduleKind.weekly:
        const weekdays = <int, String>{
          1: 'دوشنبه', 2: 'سه‌شنبه', 3: 'چهارشنبه', 4: 'پنجشنبه',
          5: 'جمعه', 6: 'شنبه', 7: 'یکشنبه',
        };
        return 'هر ${weekdays[weekday] ?? ''} ساعت $hh:$mm';
      case JobScheduleKind.interval:
        final minutes = intervalMinutes ?? 0;
        if (minutes % 60 == 0 && minutes >= 60) {
          return 'هر ${minutes ~/ 60} ساعت';
        }
        return 'هر $minutes دقیقه';
    }
  }

  String toJson() {
    final buffer = StringBuffer('{');
    buffer.write('"kind":"${kind.name}"');
    if (hour != null) buffer.write(',"hour":$hour');
    if (minute != null) buffer.write(',"minute":$minute');
    if (weekday != null) buffer.write(',"weekday":$weekday');
    if (intervalMinutes != null) buffer.write(',"interval_minutes":$intervalMinutes');
    if (anchor != null) {
      buffer.write(',"anchor":${anchor!.millisecondsSinceEpoch}');
    }
    buffer.write('}');
    return buffer.toString();
  }

  static JobSchedule fromJson(String raw) {
    final map = _MiniJson.decode(raw);
    final kind = JobScheduleKind.values.firstWhere(
      (kind) => kind.name == map['kind'],
      orElse: () => JobScheduleKind.once,
    );
    return JobSchedule(
      kind: kind,
      hour: map['hour'] as int?,
      minute: map['minute'] as int?,
      weekday: map['weekday'] as int?,
      intervalMinutes: map['interval_minutes'] as int?,
      anchor: map['anchor'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['anchor']! as int),
    );
  }
}

/// Tiny purpose-built decoder for the flat schedule JSON written by
/// [JobSchedule.toJson]. Keeps the model free of a codec dependency while
/// still being strict about malformed input.
abstract final class _MiniJson {
  static Map<String, Object?> decode(String raw) {
    final result = <String, Object?>{};
    final body = raw.trim().replaceAll(RegExp(r'^\{|\}$'), '');
    if (body.isEmpty) return result;
    for (final part in body.split(',')) {
      final separator = part.indexOf(':');
      if (separator <= 0) continue;
      final key = part.substring(0, separator).replaceAll('"', '').trim();
      var value = part.substring(separator + 1).trim();
      value = value.replaceAll('"', '');
      if (value.isEmpty) continue;
      result[key] = int.tryParse(value) ?? value;
    }
    return result;
  }
}
