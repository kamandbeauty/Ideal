import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/subtitle.dart';
import '../constants.dart';
import '../errors.dart';
import '../logger.dart';
import 'contracts.dart';

/// Typed wrapper over the single MethodChannel used by the app.
///
/// Pigeon was evaluated and rejected for Phase 1: it requires a code generation
/// step before the project even compiles, and the schema is small enough that a
/// hand-written, unit-testable codec is less risky. The contract lives in
/// `BridgeContract.kt` and `NativeMethods` and is checked by
/// `tools/check-dart.py`.
class NativeBridge {
  NativeBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(Channels.native);

  final MethodChannel _channel;
  static const SfLog _log = SfLog('bridge');

  Future<PickedVideoFile?> pickVideo() async {
    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMethod<Map<Object?, Object?>>(NativeMethods.pickVideo);
      if (result == null) return null;
      return PickedVideoFile.fromMap(result);
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') return null;
      throw AppFailure.fromPlatform(error);
    }
  }

  /// A JPEG frame for a video, or null when the platform declines. Callers must
  /// treat null as "show a placeholder", never as an error to surface.
  Future<String?> thumbnail({
    required String uri,
    required String key,
    int timeMs = 1000,
    int width = 480,
  }) async {
    try {
      return await _channel.invokeMethod<String>(NativeMethods.thumbnail, <String, Object?>{
        'uri': uri,
        'key': key,
        'timeMs': timeMs,
        'width': width,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Peak amplitudes (0..1000) for the timeline. An empty list means "no audio
  /// could be decoded", which the timeline renders as a flat strip.
  Future<List<int>> waveform({required String uri, int buckets = 72}) async {
    try {
      final List<Object?>? raw = await _channel.invokeListMethod<Object?>(
        NativeMethods.waveform,
        <String, Object?>{'uri': uri, 'buckets': buckets},
      );
      if (raw == null) return const <int>[];
      return raw.whereType<num>().map((num value) => value.toInt()).toList(growable: false);
    } on PlatformException {
      return const <int>[];
    } on MissingPluginException {
      return const <int>[];
    }
  }

  Future<VideoProbeResult> probeVideo(String uri) async {
    try {
      final Map<Object?, Object?>? result = await _channel
          .invokeMethod<Map<Object?, Object?>>(NativeMethods.probeVideo, <String, Object?>{
        'uri': uri,
      });
      if (result == null) {
        throw const AppFailure(AppErrorCode.nativeFailure, 'اطلاعات ویدئو دریافت نشد.');
      }
      final VideoProbeResult probe = VideoProbeResult.fromMap(result);
      if (!probe.isValid) {
        throw const AppFailure(
          AppErrorCode.unsupportedFormat,
          'این فایل ویدئوی معتبری نیست یا کدک آن پشتیبانی نمی‌شود.',
        );
      }
      return probe;
    } on PlatformException catch (error) {
      throw AppFailure.fromPlatform(error);
    }
  }

  Future<bool> fileExists(String uri) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        NativeMethods.fileExists,
        <String, Object?>{'uri': uri},
      );
      return result ?? false;
    } on PlatformException catch (error) {
      _log.e('fileExists failed', error);
      return false;
    }
  }

  Future<DeviceCapabilities> capabilities() async {
    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMethod<Map<Object?, Object?>>(NativeMethods.capabilities);
      return DeviceCapabilities.fromMap(result ?? const <Object?, Object?>{});
    } on PlatformException catch (error) {
      _log.e('capabilities failed', error);
      return DeviceCapabilities.fromMap(const <Object?, Object?>{});
    }
  }

  /// Renders SRT with the native codec, so the file exported here is byte-for-byte
  /// the same format the tests in `tools/native-core` verify.
  Future<String> writeSrt(List<SubtitleSegment> segments) async {
    final _SegmentColumns columns = _SegmentColumns.from(segments);
    try {
      final String? result = await _channel.invokeMethod<String>(
        NativeMethods.writeSrt,
        columns.toArguments(),
      );
      if (result == null) {
        throw const AppFailure(AppErrorCode.nativeFailure, 'خروجی SRT تولید نشد.');
      }
      return result;
    } on PlatformException catch (error) {
      throw AppFailure.fromPlatform(error);
    }
  }

  Future<String> writeAss({
    required List<SubtitleSegment> segments,
    required int videoWidth,
    required int videoHeight,
    String fontName = 'Vazirmatn',
    double fontSize = 64,
    int primaryColor = 0xFFFFFF,
    int outlineColor = 0x000000,
    bool bold = true,
    double outlineWidth = 4,
    double shadowDepth = 1.5,
    int alignment = 2,
  }) async {
    final _SegmentColumns columns = _SegmentColumns.from(segments);
    try {
      final String? result = await _channel.invokeMethod<String>(NativeMethods.writeAss, {
        ...columns.toArguments(),
        'fontName': fontName,
        'fontSize': fontSize,
        'primaryColor': primaryColor,
        'outlineColor': outlineColor,
        'bold': bold,
        'outlineWidth': outlineWidth,
        'shadowDepth': shadowDepth,
        'alignment': alignment,
        'playResX': videoWidth,
        'playResY': videoHeight,
      });
      if (result == null) {
        throw const AppFailure(AppErrorCode.nativeFailure, 'خروجی ASS تولید نشد.');
      }
      return result;
    } on PlatformException catch (error) {
      throw AppFailure.fromPlatform(error);
    }
  }

  Future<ExportPlanDto> planExport({
    required VideoProbeResult source,
    int presetHeight = 0,
    double customFps = 0,
    int customBitrate = 0,
    bool burnIn = true,
    bool allowUpscale = false,
    bool preferHevc = false,
    bool hevcSupported = false,
    bool hardware = true,
    bool keepSourceAudio = true,
    double quality = 0.75,
  }) async {
    try {
      final String? raw = await _channel.invokeMethod<String>(NativeMethods.planExport, {
        'srcWidth': source.width,
        'srcHeight': source.height,
        'srcFps': source.fpsMilli / 1000.0,
        'srcBitrate': source.bitrateBps,
        'hdr': source.hdr,
        'audioSampleRate': source.audioSampleRate,
        'audioChannels': source.audioChannels,
        'audioBitrate': source.audioBitrateBps,
        'durationUs': source.durationUs,
        'presetHeight': presetHeight,
        'customFps': customFps,
        'customBitrate': customBitrate,
        'burnIn': burnIn,
        'allowUpscale': allowUpscale,
        'preferHevc': preferHevc,
        'hevcSupported': hevcSupported,
        'hardware': hardware,
        'keepSourceAudio': keepSourceAudio,
        'quality': quality,
      });
      if (raw == null || raw.isEmpty) {
        throw const AppFailure(AppErrorCode.nativeFailure, 'برنامه‌ریزی خروجی انجام نشد.');
      }
      return ExportPlanDto.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on PlatformException catch (error) {
      throw AppFailure.fromPlatform(error);
    }
  }

  /// Bakes the captions into a new MP4 and returns once the file exists.
  ///
  /// Progress is *not* returned here: it arrives on [Channels.exportEvents],
  /// because a render can take minutes and the method reply must stay small.
  /// The raw map is returned so the renderer's own words (path, size, frame
  /// dimensions, error message) reach the UI unchanged.
  Future<Map<String, Object?>> renderVideo({
    required String uri,
    required String outputName,
    required int maxShortEdge,
    required Map<String, Object?> style,
    required List<Map<String, Object?>> cues,
    int? trimStartUs,
    int? trimEndUs,
  }) async {
    try {
      final Map<Object?, Object?>? map =
          await _channel.invokeMapMethod<Object?, Object?>(NativeMethods.exportVideo, <String, Object?>{
        'uri': uri,
        'outputName': outputName,
        'maxShortEdge': maxShortEdge,
        'style': style,
        'cues': cues,
        'trimStartUs': trimStartUs,
        'trimEndUs': trimEndUs,
      });
      if (map == null) return const <String, Object?>{};
      return map.map((Object? key, Object? value) => MapEntry<String, Object?>(key.toString(), value));
    } on PlatformException catch (error) {
      throw AppFailure.fromPlatform(error);
    }
  }

  /// Stops the running render. Safe to call when nothing is running.
  Future<void> cancelRender() async {
    try {
      await _channel.invokeMethod<bool>(NativeMethods.exportCancel);
    } on PlatformException {
      // Nothing to cancel is not an error the UI should ever show.
    } on MissingPluginException {
      // Same.
    }
  }

  /// Opens the system share sheet for a finished file. Returns false when the
  /// platform declined (no handler installed, file already deleted, ...).
  Future<bool> shareFile(String path) async {
    try {
      return await _channel.invokeMethod<bool>(NativeMethods.shareFile, <String, Object?>{
            'path': path,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Converts segment lists into the parallel arrays the JNI layer expects.
class _SegmentColumns {
  _SegmentColumns(this.starts, this.ends, this.texts, this.styles);

  final List<int> starts;
  final List<int> ends;
  final List<String> texts;
  final List<String> styles;

  factory _SegmentColumns.from(List<SubtitleSegment> segments) {
    final List<int> starts = <int>[];
    final List<int> ends = <int>[];
    final List<String> texts = <String>[];
    final List<String> styles = <String>[];
    for (final SubtitleSegment segment in segments) {
      if (segment.endUs <= segment.startUs || segment.text.isEmpty) continue;
      starts.add(segment.startUs);
      ends.add(segment.endUs);
      texts.add(segment.text);
      styles.add(segment.styleId ?? '');
    }
    return _SegmentColumns(starts, ends, texts, styles);
  }

  Map<String, Object?> toArguments() => <String, Object?>{
        'starts': starts,
        'ends': ends,
        'texts': texts,
        'styles': styles,
      };
}
