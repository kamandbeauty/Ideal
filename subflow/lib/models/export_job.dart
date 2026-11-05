import 'enums.dart';

/// A record of one export attempt. `planJson` keeps the exact numbers the
/// exporter used, so "why is my file smaller?" can always be answered.
class ExportJob {
  const ExportJob({
    required this.id,
    required this.projectId,
    required this.status,
    required this.mode,
    required this.createdAtMs,
    this.planJson,
    this.outputPath,
    this.subtitlePathsJson,
    this.errorCode,
    this.finishedAtMs,
  });

  final String id;
  final String projectId;
  final ExportStatus status;
  final ExportMode mode;
  final String? planJson;
  final String? outputPath;
  final String? subtitlePathsJson;
  final String? errorCode;
  final int createdAtMs;
  final int? finishedAtMs;

  factory ExportJob.fromMap(Map<String, Object?> map) => ExportJob(
        id: map['id']! as String,
        projectId: map['project_id']! as String,
        status: ExportStatus.fromDb(map['status'] as String?),
        mode: ExportMode.fromDb(map['mode'] as String?),
        planJson: map['plan_json'] as String?,
        outputPath: map['output_path'] as String?,
        subtitlePathsJson: map['subtitle_paths_json'] as String?,
        errorCode: map['error_code'] as String?,
        createdAtMs: map['created_at_ms']! as int,
        finishedAtMs: map['finished_at_ms'] as int?,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'project_id': projectId,
        'status': status.dbValue,
        'mode': mode.dbValue,
        'plan_json': planJson,
        'output_path': outputPath,
        'subtitle_paths_json': subtitlePathsJson,
        'error_code': errorCode,
        'created_at_ms': createdAtMs,
        'finished_at_ms': finishedAtMs,
      };
}
