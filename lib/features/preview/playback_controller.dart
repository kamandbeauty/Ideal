/// Preview playback clock.
///
/// The preview never fakes motion: it samples the *same* `sampleKeyframes` +
/// `clampCamera` pipeline that the request builder sends to Kotlin, using the
/// same timeline resolution. Only the rendered resolution differs (spec §8.3),
/// which is why a preview always matches the export.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/photo_item.dart';
import '../../core/models/transition.dart';
import '../../core/models/project.dart';
import '../motion/camera_math.dart';
import '../transitions/timeline_engine.dart';

@immutable
class FrameState {
  const FrameState({
    required this.time,
    required this.total,
    required this.layers,
    this.playing = false,
  });

  final double time;
  final double total;
  final List<TimelineLayer> layers;
  final bool playing;

  double get progress => total <= 0 ? 0 : (time / total).clamp(0.0, 1.0);
  int get currentPhotoIndex =>
      layers.isEmpty ? 0 : layers.last.photoIndex;
  bool get isTransition => layers.length > 1;
}

class PlaybackController extends StateNotifier<FrameState> {
  PlaybackController() : super(const FrameState(time: 0, total: 0, layers: []));

  Timer? _ticker;
  Project? _project;
  List<double> _durations = const <double>[];
  List<TransitionSpec> _transitions = const <TransitionSpec>[];
  DateTime? _lastTick;
  bool _scrubbing = false;

  /// Set while a motion-editor preview runs; the project clock pauses.
  bool get isPlaying => state.playing;

  void bind(Project project) {
    _project = project;
    _durations = project.photos.map((PhotoItem p) => p.duration).toList();
    _transitions =
        project.photos.map((PhotoItem p) => p.transition).toList();
    final total = totalDuration(_durations);
    final t = state.time.clamp(0.0, math.max(0.0, total));
    _emit(t, state.playing);
  }

  void _emit(double t, bool playing) {
    final total = totalDuration(_durations);
    final clamped = total <= 0 ? 0.0 : t.clamp(0.0, total);
    final layers = total <= 0
        ? const <TimelineLayer>[]
        : resolveLayers(clamped, _durations, _transitions);
    state = FrameState(
        time: clamped, total: total, layers: layers, playing: playing);
  }

  void play() {
    if (state.total <= 0) return;
    if (state.time >= state.total - 1e-6) {
      _emit(0, true);
    } else {
      _emit(state.time, true);
    }
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _lastTick = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_scrubbing || !state.playing) return;
      final now = DateTime.now();
      final dt = now.difference(_lastTick!).inMicroseconds / 1e6;
      _lastTick = now;
      final next = state.time + dt;
      if (next >= state.total) {
        pause();
        _emit(state.total, false);
      } else {
        _emit(next, true);
      }
    });
  }

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    if (state.playing) _emit(state.time, false);
  }

  void togglePlay() => state.playing ? pause() : play();

  /// Stop returns the playhead to the beginning, as the brief requires.
  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _emit(0, false);
  }

  void seek(double seconds) {
    _emit(seconds, state.playing);
    _lastTick = DateTime.now();
  }

  void seekFraction(double fraction) {
    if (state.total <= 0) return;
    seek(fraction.clamp(0.0, 1.0) * state.total);
  }

  void beginScrub() {
    _scrubbing = true;
  }

  void endScrub() {
    _scrubbing = false;
    _lastTick = DateTime.now();
  }

  /// Jump to the start of the next / previous photo (skipping the transition
  /// window so the user lands on a clean frame).
  void nextPhoto() {
    if (_durations.isEmpty) return;
    final idx = state.currentPhotoIndex;
    if (idx + 1 >= _durations.length) {
      seek(state.total);
      return;
    }
    final segs = buildSegments(
      _durations.asMap().entries.map((e) => e.key.toString()).toList(),
      _durations,
      _transitions,
    );
    seek(segs[idx + 1].start + 0.001);
  }

  void previousPhoto() {
    if (_durations.isEmpty) return;
    final idx = state.currentPhotoIndex;
    final segs = buildSegments(
      _durations.asMap().entries.map((e) => e.key.toString()).toList(),
      _durations,
      _transitions,
    );
    // Inside the first half of a photo, go back; otherwise restart this one.
    final seg = segs[idx];
    if (state.time - seg.start > 0.8 && idx > 0) {
      seek(seg.start + 0.001);
    } else if (idx == 0) {
      seek(0);
    } else {
      seek(segs[idx - 1].start + 0.001);
    }
  }

  CameraState? cameraFor(
    PhotoItem photo,
    TimelineLayer layer,
    Viewport vp,
  ) {
    final motion = photo.motion;
    if (motion == null) return null;
    final fit = ImageFit.make(photo.width, photo.height, vp);
    return motion.sample(layer.localTime, fit, vp);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final playbackProvider =
    StateNotifierProvider<PlaybackController, FrameState>(
  (ref) => PlaybackController(),
);
