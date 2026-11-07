/// Music playback for the live preview.
///
/// The preview is visual, but the user's music must be heard while editing
/// (InShot parity): the project's audio file plays in sync with the
/// playhead — it starts, pauses, seeks and stops with the video clock, and
/// follows volume/loop changes made in the audio sheet.
///
/// Fades are a render-time effect (applied by the exporter) and are not
/// emulated in the preview; volume and looping are.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/models/project.dart';
import '../project/project_editor_controller.dart';
import 'playback_controller.dart';

/// One process-wide audio player shared by every preview surface.
///
/// Commands are cheap and idempotent, and a generation token makes stale
/// async results (a load finishing after the track changed) harmless.
class PreviewAudioPlayer {
  PreviewAudioPlayer() {
    _player.playingStream.listen((p) => _isPlaying = p);
  }

  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  // Set synchronously when a source is loaded (processingStateStream events
  // arrive later, which would race a play() issued right after load()).
  bool _hasSource = false;
  int _generation = 0;

  /// How many preview surfaces are driving the player right now. When the
  /// last one goes away, playback must stop — but while the editor is still
  /// alive behind the full-screen preview, popping the preview must not.
  int activeSyncs = 0;

  bool get playing => _isPlaying;

  /// Loads [path] (replacing the current source) and prepares it at
  /// [seconds]. A missing/unreadable file leaves the player silent.
  Future<void> load({
    required String path,
    required double volume,
    required bool loop,
    required double seconds,
  }) async {
    final gen = ++_generation;
    try {
      await _player.stop();
      await _player.setFilePath(path);
      await _player.setVolume(volume.clamp(0.0, 1.0));
      await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      _hasSource = true;
      if (gen != _generation) return;
      await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
    } catch (e) {
      _hasSource = false;
      debugPrint('preview audio load failed: $e');
    }
  }

  /// Starts playback from [seconds] (seeking when the position is off).
  Future<void> playAt(double seconds) async {
    final gen = ++_generation;
    if (!_hasSource) return; // nothing loaded
    try {
      await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
      if (gen != _generation) return;
      await _player.play();
    } catch (e) {
      debugPrint('preview audio play failed: $e');
    }
  }

  /// Moves the playhead without changing the play/pause state (scrub).
  Future<void> seekTo(double seconds) async {
    final gen = ++_generation;
    if (!_hasSource) return;
    try {
      await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
      if (gen != _generation) return;
      if (_isPlaying) await _player.play();
    } catch (e) {
      debugPrint('preview audio seek failed: $e');
    }
  }

  Future<void> pause() async {
    _generation++;
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('preview audio pause failed: $e');
    }
  }

  /// Stops playback and forgets the source (music removed from the project).
  Future<void> stopAll() async {
    _generation++;
    _hasSource = false;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('preview audio stop failed: $e');
    }
  }

  Future<void> dispose() async {
    _generation++;
    _hasSource = false;
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('preview audio dispose failed: $e');
    }
  }
}

/// Shared player: one for the app, disposed with the container.
final previewAudioPlayerProvider = Provider<PreviewAudioPlayer>((ref) {
  final player = PreviewAudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

/// Syncs the shared player with the project audio and the playhead.
///
/// Wraps a preview widget (editor or full-screen preview); both may be live
/// at once — they drive the same player from the same state, so the commands
/// are idempotent.
class PreviewAudioSync extends ConsumerStatefulWidget {
  const PreviewAudioSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PreviewAudioSync> createState() => _PreviewAudioSyncState();
}

class _PreviewAudioSyncState extends ConsumerState<PreviewAudioSync> {
  /// Identifies the loaded track: file + volume + loop mode.
  String? _trackKey;

  /// Time at which the last play/seek command was issued; compares against
  /// the playhead to decide when a seek is actually needed.
  double _lastCommandTime = 0;

  /// Playhead as seen on the previous build (scrub detection).
  double? _lastSeenTime;

  bool _audioPlaying = false;

  @override
  void initState() {
    super.initState();
    ref.read(previewAudioPlayerProvider).activeSyncs++;
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(projectEditorProvider);
    final frame = ref.watch(playbackProvider);
    _decide(st?.project, frame);
    return widget.child;
  }

  void _decide(Project? project, FrameState frame) {
    final audio = project?.audio;
    final uri = (audio != null && audio.hasAudio) ? audio.uri : null;
    final trackKey = uri == null ? null : '$uri|${audio!.volume}|${audio!.loop}';
    final delta = _lastSeenTime == null ? 0.0 : (frame.time - _lastSeenTime!).abs();
    _lastSeenTime = frame.time;
    final scrubbed = delta > 0.5;

    if (trackKey == _trackKey &&
        frame.playing == _audioPlaying &&
        !scrubbed) {
      return;
    }

    final player = ref.read(previewAudioPlayerProvider);
    if (trackKey == null) {
      if (_trackKey != null) {
        // Music was removed from the project.
        _trackKey = null;
        _audioPlaying = false;
        player.stopAll();
      }
      return;
    }

    // Load (or reload when volume/loop changed), then play if the video is.
    if (trackKey != _trackKey) {
      _trackKey = trackKey;
      _lastCommandTime = frame.time;
      _audioPlaying = frame.playing;
      if (frame.playing) {
        Future.microtask(() =>
            player.load(
                    path: uri!,
                    volume: audio!.volume,
                    loop: audio!.loop,
                    seconds: frame.time,
                  ).then((_) => player.playAt(frame.time)));
      } else {
        Future.microtask(() =>
            player.load(
                path: uri!,
                volume: audio!.volume,
                loop: audio!.loop,
                seconds: frame.time));
      }
      return;
    }

    if (frame.playing != _audioPlaying) {
      _audioPlaying = frame.playing;
      _lastCommandTime = frame.time;
      if (frame.playing) {
        Future.microtask(() => player.playAt(frame.time));
      } else {
        Future.microtask(player.pause);
      }
      return;
    }

    if (scrubbed) {
      _lastCommandTime = frame.time;
      Future.microtask(() => player.seekTo(frame.time));
    }
  }

  @override
  void dispose() {
    // The player outlives this widget (it is app-wide). Only the last
    // surface leaving stops the sound — popping the full-screen preview
    // must not silence the editor that is still alive underneath.
    final player = ref.read(previewAudioPlayerProvider);
    player.activeSyncs--;
    if (player.activeSyncs <= 0) player.pause();
    super.dispose();
  }
}
