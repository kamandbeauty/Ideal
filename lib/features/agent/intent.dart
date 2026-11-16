import '../../data/models/job.dart';

/// Everything the agent can do without a cloud model.
enum IntentType {
  createNote,
  listNotes,
  readLatestNote,
  deleteNote,
  createJob,
  listJobs,
  pauseJob,
  deleteJob,
  dailyBriefing,
  messageSummary,
  greeting,
  help,
  unknown,
}

/// Executable action produced by the parser.
class AgentIntent {
  const AgentIntent({
    required this.type,
    required this.rawText,
    this.slots = const {},
    this.confidence = 0,
  });

  final IntentType type;
  final String rawText;
  final Map<String, Object?> slots;

  /// 0..1 – the parser's own confidence, surfaced in debug logs only.
  final double confidence;

  T? slot<T>(String key) {
    final value = slots[key];
    return value is T ? value : null;
  }

  AgentIntent copyWith({Map<String, Object?>? slots, IntentType? type}) => AgentIntent(
        type: type ?? this.type,
        rawText: rawText,
        slots: slots ?? this.slots,
        confidence: confidence,
      );
}

/// A schedule request extracted from natural language before it becomes a Job.
class ScheduleRequest {
  const ScheduleRequest({
    required this.kind,
    this.hour,
    this.minute,
    this.weekday,
    this.intervalMinutes,
    this.onceAt,
  });

  final JobScheduleKind kind;
  final int? hour;
  final int? minute;
  final int? weekday;
  final int? intervalMinutes;
  final DateTime? onceAt;

  JobSchedule toSchedule() => kind == JobScheduleKind.once
      ? JobSchedule.once(onceAt!)
      : JobSchedule(
          kind: kind,
          hour: hour,
          minute: minute,
          weekday: weekday,
          intervalMinutes: intervalMinutes,
        );
}

/// Sensitivity of an operation, used to decide whether confirmation is needed.
enum ActionRisk {
  /// Reads local data only.
  readOnly,

  /// Writes/updates local data (notes, job definitions) and can be undone.
  localReversible,

  /// Deletes data or runs something that reaches outside the app.
  destructive,
}
