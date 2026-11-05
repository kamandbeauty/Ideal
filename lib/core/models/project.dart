import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'audio_settings.dart';
import 'export_settings.dart';
import 'photo_item.dart';

/// A saved MotionShot project (product brief §14, §15).
@immutable
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.photos,
    required this.createdAt,
    required this.updatedAt,
    this.audio,
    this.exportSettings = const ExportSettings(),
    this.seed = 1,
    this.schemaVersion = kProjectSchemaVersion,
    this.thumbnailPath,
  });

  final String id;
  final String name;

  /// Always in display order (order field kept in sync by the repository).
  final List<PhotoItem> photos;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AudioSettings? audio;
  final ExportSettings exportSettings;

  /// Project-wide random seed: makes Auto Motion reproducible (spec §10).
  final int seed;
  final int schemaVersion;
  final String? thumbnailPath;

  static const int kProjectSchemaVersion = 1;

  double get totalDuration =>
      photos.fold(0.0, (a, p) => a + p.duration);

  double get firstPhotoAspect =>
      photos.isEmpty ? 16 / 9 : photos.first.aspect;

  double get outputAspect => effectiveAspect(exportSettings.aspect, firstPhotoAspect);

  int get videoFrameCount =>
      (totalDuration * exportSettings.fps.value).round();

  bool get hasAllMotions =>
      photos.isNotEmpty && photos.every((p) => p.motion != null);

  List<PhotoItem> get missingPhotos =>
      photos.where((p) => p.missing).toList(growable: false);

  Project copyWith({
    String? name,
    List<PhotoItem>? photos,
    DateTime? updatedAt,
    AudioSettings? audio,
    ExportSettings? exportSettings,
    int? seed,
    String? thumbnailPath,
    bool clearAudio = false,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        photos: photos ?? this.photos,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
        audio: clearAudio ? null : (audio ?? this.audio),
        exportSettings: exportSettings ?? this.exportSettings,
        seed: seed ?? this.seed,
        schemaVersion: schemaVersion,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      );

  /// Re-assigns `order` to match list position. Call after any reorder.
  Project normalized() => copyWith(
        photos: List<PhotoItem>.unmodifiable(
          <PhotoItem>[
            for (var i = 0; i < photos.length; i++) photos[i].copyWith(order: i),
          ],
        ),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'photos': photos.map((p) => p.toJson()).toList(growable: false),
        'audio': audio?.toJson(),
        'exportSettings': exportSettings.toJson(),
        'seed': seed,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'thumbnailPath': thumbnailPath,
      };

  factory Project.fromJson(Map<String, dynamic> json) {
    final rawPhotos = (json['photos'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => PhotoItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    rawPhotos.sort((a, b) => a.order.compareTo(b.order));
    return Project(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      photos: List<PhotoItem>.unmodifiable(rawPhotos),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      audio: json['audio'] == null
          ? null
          : AudioSettings.fromJson(
              Map<String, dynamic>.from(json['audio'] as Map)),
      exportSettings: json['exportSettings'] == null
          ? const ExportSettings()
          : ExportSettings.fromJson(
              Map<String, dynamic>.from(json['exportSettings'] as Map)),
      seed: (json['seed'] as num?)?.toInt() ?? 1,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ??
          kProjectSchemaVersion,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }
}
