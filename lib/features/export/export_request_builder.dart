/// Serialises a project into the exact payload the Kotlin renderer consumes.
///
/// This is the *contract* between the two runtimes. It is mirrored by
/// `ExportRequest.fromJson` in android/.../ExportRequest.kt and by
/// `tools/validate/request.py`, which validates the same document.
library;

import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/models/photo_item.dart';
import '../../core/models/project.dart';
import '../motion/camera_math.dart';

class ExportRequestException implements Exception {
  const ExportRequestException(this.message);
  final String message;
  @override
  String toString() => 'ExportRequestException: $message';
}

/// Builds the render request.
///
/// [outputPath] must be inside the app cache dir; the native layer moves it to
/// the gallery on success so a partial file is never published.
Map<String, dynamic> buildExportRequest({
  required Project project,
  required String outputPath,
  required int width,
  required int height,
  required int fps,
  required String codec,
  required int bitrate,
  int audioBitrate = 192000,
}) {
  if (project.photos.isEmpty) {
    throw const ExportRequestException('project has no photos');
  }
  final aspect = project.outputAspect;
  final vp = Viewport(aspect);
  final audio = project.audio;

  final photos = <Map<String, dynamic>>[];
  for (var i = 0; i < project.photos.length; i++) {
    final photo = project.photos[i];
    final motion = photo.motion;
    if (motion == null) {
      throw ExportRequestException(
          'photo ${photo.id} has no motion profile; run Auto Motion first');
    }
    if (photo.missing) {
      throw ExportRequestException(
          'photo ${photo.id} is missing on disk; replace or remove it');
    }
    motion.validate();
    final fit = ImageFit.make(photo.width, photo.height, vp);
    photos.add(<String, dynamic>{
      'id': photo.id,
      'path': photo.sourceUri,
      'width': photo.width,
      'height': photo.height,
      'duration': photo.duration,
      'order': i,
      'rotationDegrees': photo.rotationDegrees,
      'motionType': motion.motionType.id,
      'intensity': motion.intensity,
      'isLocked': motion.isLocked,
      // The high-resolution camera path, when one is set. The native
      // renderer evaluates it directly (spec §12.6); the keyframes below
      // stay as a lossless fallback for old native builds.
      if (motion.path != null) 'motionPath': motion.path!.toJson(),
      'keyframes': <Map<String, dynamic>>[
        for (final k in motion.keyframes)
          <String, dynamic>{
            'time': k.time,
            'x': k.x,
            'y': k.y,
            'scale': k.scale,
            'rotation': k.rotation,
            'easing': k.easing.name,
            if (k.curve != null) 'curve': k.curve,
          },
      ],
      // Per-photo look (user zoom and opacity; 1.0/1.0 = unchanged).
      'zoomFactor': photo.zoomFactor,
      'opacity': photo.opacity,
      // Derived values are included so the native side can assert that both
      // runtimes computed the same fit (guards against model drift).
      'expectedFitIw': fit.iw,
      'expectedFitIh': fit.ih,
      'transition': i < project.photos.length - 1
          ? <String, dynamic>{
              'type': photo.transition.type.id,
              'duration': photo.transition.duration,
            }
          : null,
    });
  }

  return <String, dynamic>{
    'schema': 1,
    'projectId': project.id,
    'projectSeed': project.seed,
    'outputPath': outputPath,
    'width': width,
    'height': height,
    'fps': fps,
    'codec': codec,
    'bitrate': bitrate,
    'aspect': aspect,
    'totalDuration': project.totalDuration,
    'frameCount': (project.totalDuration * fps).round(),
    'photos': photos,
    'watermark': project.watermark?.toJson(),
    'audio': audio != null && audio.hasAudio
        ? <String, dynamic>{
            'path': audio.uri,
            'volume': audio.volume,
            'fadeIn': audio.fadeIn,
            'fadeOut': audio.fadeOut,
            'trimStart': audio.trimStart,
            'trimEnd': audio.trimEnd,
            'loop': audio.loop,
            'bitrate': audioBitrate,
          }
        : null,
    'debug': <String, dynamic>{
      'appVersion': const String.fromEnvironment('APP_VERSION',
          defaultValue: '1.0.0+1'),
    },
  };
}

/// Convenience wrapper that also returns the JSON string for the channel.
String encodeExportRequest(Map<String, dynamic> request) => jsonEncode(request);

/// Estimates the output file size in bytes, for the pre-export disk check.
int estimateOutputBytes({
  required int bitrate,
  required double durationSeconds,
  bool hasAudio = true,
  int audioBitrate = 192000,
}) =>
    ((bitrate + (hasAudio ? audioBitrate : 0)) * durationSeconds / 8).round();

/// Validates that a photo list can be exported at all, returning a list of
/// human-usable problems (empty means good to go).
List<String> preflightProblems(Project project) {
  final problems = <String>[];
  if (project.photos.isEmpty) {
    problems.add('no_photos');
    return problems;
  }
  final missing = project.missingPhotos;
  if (missing.isNotEmpty) {
    problems.add('missing_photos:${missing.length}');
  }
  final noMotion =
      project.photos.where((PhotoItem p) => p.motion == null).length;
  if (noMotion > 0) {
    problems.add('motion_missing:$noMotion');
  }
  return problems;
}
