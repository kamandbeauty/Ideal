import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../../../core/errors.dart';
import '../../../shared/theme/app_colors.dart';

/// Immutable player state pushed from Kotlin (Media3 ExoPlayer).
@immutable
class SfPlayerState {
  const SfPlayerState({
    this.positionUs = 0,
    this.durationUs = 0,
    this.isPlaying = false,
    this.isReady = false,
    this.isBuffering = false,
    this.error,
  });

  final int positionUs;
  final int durationUs;
  final bool isPlaying;
  final bool isReady;
  final bool isBuffering;
  final String? error;

  SfPlayerState copyWith({
    int? positionUs,
    int? durationUs,
    bool? isPlaying,
    bool? isReady,
    bool? isBuffering,
    String? error,
  }) {
    return SfPlayerState(
      positionUs: positionUs ?? this.positionUs,
      durationUs: durationUs ?? this.durationUs,
      isPlaying: isPlaying ?? this.isPlaying,
      isReady: isReady ?? this.isReady,
      isBuffering: isBuffering ?? this.isBuffering,
      error: error ?? this.error,
    );
  }
}

/// Dart side of the Media3 player. Commands are fire-and-forget; state flows
/// back as `onPlayerEvent` calls from Kotlin, so the UI never polls.
class SfPlayerController {
  SfPlayerController._(this.viewId) {
    _channel.setMethodCallHandler(_handleCall);
  }

  factory SfPlayerController.create() => SfPlayerController._(_nextId++);

  static int _nextId = 1;

  final int viewId;
  late final MethodChannel _channel = MethodChannel(Channels.player(viewId));

  final ValueNotifier<SfPlayerState> state = ValueNotifier<SfPlayerState>(
    const SfPlayerState(),
  );

  bool _disposed = false;

  Future<void> play() => _invoke('play');
  Future<void> pause() => _invoke('pause');
  Future<void> seekTo(int positionUs) => _invoke('seek', <String, Object?>{'positionUs': positionUs});
  Future<void> setSpeed(double speed) => _invoke('setSpeed', <String, Object?>{'speed': speed});

  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (error) {
      throw AppFailure.fromPlatform(error);
    }
  }

  Future<void> _handleCall(MethodCall call) async {
    // A late event after dispose() must not touch a disposed ValueNotifier.
    if (_disposed || call.method != 'onPlayerEvent') return;
    final Map<Object?, Object?> args =
        (call.arguments as Map<Object?, Object?>?) ?? const <Object?, Object?>{};
    state.value = SfPlayerState(
      positionUs: (args['positionUs'] as num?)?.toInt() ?? state.value.positionUs,
      durationUs: (args['durationUs'] as num?)?.toInt() ?? state.value.durationUs,
      isPlaying: (args['isPlaying'] as bool?) ?? state.value.isPlaying,
      isReady: (args['isReady'] as bool?) ?? state.value.isReady,
      isBuffering: (args['isBuffering'] as bool?) ?? state.value.isBuffering,
      error: args['error'] as String?,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _channel.invokeMethod<void>('dispose').ignore();
    _channel.setMethodCallHandler(null);
    state.dispose();
  }
}

/// Platform view that hosts the native Media3 surface. Phase 1 plays the
/// original file untouched - the same player will later render the preview with
/// the shared caption overlay.
class NativeVideoPlayer extends StatelessWidget {
  const NativeVideoPlayer({required this.uri, required this.controller, super.key});

  final String uri;
  final SfPlayerController controller;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const _PlayerUnavailable(reason: 'پیش‌نمایش ویدئو فقط روی اندروید اجرا می‌شود.');
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: AndroidView(
          viewType: Channels.playerViewType,
          creationParams: <String, Object?>{'uri': uri, 'viewId': controller.viewId},
          creationParamsCodec: const StandardMessageCodec(),
        ),
      ),
    );
  }
}

class _PlayerUnavailable extends StatelessWidget {
  const _PlayerUnavailable({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outline),
        ),
        alignment: Alignment.center,
        child: Text(reason, style: const TextStyle(color: AppColors.textMuted)),
      ),
    );
  }
}
