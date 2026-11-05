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
