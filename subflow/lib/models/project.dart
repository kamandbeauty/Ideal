import 'enums.dart';

/// A SubFlow project. Immutable so Riverpod state updates are explicit.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.thumbnailPath,
    this.exportSettingsJson,
    this.lastEditLabel,
    this.lastOpenedAtMs,
    this.deletedAtMs,
  });

  final String id;
  final String name;
  final ProjectStatus status;
  final int createdAtMs;
  final int updatedAtMs;
  final String? thumbnailPath;
  final String? exportSettingsJson;
  final String? lastEditLabel;
  final int? lastOpenedAtMs;
  final int? deletedAtMs;

  bool get isDeleted => deletedAtMs != null;

  factory Project.fromMap(Map<String, Object?> map) => Project(
        id: map['id']! as String,
        name: map['name']! as String,
        status: ProjectStatus.fromDb(map['status'] as String?),
        createdAtMs: map['created_at_ms']! as int,
        updatedAtMs: map['updated_at_ms']! as int,
        thumbnailPath: map['thumbnail_path'] as String?,
        exportSettingsJson: map['export_settings_json'] as String?,
        lastEditLabel: map['last_edit_label'] as String?,
        lastOpenedAtMs: map['last_opened_at_ms'] as int?,
        deletedAtMs: map['deleted_at_ms'] as int?,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'status': status.dbValue,
        'thumbnail_path': thumbnailPath,
        'export_settings_json': exportSettingsJson,
        'last_edit_label': lastEditLabel,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'last_opened_at_ms': lastOpenedAtMs,
        'deleted_at_ms': deletedAtMs,
      };

  Project copyWith({
    String? name,
    ProjectStatus? status,
    String? thumbnailPath,
    String? exportSettingsJson,
    String? lastEditLabel,
    int? updatedAtMs,
    int? lastOpenedAtMs,
    int? deletedAtMs,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      exportSettingsJson: exportSettingsJson ?? this.exportSettingsJson,
      lastEditLabel: lastEditLabel ?? this.lastEditLabel,
      lastOpenedAtMs: lastOpenedAtMs ?? this.lastOpenedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
    );
  }
}
