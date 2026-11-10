/// Photo and audio import.
///
/// Uses the **Android Photo Picker** path (`image_picker` -> ACTION_PICK_IMAGES)
/// where available, which grants access only to the chosen items and needs no
/// storage permission at all (product brief §4). On older devices it falls back
/// to the system document picker. Images are copied into the app's private
/// project directory so a later gallery delete cannot break a saved project,
/// while the original file is left completely untouched.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../errors/app_failure.dart';
import '../utils/progress.dart';
import '../utils/thumbnail_service_ref.dart' show decodeImageSize;

/// A picked image ready to become a [PhotoItem].
@immutable
class PickedPhoto {
  const PickedPhoto({
    required this.id,
    required this.path,
    required this.width,
    required this.height,
    required this.originalName,
    required this.bytes,
  });

  final String id;

  /// Private copy inside the app sandbox (stable, always readable).
  final String path;
  final int width;
  final int height;
  final String originalName;

  /// Bytes of the *full* image, used for the first thumbnail generation only.
  final Uint8List bytes;
}

class MediaPickerService {
  MediaPickerService({required this.projectsDir, ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final Directory projectsDir;
  final ImagePicker _picker;

  /// Picks multiple images. Returns an empty list when the user cancels.
  ///
  /// [progress] (optional) is called with the import fraction 0..1 — the
  /// picker phase itself is not measurable and stays indeterminate.
  Future<List<PickedPhoto>> pickPhotos(
      {HeroReport? progress, HeroToken? token}) async {
    final List<XFile> files;
    try {
      files = await _picker.pickMultiImage(
        imageQuality: null, // never re-encode: we keep the original bits
        requestFullMetadata: true,
      );
    } on PlatformException catch (e) {
      throw AppFailure(
        FailureKind.permissionDenied,
        technicalDetail: '${e.code}: ${e.message}',
      );
    }
    return importPaths(files, progress: progress, token: token);
  }

  /// Adds images that were picked elsewhere (e.g. share intents or a restore).
  ///
  /// [progress] reports 0..1 as files are copied, with the current file name
  /// as detail; [token] allows cooperative cancellation between files.
  Future<List<PickedPhoto>> importPaths(
    List<XFile> files, {
    HeroReport? progress,
    HeroToken? token,
  }) async {
    final out = <PickedPhoto>[];
    final failures = <String>[];
    for (var i = 0; i < files.length; i++) {
      token?.check();
      final f = files[i];
      progress?.call(i / files.length, detail: f.name);
      try {
        final bytes = await f.readAsBytes();
        if (bytes.isEmpty) {
          failures.add('${f.name}: empty file');
          continue;
        }
        final size = await decodeImageSize(bytes);
        final id = _newId();
        final dir = Directory(p.join(projectsDir.path, 'media'));
        await dir.create(recursive: true);
        final target = File(p.join(dir.path, '$id${p.extension(f.name)}'));
        await target.writeAsBytes(bytes, flush: true);
        out.add(PickedPhoto(
          id: id,
          path: target.path,
          width: size.width,
          height: size.height,
          originalName: f.name,
          bytes: bytes,
        ));
      } on AppFailure catch (e) {
        failures.add('${f.name}: ${e.kind.name}');
      } catch (e) {
        failures.add('${f.name}: ${e.runtimeType}');
      }
    }
    progress?.call(1.0);
    if (out.isEmpty && failures.isNotEmpty) {
      throw AppFailure(
        FailureKind.photoUnreadable,
        technicalDetail: failures.join('; '),
        recoverableWith: 'pick_supported_formats',
      );
    }
    return out;
  }

  /// Picks a music file. `file_picker` style filtering by mime would need an
  /// extra dependency; the platform picker already restricts to audio.
  Future<File?> pickAudio() async {
    const channel = MethodChannel('motionshot/media');
    try {
      final path = await channel.invokeMethod<String>('pickAudio');
      if (path == null) return null;
      final f = File(path);
      if (!f.existsSync()) {
        throw const AppFailure(FailureKind.audioUnreadable,
            technicalDetail: 'picked audio file disappeared');
      }
      return f;
    } on MissingPluginException {
      throw const AppFailure(FailureKind.audioUnreadable,
          technicalDetail: 'audio picker channel missing');
    } on PlatformException catch (e) {
      throw AppFailure.fromNative('${e.code}|${e.message}');
    }
  }

  /// Midpoints (in seconds) of the quiet spans of an audio file, so the
  /// editor can align photo switches to silences. Decoded natively
  /// (MediaCodec); a few seconds for long tracks, runs off the main thread.
  Future<List<double>> analyzeSilences(String path) async {
    const channel = MethodChannel('motionshot/media');
    try {
      final list = await channel.invokeListMethod<double>(
          'analyzeSilences', <String, Object>{'path': path});
      return list ?? const <double>[];
    } on MissingPluginException {
      throw const AppFailure(FailureKind.audioUnreadable,
          technicalDetail: 'media channel missing');
    } on PlatformException catch (e) {
      throw AppFailure.fromNative('${e.code}|${e.message}');
    }
  }

  /// Amplitude envelope for the music timeline, decoded natively
  /// (`Waveform.kt`). Returns the source duration in seconds and ~[buckets]
  /// peak values in 0..1 (normalized by the global peak). Runs off the main
  /// thread; a few seconds for long tracks.
  Future<(double, List<double>)> waveform(
      String path, {int buckets = 600}) async {
    const channel = MethodChannel('motionshot/media');
    try {
      final result = await channel.invokeListMethod<Object?>(
          'getWaveform', <String, Object>{'path': path, 'buckets': buckets});
      if (result == null || result.length < 2) {
        return (0.0, const <double>[]);
      }
      final duration = (result[0] as num).toDouble();
      final peaks = (result[1] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      return (duration, peaks);
    } on MissingPluginException {
      throw const AppFailure(FailureKind.audioUnreadable,
          technicalDetail: 'media channel missing');
    } on PlatformException catch (e) {
      throw AppFailure.fromNative('${e.code}|${e.message}');
    }
  }

  static int _counter = 0;
  static String _newId() {
    _counter++;
    return 'p${DateTime.now().microsecondsSinceEpoch}_$_counter';
  }
}
