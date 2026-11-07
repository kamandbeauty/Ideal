/// Dart side of the Flutter <-> Kotlin render contract.
///
/// Contract (kept in sync with `android/.../NativeBridge.kt`):
///
///  MethodChannel `motionshot/render`
///    * `getCapabilities()` -> DeviceCapabilities JSON
///    * `startExport(ExportRequest JSON)` -> String sessionId
///    * `cancelExport(String sessionId)` -> bool
///    * `isExportRunning(String sessionId)` -> bool
///    * `probeFile(String path)` -> MediaProbe JSON  (used to verify output)
///    * `saveToGallery(String path)` -> content:// uri
///    * `shareFile(String path)` -> void
///    * `copyUriToTemp(String uri)` -> String path (for audio/image probing)
///
///  EventChannel `motionshot/render/progress` streams maps of the shape
///    { sessionId, stage, progress (0..1), framesDone, framesTotal,
///      elapsedMs, etaMs, message }
///
/// Errors are thrown as `PlatformException` whose `code` is one of the
/// `FailureKind` codes and `message` is the human-readable detail. Any missing
/// implementation surfaces as [BridgeUnavailable], which the UI reports as
/// BLOCKED rather than pretending the export succeeded.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/errors/app_failure.dart';

/// Hardware capability report from the device.
@immutable
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.supportsHevc,
    required this.supportsH264,
    required this.maxWidth,
    required this.maxHeight,
    required this.maxFps,
    required this.maxBitrate,
    required this.hasGlEs3,
    required this.maxTextureSize,
    required this.totalRamMb,
    required this.isLowRamDevice,
    required this.availableStorageMb,
    required this.codecName,
    this.note,
  });

  final bool supportsHevc;
  final bool supportsH264;
  final int maxWidth;
  final int maxHeight;
  final int maxFps;
  final int maxBitrate;
  final bool hasGlEs3;
  final int maxTextureSize;
  final int totalRamMb;
  final bool isLowRamDevice;
  final int availableStorageMb;
  final String codecName;
  final String? note;

  /// Whether a given resolution/fps pair is actually encodable here.
  bool canEncode({required int width, required int height, required int fps}) {
    if (!supportsH264 && !supportsHevc) return false;
    final maxSide = maxWidth > maxHeight ? maxWidth : maxHeight;
    final minSide = maxWidth > maxHeight ? maxHeight : maxWidth;
    final targetMax = width > height ? width : height;
    final targetMin = width > height ? height : width;
    return targetMax <= maxSide &&
        targetMin <= minSide &&
        fps <= maxFps;
  }

  static const DeviceCapabilities unknown = DeviceCapabilities(
    supportsHevc: false,
    supportsH264: true,
    maxWidth: 1920,
    maxHeight: 1080,
    maxFps: 30,
    maxBitrate: 20000000,
    hasGlEs3: false,
    maxTextureSize: 4096,
    totalRamMb: 2048,
    isLowRamDevice: true,
    availableStorageMb: 0,
    codecName: 'unavailable',
  );

  factory DeviceCapabilities.fromJson(Map<String, dynamic> j) =>
      DeviceCapabilities(
        supportsHevc: j['supportsHevc'] as bool? ?? false,
        supportsH264: j['supportsH264'] as bool? ?? false,
        maxWidth: (j['maxWidth'] as num?)?.toInt() ?? 1920,
        maxHeight: (j['maxHeight'] as num?)?.toInt() ?? 1080,
        maxFps: (j['maxFps'] as num?)?.toInt() ?? 30,
        maxBitrate: (j['maxBitrate'] as num?)?.toInt() ?? 20000000,
        hasGlEs3: j['hasGlEs3'] as bool? ?? false,
        maxTextureSize: (j['maxTextureSize'] as num?)?.toInt() ?? 4096,
        totalRamMb: (j['totalRamMb'] as num?)?.toInt() ?? 2048,
        isLowRamDevice: j['isLowRamDevice'] as bool? ?? false,
        availableStorageMb: (j['availableStorageMb'] as num?)?.toInt() ?? 0,
        codecName: j['codecName'] as String? ?? 'unknown',
        note: j['note'] as String?,
      );
}

/// Stage ids are shared with the Kotlin worker (`ExportWorker.kt`) — the
/// strings are the wire format, so they must never be renamed.
enum ExportStage {
  preparing,
  decodingPhotos,
  rendering,
  encoding,
  muxingAudio,
  muxing,
  verifying,
  savingToGallery,
  done;

  static ExportStage parse(String? v) =>
      ExportStage.values.firstWhere((e) => e.name == v, orElse: () => ExportStage.rendering);

  String get messageKey => 'export_stage_$name';
}

@immutable
class ExportProgress {
  const ExportProgress({
    required this.sessionId,
    required this.stage,
    required this.progress,
    required this.framesDone,
    required this.framesTotal,
    required this.elapsedMs,
    this.etaMs,
    this.result,
    this.errorCode,
    this.errorMessage,
    this.cancelled = false,
  });

  final String sessionId;
  final ExportStage stage;
  final double progress;
  final int framesDone;
  final int framesTotal;
  final int elapsedMs;
  final int? etaMs;

  /// Present only on the terminal [ExportStage.done] event.
  final NativeExportResult? result;
  final String? errorCode;
  final String? errorMessage;
  final bool cancelled;

  factory ExportProgress.fromJson(Map<String, dynamic> j) => ExportProgress(
        sessionId: j['sessionId'] as String? ?? '',
        stage: ExportStage.parse(j['stage'] as String?),
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        framesDone: (j['framesDone'] as num?)?.toInt() ?? 0,
        framesTotal: (j['framesTotal'] as num?)?.toInt() ?? 0,
        elapsedMs: (j['elapsedMs'] as num?)?.toInt() ?? 0,
        etaMs: (j['etaMs'] as num?)?.toInt(),
        result: j['result'] == null
            ? null
            : NativeExportResult.fromJson(
                Map<String, dynamic>.from(j['result'] as Map)),
        errorCode: j['errorCode'] as String?,
        errorMessage: j['errorMessage'] as String?,
        cancelled: j['cancelled'] as bool? ?? false,
      );
}

/// A finished export as reported by the native layer.
@immutable
class NativeExportResult {
  const NativeExportResult({
    required this.path,
    required this.width,
    required this.height,
    required this.fps,
    required this.durationMs,
    required this.frameCount,
    required this.bitrate,
    required this.codec,
    required this.sizeBytes,
    this.galleryUri,
    this.hasAudio = false,
  });

  final String path;
  final int width;
  final int height;
  final int fps;
  final int durationMs;
  final int frameCount;
  final int bitrate;
  final String codec;
  final int sizeBytes;
  final String? galleryUri;
  final bool hasAudio;

  factory NativeExportResult.fromJson(Map<String, dynamic> j) =>
      NativeExportResult(
        path: j['path'] as String? ?? '',
        width: (j['width'] as num?)?.toInt() ?? 0,
        height: (j['height'] as num?)?.toInt() ?? 0,
        fps: (j['fps'] as num?)?.toInt() ?? 0,
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        frameCount: (j['frameCount'] as num?)?.toInt() ?? 0,
        bitrate: (j['bitrate'] as num?)?.toInt() ?? 0,
        codec: j['codec'] as String? ?? '',
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        galleryUri: j['galleryUri'] as String?,
        hasAudio: j['hasAudio'] as bool? ?? false,
      );
}

/// Thrown when the native renderer is not present (e.g. Flutter-only build).
class BridgeUnavailable implements Exception {
  const BridgeUnavailable([this.detail = 'native renderer not available']);
  final String detail;
  @override
  String toString() => 'BridgeUnavailable: $detail';
}

class VideoBridge {
  VideoBridge({
    MethodChannel? methodChannel,
    EventChannel? progressChannel,
  })  : _method = methodChannel ??
            const MethodChannel('motionshot/render'),
        _events = progressChannel ??
            const EventChannel('motionshot/render/progress');

  final MethodChannel _method;
  final EventChannel _events;

  DeviceCapabilities? _cachedCapabilities;

  /// Queries (and caches) the encoder/GL capabilities of this device.
  Future<DeviceCapabilities> getCapabilities({bool refresh = false}) async {
    if (_cachedCapabilities != null && !refresh) return _cachedCapabilities!;
    try {
      final raw = await _method.invokeMethod<String>('getCapabilities');
      if (raw == null) {
        throw const BridgeUnavailable('getCapabilities returned null');
      }
      final caps = DeviceCapabilities.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      _cachedCapabilities = caps;
      return caps;
    } on MissingPluginException catch (e) {
      throw BridgeUnavailable(e.message ?? 'channel missing');
    } on PlatformException catch (e) {
      throw AppFailure.fromNative('${e.code}|${e.message}');
    }
  }

  /// Starts an export. Returns the session id used for cancel/progress.
  Future<String> startExport(Map<String, dynamic> request) async {
    try {
      final id = await _method.invokeMethod<String>(
          'startExport', jsonEncode(request));
      if (id == null) {
        throw const BridgeUnavailable('startExport returned null');
      }
      return id;
    } on MissingPluginException catch (e) {
      throw BridgeUnavailable(e.message ?? 'channel missing');
    } on PlatformException catch (e) {
      throw AppFailure.fromNative('${e.code}|${e.message}');
    }
  }

  Future<bool> cancelExport(String sessionId) async {
    try {
      return await _method.invokeMethod<bool>(
              'cancelExport', <String, dynamic>{'sessionId': sessionId}) ??
          false;
    } on MissingPluginException catch (e) {
      throw BridgeUnavailable(e.message ?? 'channel missing');
    } on PlatformException catch (e) {
      throw AppFailure.fromNative('${e.code}|${e.message}');
    }
  }

  /// Lists the encoder/colour-space facts for an export request, letting the
  /// Export screen disable impossible combinations *before* the user starts.
  Future<Map<String, dynamic>> probeRequest(
      Map<String, dynamic> request) async {
    try {
      final raw = await _method.invokeMethod<String>(
          'probeRequest', jsonEncode(request));
      return raw == null
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
    } on MissingPluginException catch (e) {
      throw BridgeUnavailable(e.message ?? 'channel missing');
    } on PlatformException catch (e) {
      throw AppFailure.fromNative('${e.code}|${e.message}');
    }
  }

  Future<NativeExportResult> probeFile(String path) async {
    try {
      final raw = await _method
          .invokeMethod<String>('probeFile', <String, dynamic>{'path': path});
      if (raw == null) throw const BridgeUnavailable('probeFile returned null');
      return NativeExportResult.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } on MissingPluginException catch (e) {
      throw BridgeUnavailable(e.message ?? 'channel missing');
    } on PlatformException catch (e) {
      throw AppFailure.fromNative('${e.code}|${e.message}');
    }
  }

  Future<String?> saveToGallery(String path) async {
    try {
      return await _method.invokeMethod<String>(
          'saveToGallery', <String, dynamic>{'path': path});
    } on MissingPluginException {
      return null; // gallery insert is best effort
    } on PlatformException catch (e) {
      throw AppFailure.fromNative('${e.code}|${e.message}');
    }
  }

  Future<void> shareFile(String path) async {
    try {
      await _method.invokeMethod<void>('shareFile', <String, dynamic>{'path': path});
    } on MissingPluginException {
      throw const BridgeUnavailable('sharing needs the native layer');
    } on PlatformException catch (e) {
      throw AppFailure.fromNative('${e.code}|${e.message}');
    }
  }

  /// The most recent uncaught native crash, as captured locally, or null.
  /// Shown on the export screen so a crash from a previous run can be read
  /// (and forwarded) instead of the app dying silently.
  Future<String?> getCrashLog() async {
    try {
      return await _method.invokeMethod<String>('getCrashLog');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Progress events for every running session; filter by session id.
  Stream<ExportProgress> progressStream() {
    return _events.receiveBroadcastStream().map((event) {
      if (event is String) {
        return ExportProgress.fromJson(
            jsonDecode(event) as Map<String, dynamic>);
      }
      return ExportProgress.fromJson(
          Map<String, dynamic>.from(event as Map));
    });
  }

  /// Lightweight capability check for a *specific* planned export.
  Future<Map<String, dynamic>> makeRequest({
    required String outputPath,
    required int width,
    required int height,
    required int fps,
    required String codec,
    required int bitrate,
    required double durationSeconds,
  }) async {
    final probe = await probeRequest(<String, dynamic>{
      'width': width,
      'height': height,
      'fps': fps,
      'codec': codec,
      'bitrate': bitrate,
    });
    return <String, dynamic>{
      'outputPath': outputPath,
      'width': width,
      'height': height,
      'fps': fps,
      'codec': codec,
      'bitrate': bitrate,
      'durationSeconds': durationSeconds,
      'supported': probe['supported'] ?? false,
      'note': probe['note'],
    };
  }

  /// Runs an export to completion, translating progress and cancellation.
  ///
  /// The native side emits progress events and finishes with a single event
  /// whose `stage` is [ExportStage.done] and which carries a `result` object.
  /// That keeps result delivery and progress on one ordered channel, so a
  /// completion can never be observed before its last progress frame.
  Future<NativeExportResult> runExport({
    required Map<String, dynamic> request,
    void Function(ExportProgress)? onProgress,
    Future<bool> Function()? shouldCancel,
  }) async {
    final sessionId = await startExport(request);
    final completer = Completer<NativeExportResult>();
    final sub = progressStream().listen((p) {
      if (p.sessionId != sessionId || completer.isCompleted) return;
      onProgress?.call(p);
      if (p.stage == ExportStage.done) {
        if (p.cancelled) {
          completer.completeError(const AppFailure(FailureKind.cancelled));
          return;
        }
        if (p.errorCode != null) {
          completer.completeError(
              AppFailure.fromNative('${p.errorCode}|${p.errorMessage ?? ""}'));
          return;
        }
        final result = p.result;
        if (result == null) {
          completer.completeError(const AppFailure(FailureKind.unknown,
              technicalDetail: 'export finished without a result descriptor'));
        } else {
          completer.complete(result);
        }
      }
    }, onError: (Object e) {
      if (!completer.isCompleted) {
        completer.completeError(e is PlatformException
            ? AppFailure.fromNative('${e.code}|${e.message}')
            : e);
      }
    });

    Timer? cancelPoll;
    if (shouldCancel != null) {
      cancelPoll = Timer.periodic(const Duration(milliseconds: 400), (_) async {
        if (completer.isCompleted) return;
        if (await shouldCancel()) {
          await cancelExport(sessionId);
          if (!completer.isCompleted) {
            completer.completeError(const AppFailure(FailureKind.cancelled));
          }
        }
      });
    }

    try {
      return await completer.future;
    } finally {
      cancelPoll?.cancel();
      await sub.cancel();
    }
  }
}
