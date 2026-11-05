/// Orchestrates a native export: pre-flight, progress, cancel, verify, publish.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_failure.dart';
import '../../core/models/project.dart';
import '../../core/utils/ratio_utils.dart';
import '../platform/native_video_bridge/video_bridge.dart';
import 'export_request_builder.dart';

class ExportJobState {
  const ExportJobState({
    this.sessionId,
    this.stage = ExportStage.preparing,
    this.progress = 0,
    this.framesDone = 0,
    this.framesTotal = 0,
    this.elapsed = Duration.zero,
    this.eta,
    this.result,
    this.failure,
    this.isRunning = false,
    this.cancelling = false,
  });

  final String? sessionId;
  final ExportStage stage;
  final double progress;
  final int framesDone;
  final int framesTotal;
  final Duration elapsed;
  final Duration? eta;
  final NativeExportResult? result;
  final AppFailure? failure;
  final bool isRunning;
  final bool cancelling;

  bool get isFinished => !isRunning && (result != null || failure != null);

  ExportJobState copyWith({
    String? sessionId,
    ExportStage? stage,
    double? progress,
    int? framesDone,
    int? framesTotal,
    Duration? elapsed,
    Duration? eta,
    NativeExportResult? result,
    AppFailure? failure,
    bool? isRunning,
    bool? cancelling,
  }) =>
      ExportJobState(
        sessionId: sessionId ?? this.sessionId,
        stage: stage ?? this.stage,
        progress: progress ?? this.progress,
        framesDone: framesDone ?? this.framesDone,
        framesTotal: framesTotal ?? this.framesTotal,
        elapsed: elapsed ?? this.elapsed,
        eta: eta ?? this.eta,
        result: result ?? this.result,
        failure: failure ?? this.failure,
        isRunning: isRunning ?? this.isRunning,
        cancelling: cancelling ?? this.cancelling,
      );
}

/// Raised instead of silently "succeeding" when the native renderer is absent.
class ExportBlocked implements Exception {
  const ExportBlocked(this.reason);
  final String reason;
  @override
  String toString() => 'ExportBlocked: $reason';
}

class ExportManager {
  ExportManager({required VideoBridge bridge}) : _bridge = bridge;

  final VideoBridge _bridge;
  final StreamController<ExportJobState> _states =
      StreamController<ExportJobState>.broadcast();

  ExportJobState _state = const ExportJobState();
  String? _sessionId;
  bool _cancelRequested = false;

  Stream<ExportJobState> get states => _states.stream;
  ExportJobState get state => _state;
  bool get isRunning => _state.isRunning;

  void _emit(ExportJobState s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  /// Runs the disk-space and capability pre-flight, then starts rendering.
  ///
  /// Throws [AppFailure] for pre-flight problems and [ExportBlocked] when the
  /// native renderer is missing.
  Future<NativeExportResult> start({
    required Project project,
    required int width,
    required int height,
    required int fps,
    required String codec,
    required int bitrate,
  }) async {
    if (_state.isRunning) {
      throw const AppFailure(FailureKind.internal,
          technicalDetail: 'an export is already running');
    }
    final problems = preflightProblems(project);
    if (problems.isNotEmpty) {
      throw AppFailure(FailureKind.photoMissing,
          technicalDetail: problems.join(','));
    }

    // 1. capability + storage pre-flight (never start a doomed export)
    DeviceCapabilities caps;
    try {
      caps = await _bridge.getCapabilities();
    } on BridgeUnavailable catch (e) {
      throw ExportBlocked(e.detail);
    }
    if (!caps.canEncode(width: width, height: height, fps: fps)) {
      throw AppFailure(
        FailureKind.resolutionUnsupported,
        technicalDetail: 'encoder limits: ${caps.maxWidth}x${caps.maxHeight}'
            '@${caps.maxFps}, requested ${width}x$height@$fps',
        recoverableWith: 'lower_resolution',
      );
    }
    if (codec == 'hevc' && !caps.supportsHevc) {
      throw const AppFailure(FailureKind.codecUnsupported,
          recoverableWith: 'use_h264');
    }

    final estimated = estimateOutputBytes(
      bitrate: bitrate,
      durationSeconds: project.totalDuration,
      hasAudio: project.audio?.hasAudio ?? false,
    );
    final tempDir = await getTemporaryDirectory();
    final available = await _availableBytes(tempDir);
    final needed = estimated + 120 * 1024 * 1024;
    if (available > 0 && available < needed) {
      throw AppFailure(
        FailureKind.outOfStorage,
        technicalDetail: 'need ${formatBytes(needed)}, '
            'have ${formatBytes(available)}',
        recoverableWith: 'free_space',
      );
    }

    // 2. build the request and start
    final outputPath = p.join(
      tempDir.path,
      'export_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    final request = buildExportRequest(
      project: project,
      outputPath: outputPath,
      width: width,
      height: height,
      fps: fps,
      codec: codec,
      bitrate: bitrate,
    );

    _cancelRequested = false;
    _emit(ExportJobState(
      stage: ExportStage.preparing,
      isRunning: true,
      framesTotal: request['frameCount'] as int,
    ));

    try {
      final sessionId = await _bridge.startExport(request);
      _sessionId = sessionId;
      final result = await _awaitCompletion(sessionId, request);
      // 3. verify the artifact by re-reading it with the platform probe
      final probe = await _verify(result);
      return probe;
    } on AppFailure catch (e) {
      _emit(_state.copyWith(
          isRunning: false, failure: e, cancelling: false));
      rethrow;
    } on BridgeUnavailable catch (e) {
      _emit(_state.copyWith(isRunning: false, cancelling: false));
      throw ExportBlocked(e.detail);
    } catch (e) {
      final failure = e is AppFailure
          ? e
          : AppFailure(FailureKind.unknown, technicalDetail: e.toString());
      _emit(_state.copyWith(
          isRunning: false, failure: failure, cancelling: false));
      throw failure;
    } finally {
      _sessionId = null;
    }
  }

  Future<NativeExportResult> _awaitCompletion(
      String sessionId, Map<String, dynamic> request) async {
    final framesTotal = request['frameCount'] as int;
    final started = DateTime.now();
    final completer = Completer<NativeExportResult>();
    final sub = _bridge.progressStream().listen((pp) {
      if (pp.sessionId != sessionId || completer.isCompleted) return;
      if (pp.stage == ExportStage.done) {
        if (pp.cancelled) {
          completer.completeError(const AppFailure(FailureKind.cancelled));
          return;
        }
        if (pp.errorCode != null) {
          completer.completeError(
              AppFailure.fromNative('${pp.errorCode}|${pp.errorMessage ?? ""}'));
          return;
        }
        final res = pp.result;
        if (res == null) {
          completer.completeError(const AppFailure(FailureKind.unknown,
              technicalDetail: 'done event without result'));
        } else {
          completer.complete(res);
        }
        return;
      }
      final elapsed = DateTime.now().difference(started);
      Duration? eta;
      if (pp.progress > 0.02) {
        final totalMs = elapsed.inMilliseconds / pp.progress;
        eta = Duration(milliseconds: (totalMs - elapsed.inMilliseconds).round());
      }
      _emit(_state.copyWith(
        sessionId: sessionId,
        // The native worker encodes while it renders, so its "rendering"
        // stage is already producing video frames: show it as encoding.
        stage: pp.stage == ExportStage.rendering ? ExportStage.encoding : pp.stage,
        progress: clamp01(pp.progress),
        framesDone: pp.framesDone == 0 && pp.framesTotal == 0
            ? _state.framesDone
            : pp.framesDone,
        framesTotal: pp.framesTotal == 0 ? framesTotal : pp.framesTotal,
        elapsed: elapsed,
        eta: eta,
        isRunning: true,
      ));
    }, onError: (Object e) {
      if (!completer.isCompleted) {
        completer.completeError(e is AppFailure
            ? e
            : AppFailure(FailureKind.unknown, technicalDetail: e.toString()));
      }
    });

    // poll the UI cancel flag at a human granularity
    final poll = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      if (_cancelRequested && !completer.isCompleted) {
        await _bridge.cancelExport(sessionId);
        if (!completer.isCompleted) {
          completer.completeError(const AppFailure(FailureKind.cancelled));
        }
      }
    });
    try {
      final result = await completer.future;
      _emit(_state.copyWith(
        stage: ExportStage.done,
        progress: 1.0,
        result: result,
        isRunning: false,
      ));
      return result;
    } finally {
      poll.cancel();
      await sub.cancel();
    }
  }

  /// Confirms the produced file is a real, playable video of the expected size,
  /// then moves it to the gallery. A truncated file never reaches the user.
  Future<NativeExportResult> _verify(NativeExportResult result) async {
    _emit(_state.copyWith(stage: ExportStage.verifying, progress: 0.985));
    final file = File(result.path);
    if (!file.existsSync() || file.lengthSync() < 4096) {
      throw const AppFailure(FailureKind.encoderFailed,
          technicalDetail: 'output file missing or too small');
    }
    NativeExportResult probed;
    try {
      probed = await _bridge.probeFile(result.path);
    } on BridgeUnavailable {
      // Without a probe we cannot claim success; surface it instead of hiding.
      throw const AppFailure(FailureKind.encoderFailed,
          technicalDetail: 'cannot verify output without the native probe');
    }
    if (probed.width != result.width ||
        probed.height != result.height ||
        probed.frameCount <= 0) {
      throw AppFailure(FailureKind.encoderFailed,
          technicalDetail: 'verification mismatch: '
              'expected ${result.width}x${result.height}, '
              'got ${probed.width}x${probed.height} '
              'frames=${probed.frameCount}');
    }
    final expectedMs = (result.durationMs * 0.98).round();
    if (probed.durationMs < expectedMs) {
      throw AppFailure(FailureKind.encoderFailed,
          technicalDetail: 'duration too short: '
              '${probed.durationMs}ms < ${expectedMs}ms');
    }
    _emit(_state.copyWith(stage: ExportStage.savingToGallery, progress: 0.995));
    try {
      final galleryUri = await _bridge.saveToGallery(result.path);
      return NativeExportResult(
        path: result.path,
        width: probed.width,
        height: probed.height,
        fps: probed.fps,
        durationMs: probed.durationMs,
        frameCount: probed.frameCount,
        bitrate: probed.bitrate,
        codec: probed.codec,
        sizeBytes: probed.sizeBytes,
        galleryUri: galleryUri,
        hasAudio: probed.hasAudio,
      );
    } on AppFailure catch (e) {
      // The video is valid; only publishing failed. Report it without
      // discarding the usable file.
      debugPrint('gallery save failed: ${e.kind.name}');
      return probed;
    }
  }

  Future<void> cancel() async {
    if (!_state.isRunning) return;
    _cancelRequested = true;
    _emit(_state.copyWith(cancelling: true));
    final id = _sessionId;
    if (id != null) {
      await _bridge.cancelExport(id);
    }
  }

  Future<int> _availableBytes(Directory dir) async {
    try {
      // Dart has no statvfs; ask the native side, which uses StatFs.
      final caps = await _bridge.getCapabilities(refresh: true);
      return caps.availableStorageMb * 1024 * 1024;
    } catch (_) {
      return 0; // unknown -> skip the check rather than block the user
    }
  }

  Future<void> share(NativeExportResult result) =>
      _bridge.shareFile(result.path);

  Future<void> dispose() async {
    if (_state.isRunning) {
      await cancel();
    }
    await _states.close();
  }
}
