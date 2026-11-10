import 'dart:async';

import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/platform/native_bridge.dart';
import '../features/effects/caption_preset.dart';
import '../features/subtitles/subtitle_document.dart';
import '../models/subtitle.dart';

/// Output quality of a rendered MP4, expressed as the short edge of the frame.
///
/// Short edge - not height - because the same choice has to make sense for a
/// portrait phone clip and a landscape one: 1080 means 1080x1920 for the first
/// and 1920x1080 for the second, never a stretched frame.
enum RenderQuality {
  p1080(1080, '۱۰۸۰p', 'بهترین کیفیت، فایل بزرگ‌تر'),
  p720(720, '۷۲۰p', 'تعادل حجم و کیفیت'),
  p480(480, '۴۸۰p', 'سبک، برای اشتراک‌گذاری سریع');

  const RenderQuality(this.shortEdge, this.label, this.hint);

  final int shortEdge;
  final String label;
  final String hint;
}

/// A finished render on disk.
class VideoRenderResult {
  const VideoRenderResult({
    required this.path,
    required this.bytes,
    required this.width,
    required this.height,
    required this.durationUs,
  });

  final String path;
  final int bytes;
  final int width;
  final int height;
  final int durationUs;

  String get fileName => path.split('/').last;

  String get resolution => '$width×$height';

  String get sizeLabel {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} مگابایت';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} کیلوبایت';
  }

  String get durationLabel {
    final int totalSeconds = (durationUs / 1000000).round();
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class VideoRenderException implements Exception {
  const VideoRenderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the user pressed cancel; the UI should stay quiet about it.
class VideoRenderCancelled implements Exception {
  const VideoRenderCancelled();
}

/// Burns the captions into a new MP4 through the native renderer.
///
/// The service owns the mapping between the app's own models
/// ([SubtitleDocument], [CaptionPreset]) and the renderer's request map, so the
/// Kotlin side never has to know what a "project" or a "segment" is - it only
/// paints cues. Style travels as `CaptionPreset.toMap()`, the very object the
/// Flutter preview renders, which is how the exported MP4 ends up matching the
/// editor instead of approximating it.
class VideoExportService {
  VideoExportService({
    required NativeBridge bridge,
    Stream<Object?>? events,
  })  : _bridge = bridge,
        _events = events ??
            const EventChannel(Channels.exportEvents).receiveBroadcastStream();

  final NativeBridge _bridge;
  final Stream<Object?> _events;

  Future<VideoRenderResult> render({
    required String uri,
    required SubtitleDocument document,
    required CaptionPreset preset,
    required RenderQuality quality,
    required String outputName,
    int? trimStartUs,
    int? trimEndUs,
    void Function(int percent)? onProgress,
  }) async {
    if (document.isEmpty) {
      throw const VideoRenderException('زیرنویسی برای سوختن روی ویدئو وجود ندارد.');
    }
    final StreamSubscription<Object?> subscription = _events.listen((Object? raw) {
      if (raw is! Map) return;
      if (raw['event'] != 'export') return;
      if (raw['state'] != 'progress') return;
      final Object? percent = raw['progress'];
      if (percent is num) {
        onProgress?.call(percent.toInt().clamp(0, 100).toInt());
      }
    });
    try {
      final Map<String, Object?> outcome = await _bridge.renderVideo(
        uri: uri,
        outputName: outputName,
        maxShortEdge: quality.shortEdge,
        style: preset.toMap(),
        cues: cuesOf(document),
        trimStartUs: trimStartUs,
        trimEndUs: trimEndUs,
      );
      if (outcome['ok'] == true) {
        onProgress?.call(100);
        return VideoRenderResult(
          path: outcome['path'] as String? ?? '',
          bytes: (outcome['bytes'] as num?)?.toInt() ?? 0,
          width: (outcome['width'] as num?)?.toInt() ?? 0,
          height: (outcome['height'] as num?)?.toInt() ?? 0,
          durationUs: (outcome['durationUs'] as num?)?.toInt() ?? 0,
        );
      }
      if (outcome['cancelled'] == true) {
        throw const VideoRenderCancelled();
      }
      throw VideoRenderException(
        outcome['message'] as String? ?? 'ساخت ویدئو ناموفق بود.',
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> cancel() => _bridge.cancelRender();

  /// The cue list the renderer expects: plain maps, word timings included so
  /// karaoke/active-word effects burn in with the real rhythm of the speech.
  static List<Map<String, Object?>> cuesOf(SubtitleDocument document) {
    return document.segments
        .map((SubtitleSegment segment) => <String, Object?>{
              'startUs': segment.startUs,
              'endUs': segment.endUs,
              'text': segment.text,
              'words': segment.words
                  .map((SubtitleWord word) => <String, Object?>{
                        'startUs': word.startUs,
                        'endUs': word.endUs,
                        'text': word.text,
                      })
                  .toList(growable: false),
            })
        .toList(growable: false);
  }
}
