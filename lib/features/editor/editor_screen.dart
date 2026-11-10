/// The editor — InShot-style workspace:
/// big canvas, centered transport, an icon+label tool bar, and a thumbnail
/// timeline with a prominent "+" add button. Every tool opens a bottom
/// sheet (motion, transition, music, duration, canvas/aspect).
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide ValueSlider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/strings.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../../core/models/photo_item.dart';
import '../../core/models/project.dart';
import '../../core/models/transition.dart';
import '../../core/models/audio_settings.dart';
import '../../core/models/watermark.dart';
import '../../core/utils/ratio_utils.dart';
import '../transitions/timeline_engine.dart';
import '../audio/audio_sheet.dart';
import '../preview/motion_preview.dart';
import '../preview/playback_controller.dart';
import '../preview/preview_audio.dart';
import '../project/project_editor_controller.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _picking = false;

  /// Local (uncommitted) drag of the watermark lane: move the whole range
  /// or resize one edge. A single `setWatermark` commit happens on release
  /// so undo gets one entry per drag, not one per frame.
  _WmDrag? _wmDrag;

  /// Local (uncommitted) drag of the music lane's trim handles. A single
  /// `setAudio` commit happens on release.
  _MusicTrimDrag? _musicTrim;

  @override
  void initState() {
    super.initState();
    // Initial bind happens after the first frame: mutating a provider from
    // inside build() is not allowed (Riverpod throws "Tried to modify a
    // provider while the widget tree was building").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = ref.read(projectEditorProvider);
      if (st == null) return;
      ref.read(playbackProvider.notifier).bind(st.project);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final st = ref.watch(projectEditorProvider);
    final playback = ref.watch(playbackProvider);

    if (st == null || st.project.photos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('editor_title'))),
        body: EmptyState(
          icon: Icons.photo_library_outlined,
          title: l10n.t('gallery_empty'),
          hint: l10n.t('gallery_empty_hint'),
          action: FilledButton(
            onPressed: () => context.go(AppRoutes.gallery),
            child: Text(l10n.t('gallery_add')),
          ),
        ),
      );
    }

    final project = st.project;
    // Keep the playback clock bound to the current timeline. The listener
    // fires during build, so the bind is deferred until the frame is done
    // (mutating a provider mid-build is not allowed).
    ref.listen<ProjectEditorState?>(projectEditorProvider,
        (_, ProjectEditorState? next) {
      if (next == null) return;
      final changed = next.project;
      Future.microtask(
          () => ref.read(playbackProvider.notifier).bind(changed));
    });

    final missing = project.missingPhotos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _confirmLeave(context, st),
        ),
        title: Text(project.name, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          // InShot-style "SAVE": one tap to the export screen.
          TextButton(
            onPressed: () {
              if (missing) {
                context.snack(l10n.t('error_photoMissing'), isError: true);
                return;
              }
              context.push(AppRoutes.export);
            },
            child: Text(
              l10n.t('editor_export'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.s12, vertical: AppTheme.s4),
                  // Also plays the project's music in sync with the clock.
                  child: PreviewAudioSync(
                    child: MotionPreview(
                      project: st.project,
                      frame: playback,
                      showSafeFrame: false,
                    ),
                  ),
                ),
              ),
            ),
            _transport(context, l10n, st, playback),
            _toolBar(context, l10n, st),
            _timeline(context, l10n, st, playback),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- transport
  Widget _transport(
      BuildContext context, L10n l10n, ProjectEditorState st, FrameState playback) {
    final ctrl = ref.read(playbackProvider.notifier);
    final editor = ref.read(projectEditorProvider.notifier);
    final subtle = IconButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: context.theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: l10n.t('editor_undo'),
            onPressed: st.canUndo ? () => editor.undo() : null,
            style: subtle,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: l10n.t('editor_redo'),
            onPressed: st.canRedo ? () => editor.redo() : null,
            style: subtle,
            icon: const Icon(Icons.redo_rounded),
          ),
          const Spacer(),
          IconButton(
            tooltip: l10n.t('preview_previous'),
            onPressed: ctrl.previousPhoto,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: playback.playing
                ? l10n.t('preview_pause')
                : l10n.t('preview_play'),
            onPressed: ctrl.togglePlay,
            style: IconButton.styleFrom(
              minimumSize: const Size(52, 52),
              backgroundColor: playback.playing
                  ? const Color(0xFF2A2A38)
                  : Colors.white,
              foregroundColor: playback.playing
                  ? Colors.white
                  : const Color(0xFF14141F),
              shape: const CircleBorder(),
            ),
            icon: Icon(
              playback.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 32,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: l10n.t('preview_next'),
            onPressed: ctrl.nextPhoto,
            icon: const Icon(Icons.skip_next_rounded),
          ),
          IconButton(
            tooltip: l10n.t('preview_stop'),
            onPressed: ctrl.stop,
            icon: const Icon(Icons.stop_rounded),
          ),
          const Spacer(),
          IconButton(
            tooltip: l10n.t('preview_title'),
            onPressed: () => context.push(AppRoutes.preview),
            icon: const Icon(Icons.fullscreen_rounded),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- tool bar
  Widget _toolBar(BuildContext context, L10n l10n, ProjectEditorState st) {
    final label = context.theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      letterSpacing: 0.2,
      color: context.theme.colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: <Widget>[
          _toolItem(
            icon: Icons.crop_rounded,
            label: l10n.t('tool_canvas'),
            onTap: () => _openCanvasSheet(context, l10n, st),
          ),
          _toolItem(
            icon: Icons.auto_awesome_motion_rounded,
            label: l10n.t('tool_motion'),
            onTap: () => _openToolSheet(
              context,
              l10n.t('tool_motion_title'),
              _motionPanel(context, l10n, st),
            ),
          ),
          _toolItem(
            icon: Icons.compare_arrows_rounded,
            label: l10n.t('tool_transition'),
            onTap: () => _openToolSheet(
              context,
              l10n.t('tool_transition_title'),
              _transitionPanel(context, l10n, st),
            ),
          ),
          _toolItem(
            icon: Icons.center_focus_strong_rounded,
            label: l10n.t('tool_photo'),
            onTap: () => _openPhotoSheet(context, l10n, st),
          ),
          _toolItem(
            icon: Icons.title_rounded,
            label: l10n.t('tool_watermark'),
            onTap: () => _openWatermarkSheet(context, l10n),
          ),
          _toolItem(
            icon: Icons.music_note_rounded,
            label: l10n.t('tool_music'),
            onTap: () => showAudioSheet(context, ref),
          ),
          _toolItem(
            icon: Icons.timer_rounded,
            label: l10n.t('tool_duration'),
            onTap: () => _openDurationSheet(context, l10n, st),
          ),
        ],
      ),
    );
  }

  Widget _toolItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 66,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF22222E), width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 24, color: context.theme.colorScheme.onSurface),
              const SizedBox(height: 3),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.labelSmall
                      ?.copyWith(fontSize: 10, letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- timeline
  /// The bottom timeline: a time-proportional photo strip, an optional
  /// watermark lane and an optional music lane with a real waveform.
  Widget _timeline(
      BuildContext context, L10n l10n, ProjectEditorState st, FrameState playback) {
    final photos = st.project.photos;
    final currentIndex =
        playback.layers.isEmpty ? 0 : playback.layers.last.photoIndex;
    final watermark = st.project.watermark;
    final audio = st.project.audio;
    final clock = context.theme.textTheme.labelSmall?.copyWith(
      color: context.theme.colorScheme.onSurfaceVariant,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _addButton(context, l10n),
              const SizedBox(width: 10),
              Expanded(
                child: _photoTimeline(context, st, playback),
              ),
            ],
          ),
          // The add button (44) + gap (10) = 54px. Indent the lower tracks so
          // they line up under the photo strip for a true multi-track look.
          if (watermark != null) ...<Widget>[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 54),
              child: _watermarkLane(st, playback),
            ),
          ],
          // Always-present music track so the timeline shows both the image
          // track and the music track: the real waveform when a song is
          // chosen, a tappable "add music" placeholder otherwise.
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 54),
            child: audio?.hasAudio ?? false
                ? _musicLane(context, l10n, st, playback)
                : _emptyMusicLane(context, l10n, st, playback),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(formatClockPrecise(playback.time), style: clock),
              const Spacer(),
              Text('${currentIndex + 1}/${photos.length} · '
                  '${formatClock(playback.total)}',
                  style: clock),
            ],
          ),
        ],
      ),
    );
  }

  /// Photos on ONE timeline, each segment's width proportional to its
  /// duration (with a minimum tappable width). Time always flows
  /// left→right, so the content is pinned to LTR even in RTL locales.
  Widget _photoTimeline(
      BuildContext context, ProjectEditorState st, FrameState playback) {
    final segs = buildSegments(st.photoIds, st.durations, st.transitions);
    final total = st.project.totalDuration;
    if (segs.isEmpty || total <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext c, BoxConstraints constraints) {
        const minW = 44.0;
        final gap = 3.0;
        final available = (constraints.maxWidth - gap * (segs.length - 1))
            .clamp(40.0, 1e6)
            .toDouble();
        final baseUnit = available / total;
        final currentIdx =
            playback.layers.isEmpty ? -1 : playback.layers.last.photoIndex;
        var widths = <double>[
          for (final s in segs) math.max(s.duration * baseUnit, minW),
        ];
        var contentW =
            widths.reduce((a, b) => a + b) + gap * (segs.length - 1);
        if (contentW < available) {
          // Everything hit the minimum — scale up to fill the row.
          final k = available / contentW;
          widths = <double>[for (final w in widths) w * k];
          contentW = available;
        }
        final scrollable = contentW > constraints.maxWidth + 0.5;

        Widget content = Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: contentW,
            height: 54,
            child: Stack(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    for (var i = 0; i < segs.length; i++) ...<Widget>[
                      if (i > 0) SizedBox(width: gap),
                      SizedBox(
                        width: widths[i],
                        child: _segmentTile(
                          context,
                          photo: st.project.photos[segs[i].index],
                          start: segs[i].start,
                          selected:
                              st.project.photos[segs[i].index].id ==
                                  st.selectedPhotoId,
                          isCurrent: i == currentIdx,
                        ),
                      ),
                    ],
                  ],
                ),
                // Playhead, synced with the preview clock.
                Positioned(
                  left: (playback.time / total * contentW)
                      .clamp(0.0, contentW)
                      .toDouble(),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: const Color(0xFFFF3B5C),
                  ),
                ),
              ],
            ),
          ),
        );
        return scrollable
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: content,
              )
            : content;
      },
    );
  }

  /// One proportional segment: thumbnail, selection ring, duration and lock.
  Widget _segmentTile(
    BuildContext context, {
    required PhotoItem photo,
    required double start,
    required bool selected,
    required bool isCurrent,
  }) {
    final path = photo.thumbnailPath;
    final exists = path != null && File(path).existsSync();
    final ring = selected
        ? const Color(0xFFFF3B5C)
        : isCurrent
            ? const Color(0xFFFFC24B)
            : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(projectEditorProvider.notifier).selectPhoto(photo.id);
        ref.read(playbackProvider.notifier).seek(start + 0.001);
      },
      onLongPress: () =>
          context.push('${AppRoutes.motionEditor}?photo=${photo.id}'),
      child: LayoutBuilder(
        builder: (BuildContext c, BoxConstraints box) {
          final wide = box.maxWidth >= 56;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ring,
                width: selected || isCurrent ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (exists)
                  Image.file(File(path), fit: BoxFit.cover)
                else
                  Container(
                    color: const Color(0xFF22222E),
                    alignment: Alignment.center,
                    child: Icon(
                      photo.missing
                          ? Icons.broken_image_rounded
                          : Icons.image_outlined,
                      size: 18,
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (photo.isLocked)
                  const Positioned(
                    top: 2,
                    left: 2,
                    child: Icon(Icons.lock_rounded,
                        size: 12, color: Colors.white),
                  ),
                // Duration label when there is room.
                if (wide)
                  Positioned(
                    right: 4,
                    bottom: 3,
                    child: Text(
                      '${photo.duration.toStringAsFixed(1)}s',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: <Shadow>[
                          Shadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------- watermark
  /// The watermark's range on the global timeline: drag the body to move it,
  /// drag either edge to resize it. One undo entry per finished drag.
  Widget _watermarkLane(ProjectEditorState st, FrameState playback) {
    final wm = st.project.watermark!;
    final total = st.project.totalDuration;
    if (total <= 0) return const SizedBox.shrink();
    const minLen = 0.3;
    final start = _wmDrag?.start ?? wm.start;
    final end = _wmDrag?.end ?? wm.end;

    void commit() {
      if (_wmDrag == null) return;
      final s = _wmDrag!.start;
      final e = _wmDrag!.end;
      setState(() => _wmDrag = null);
      if ((s - wm.start).abs() > 0.001 || (e - wm.end).abs() > 0.001) {
        ref.read(projectEditorProvider.notifier).setWatermark(
            wm.copyWith(start: s, end: e));
      }
    }

    return LayoutBuilder(
      builder: (BuildContext c, BoxConstraints box) {
        final W = box.maxWidth;
        if (W <= 0) return const SizedBox.shrink();
        double px(double t) => t / total * W;

        return SizedBox(
          height: 34,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              // The range bar (drag to move).
              Positioned(
                left: px(start),
                width: (px(end) - px(start)).clamp(28.0, W).toDouble(),
                top: 5,
                bottom: 5,
                child: GestureDetector(
                  onHorizontalDragStart: (d) => setState(() => _wmDrag =
                      _WmDrag(wm.start, wm.end, wm.start, wm.end)),
                  onHorizontalDragUpdate: (d) {
                    final dSec = d.delta.dx / W * total;
                    final cur = _wmDrag!;
                    final len = cur.baseEnd - cur.baseStart;
                    var s = cur.baseStart + dSec;
                    s = s.clamp(0.0, total - len).toDouble();
                    cur.start = s;
                    cur.end = s + len;
                    setState(() {});
                  },
                  onHorizontalDragEnd: (_) => commit(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF46E0C0).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF46E0C0)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      wm.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9FF3E2),
                      ),
                    ),
                  ),
                ),
              ),
              // Edge handles (wider hit zones on top of the bar).
              Positioned(
                left: (px(start) - 11).clamp(0.0, W).toDouble(),
                width: 22,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: (d) => setState(() => _wmDrag =
                      _WmDrag(wm.start, wm.end, wm.start, wm.end)),
                  onHorizontalDragUpdate: (d) {
                    final dSec = d.delta.dx / W * total;
                    final cur = _wmDrag!;
                    final s =
                        (cur.baseStart + dSec).clamp(0.0, cur.baseEnd - minLen).toDouble();
                    cur.start = s;
                    setState(() {});
                  },
                  onHorizontalDragEnd: (_) => commit(),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 4,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF46E0C0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (px(end) - 11).clamp(0.0, W).toDouble(),
                width: 22,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: (d) => setState(() => _wmDrag =
                      _WmDrag(wm.start, wm.end, wm.start, wm.end)),
                  onHorizontalDragUpdate: (d) {
                    final dSec = d.delta.dx / W * total;
                    final cur = _wmDrag!;
                    final e = (cur.baseEnd + dSec)
                        .clamp(cur.baseStart + minLen, total)
                        .toDouble();
                    cur.end = e;
                    setState(() {});
                  },
                  onHorizontalDragEnd: (_) => commit(),
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 4,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF46E0C0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              // Playhead, aligned with the photo strip above.
              Positioned(
                left: (playback.time / total * W).clamp(0.0, W).toDouble(),
                top: 0,
                bottom: 0,
                width: 2,
                child: Container(color: const Color(0xFFFF3B5C)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- music
  /// The music lane: the track's REAL decoded waveform laid out across the
  /// lane (source time 0→duration) with draggable trim handles, so the user
  /// picks exactly which part of the song plays (the renderer loops/trims it
  /// to the video length). The red marker shows where in the song the
  /// timeline currently is.
  Widget _musicLane(
      BuildContext context, L10n l10n, ProjectEditorState st, FrameState playback) {
    final audio = st.project.audio!;
    final wf = ref.watch(audioWaveformProvider);
    final uri = audio.uri!;
    // Kick off the (cached, native) decode for the current track.
    Future.microtask(
        () => ref.read(audioWaveformProvider.notifier).load(uri));
    final value = wf.valueOrNull;
    final peaks = value?.$2 ?? const <double>[];
    final srcDur = value?.$1 ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.music_note_rounded,
                size: 13, color: context.theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                audio.displayName.isNotEmpty ? audio.displayName : l10n.t('tool_music'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (wf.isLoading)
              const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5))
            else if (peaks.isEmpty)
              Text(l10n.t('waveform_unavailable'),
                  style: context.theme.textTheme.labelSmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant)),
            if (peaks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  l10n.t('music_drag_trim'),
                  style: context.theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: context.theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (peaks.isEmpty || srcDur <= 0)
          const SizedBox(height: 30)
        else
          _musicTrimStrip(audio, peaks, srcDur, playback),
      ],
    );
  }

  /// The draggable source-waveform strip: the full track across the lane
  /// width, the selected [trimStart, trimEnd] span highlighted, with a handle
  /// on each edge to trim it. One `setAudio` commit per finished drag.
  Widget _musicTrimStrip(
    AudioSettings audio,
    List<double> peaks,
    double srcDur,
    FrameState playback,
  ) {
    const minTrim = 0.2;
    final committedEnd = audio.trimEnd ?? srcDur;
    final tStart = _musicTrim?.start ?? audio.trimStart;
    final tEnd = _musicTrim?.end ?? committedEnd;

    void commit() {
      final drag = _musicTrim;
      if (drag == null) return;
      setState(() => _musicTrim = null);
      if ((drag.start - audio.trimStart).abs() > 0.001 ||
          (drag.end - committedEnd).abs() > 0.001) {
        ref
            .read(projectEditorProvider.notifier)
            .setAudio(audio.copyWith(trimStart: drag.start, trimEnd: drag.end));
      }
    }

    return LayoutBuilder(
      builder: (BuildContext c, BoxConstraints box) {
        final W = box.maxWidth;
        if (W <= 0) return const SizedBox.shrink();
        double px(double srcT) => (srcT / srcDur * W).clamp(0.0, W).toDouble();

        return SizedBox(
          height: 38,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: _MusicTrimPainter(
                      peaks: peaks,
                      sourceDuration: srcDur,
                      trimStart: tStart,
                      trimEnd: tEnd,
                      loop: audio.loop,
                      playhead: playback.time,
                    ),
                  ),
                ),
              ),
              // Left handle → trimStart.
              Positioned(
                left: (px(tStart) - 11).clamp(0.0, W).toDouble(),
                width: 22,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: (d) => setState(() => _musicTrim =
                      _MusicTrimDrag(audio.trimStart, committedEnd,
                          audio.trimStart, committedEnd)),
                  onHorizontalDragUpdate: (d) {
                    final cur = _musicTrim!;
                    cur.start += d.delta.dx / W * srcDur;
                    cur.start =
                        cur.start.clamp(0.0, cur.end - minTrim).toDouble();
                    setState(() {});
                  },
                  onHorizontalDragEnd: (_) => commit(),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 4,
                      margin: const EdgeInsets.only(left: 9),
                      decoration: const BoxDecoration(
                        color: Color(0xFF46E0C0),
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ),
              // Right handle → trimEnd.
              Positioned(
                left: (px(tEnd) - 11).clamp(0.0, W).toDouble(),
                width: 22,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: (d) => setState(() => _musicTrim =
                      _MusicTrimDrag(audio.trimStart, committedEnd,
                          audio.trimStart, committedEnd)),
                  onHorizontalDragUpdate: (d) {
                    final cur = _musicTrim!;
                    cur.end += d.delta.dx / W * srcDur;
                    cur.end = cur.end.clamp(cur.start + minTrim, srcDur).toDouble();
                    setState(() {});
                  },
                  onHorizontalDragEnd: (_) => commit(),
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 4,
                      margin: const EdgeInsets.only(right: 9),
                      decoration: const BoxDecoration(
                        color: Color(0xFF46E0C0),
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The music track before any song is chosen: a tappable placeholder so the
  /// timeline always shows a music track alongside the image track. It carries
  /// the same playhead as the photo strip, so both tracks read as one
  /// time-aligned timeline. Tapping it opens the same sheet as the Music tool.
  Widget _emptyMusicLane(
      BuildContext context, L10n l10n, ProjectEditorState st, FrameState playback) {
    final total = st.project.totalDuration;
    return LayoutBuilder(
      builder: (BuildContext c, BoxConstraints box) {
        final w = box.maxWidth;
        final px = (total > 0 ? playback.time / total : 0.0) * w;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => showAudioSheet(context, ref),
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  Positioned(
                    left: px.clamp(0.0, w).toDouble(),
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: const Color(0xFFFF3B5C)),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.music_note_rounded,
                            size: 15,
                            color: context.theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          l10n.t('music_add'),
                          style: context.theme.textTheme.bodySmall?.copyWith(
                              color:
                                  context.theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// InShot-style red gradient "+" button: adds photos to this project.
  Widget _addButton(BuildContext context, L10n l10n) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _picking ? null : () => _addPhotos(),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFFF5A6E), Color(0xFFC8145A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFC8145A).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: _picking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_rounded,
                    size: 26, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Future<void> _addPhotos() async {
    final l10n = context.l10n;
    final bootstrap = ref.read(bootstrapProvider);
    final settings = ref.read(settingsProvider);
    setState(() => _picking = true);
    try {
      final picked = await bootstrap.mediaPicker.pickPhotos();
      if (picked.isEmpty) return;
      final photos = <PhotoItem>[];
      for (final p in picked) {
        String? thumb;
        // Thumbnails are best-effort, same as the gallery flow.
        try {
          thumb = (await bootstrap.thumbs.generate(p.id, p.bytes)).path;
        } catch (_) {
          thumb = null;
        }
        photos.add(PhotoItem(
          id: p.id,
          sourceUri: p.path,
          width: p.width,
          height: p.height,
          duration: settings.defaultPhotoDuration,
          order: photos.length,
          displayName: p.originalName,
          thumbnailPath: thumb,
        ));
      }
      final ctrl = ref.read(projectEditorProvider.notifier);
      ctrl.addPhotos(photos);
      // Motion for the newcomers only; existing shots keep theirs.
      ctrl.autoMotion(intensity: settings.defaultIntensity);
      if (mounted) {
        context.snack(l10n.plural('editor_photos_added', photos.length));
      }
    } on AppFailure catch (e) {
      if (mounted) context.snack(context.l10n.t(e.messageKey), isError: true);
    } catch (e) {
      debugPrint('add photos failed: $e');
      if (mounted) {
        context.snack(context.l10n.t('error_unknown'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // ---------------------------------------------------------------- sheets
  Future<void> _openToolSheet(
      BuildContext context, String title, Widget content) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) {
        final h = MediaQuery.of(ctx).size.height;
        return SizedBox(
          height: (h * 0.62).clamp(340.0, 560.0).toDouble(),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              ctx.theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  /// Canvas / aspect + project facts (rename, totals, resolution).
  Future<void> _openCanvasSheet(
      BuildContext context, L10n l10n, ProjectEditorState st) {
    final project = st.project;
    final notifier = ref.read(projectEditorProvider.notifier);
    return _openToolSheet(
      context,
      l10n.t('tool_canvas_title'),
      ListView(
        padding: const EdgeInsets.all(AppTheme.s16),
        children: <Widget>[
          Text(l10n.t('export_aspect'),
              style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final a in AspectPreset.values)
                ChoiceChip(
                  label: Text(a == AspectPreset.original
                      ? l10n.t('export_aspect_original')
                      : a.id),
                  selected: project.exportSettings.aspect == a,
                  onSelected: (_) => notifier.setExportSettings(
                      project.exportSettings.copyWith(aspect: a)),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.s16),
          _kv(context, l10n.t('editor_total'),
              formatClock(project.totalDuration)),
          _kv(context, l10n.t('editor_photo'),
              '${project.photos.length}'),
          _kv(context, l10n.t('export_resolution'),
              '${project.exportSettings.dimensions(project.firstPhotoAspect).width}'
              '×${project.exportSettings.dimensions(project.firstPhotoAspect).height}'),
          const SizedBox(height: AppTheme.s12),
          TextField(
            decoration: InputDecoration(
              labelText: l10n.t('editor_project'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            controller: TextEditingController(text: project.name),
            onSubmitted: notifier.rename,
          ),
        ],
      ),
    );
  }

  /// Per-shot duration (1–60 s) + "apply to all".
  Future<void> _openDurationSheet(
      BuildContext context, L10n l10n, ProjectEditorState st) {
    final selected = st.selectedPhotoId ?? st.project.photos.first.id;
    final photo = st.photoById(selected) ?? st.project.photos.first;
    final notifier = ref.read(projectEditorProvider.notifier);
    return _openToolSheet(
      context,
      l10n.t('tool_duration_title'),
      ListView(
        padding: const EdgeInsets.all(AppTheme.s16),
        children: <Widget>[
          Text(
            l10n.t('editor_shot').replaceAll('{n}', '${photo.order + 1}'),
            style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.s12),
          ValueSlider(
            label: l10n.t('editor_duration'),
            icon: Icons.timer_rounded,
            value: photo.duration,
            min: AppLimits.minPhotoDuration,
            max: AppLimits.maxPhotoDuration,
            divisions: 590,
            format: (double v) => '${v.toStringAsFixed(1)}s',
            onChanged: (double v) => notifier.setPhotoDuration(photo.id, v),
          ),
          const SizedBox(height: AppTheme.s12),
          OutlinedButton.icon(
            onPressed: () => notifier.applyDurationToAll(photo.duration),
            icon: const Icon(Icons.all_inclusive_rounded, size: 18),
            label: Text(l10n.t('editor_apply_duration_all')),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ motion
  Widget _motionPanel(BuildContext context, L10n l10n, ProjectEditorState st) {
    final selected = st.selectedPhotoId ?? st.project.photos.first.id;
    final photo = st.photoById(selected) ?? st.project.photos.first;
    final motion = photo.motion;
    final notifier = ref.read(projectEditorProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.s16),
      children: <Widget>[
        if (motion == null)
          Card(
            color: context.theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.s16),
              child: Text(l10n.t('editor_tap_start_hint')),
            ),
          ),
        if (motion != null) ...<Widget>[
          SectionCard(
            title: l10n.t('editor_motion'),
            icon: Icons.movie_filter_outlined,
            subtitle: l10n.t('editor_select_photo_hint'),
            trailing: photo.isLocked
                ? Pill(
                    label: l10n.t('editor_locked'),
                    icon: Icons.lock_rounded,
                    color: AppColors.amber,
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.t(motion.motionType.labelKey),
                  style: context.theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ValueSlider(
                  label: l10n.t('motion_intensity'),
                  icon: Icons.speed_rounded,
                  value: motion.intensity,
                  min: 0,
                  max: 1,
                  format: (double v) => '${(v * 100).round()}%',
                  onChanged: (double v) =>
                      notifier.setMotionIntensity(photo.id, v),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: () => context.push(
                          '${AppRoutes.motionEditor}?photo=${photo.id}'),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text(l10n.t('motion_title')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => notifier.regeneratePhotoMotion(photo.id),
                      icon: const Icon(Icons.casino_outlined, size: 18),
                      label: Text(l10n.t('editor_regenerate_one')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        notifier.toggleLock(photo.id);
                      },
                      icon: Icon(
                          photo.isLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 18),
                      label: Text(photo.isLocked
                          ? l10n.t('motion_unlock')
                          : l10n.t('motion_lock')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppTheme.s12),
        SectionCard(
          title: l10n.t('editor_regenerate_all'),
          icon: Icons.auto_awesome_rounded,
          subtitle: l10n.t('editor_regenerate_locked_note'),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => notifier.autoMotion(regenerate: false),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.t('editor_auto_motion')),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: l10n.t('editor_regenerate_all'),
                    message: l10n.t('editor_regenerate_confirm'),
                    confirmLabel: l10n.t('editor_regenerate_all'),
                  );
                  if (ok) notifier.regenerateAll();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.t('editor_regenerate_all')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- transition
  Widget _transitionPanel(
      BuildContext context, L10n l10n, ProjectEditorState st) {
    final selected = st.selectedPhotoId ?? st.project.photos.first.id;
    final photo = st.photoById(selected) ?? st.project.photos.first;
    final notifier = ref.read(projectEditorProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(AppTheme.s16),
      children: <Widget>[
        SectionCard(
          title: l10n.t('transition_title'),
          icon: Icons.compare_arrows_rounded,
          subtitle: l10n.t('editor_shot').replaceAll('{n}', '${photo.order + 1}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final t in TransitionType.values)
                    ChoiceChip(
                      label: Text(l10n.t(t.labelKey)),
                      selected: photo.transition.type == t,
                      onSelected: (_) => notifier.setTransition(
                        photo.id,
                        photo.transition.copyWith(type: t),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.s12),
              ValueSlider(
                label: l10n.t('transition_duration'),
                icon: Icons.timelapse_rounded,
                value: photo.transition.duration,
                min: 0,
                max: 3,
                divisions: 60,
                format: (double v) => '${v.toStringAsFixed(2)}s',
                onChanged: (double v) => notifier.setTransition(
                  photo.id,
                  photo.transition.copyWith(duration: v),
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => notifier
                        .applyTransitionToAll(photo.transition),
                    icon: const Icon(Icons.select_all_rounded, size: 18),
                    label: Text(l10n.t('transition_apply_all')),
                  ),
                  OutlinedButton.icon(
                    onPressed: notifier.randomizeTransitions,
                    icon: const Icon(Icons.casino_outlined, size: 18),
                    label: Text(l10n.t('transition_random')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(k,
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Text(v, style: context.theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- photo
  /// Per-photo look: zoom (0.5..3.0) and opacity (0.2..1.0).
  Future<void> _openPhotoSheet(
      BuildContext context, L10n l10n, ProjectEditorState st) {
    final selectedId = st.selectedPhotoId;
    final photo = selectedId != null ? st.photoById(selectedId) : null;
    final notifier = ref.read(projectEditorProvider.notifier);
    if (photo == null) {
      return _openToolSheet(
        context,
        l10n.t('tool_photo_title'),
        Padding(
          padding: const EdgeInsets.all(AppTheme.s16),
          child: Text(l10n.t('hint_select_photo_first')),
        ),
      );
    }
    return _openToolSheet(
      context,
      l10n.t('tool_photo_title'),
      ListView(
        padding: const EdgeInsets.all(AppTheme.s16),
        children: <Widget>[
          Text(
            l10n.t('editor_shot').replaceAll('{n}', '${photo.order + 1}'),
            style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.s12),
          ValueSlider(
            label: l10n.t('photo_zoom'),
            icon: Icons.zoom_out_map_rounded,
            value: photo.zoomFactor,
            min: 0.5,
            max: 3.0,
            divisions: 50,
            format: (double v) => '${v.toStringAsFixed(2)}x',
            onChanged: (double v) => notifier.setPhotoZoom(photo.id, v),
          ),
          const SizedBox(height: AppTheme.s12),
          ValueSlider(
            label: l10n.t('photo_opacity'),
            icon: Icons.texture_rounded,
            value: photo.opacity,
            min: 0.2,
            max: 1.0,
            divisions: 40,
            format: (double v) => '${(v * 100).round()}%',
            onChanged: (double v) => notifier.setPhotoOpacity(photo.id, v),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- watermark
  Future<void> _openWatermarkSheet(BuildContext context, L10n l10n) {
    return _openToolSheet(
      context,
      l10n.t('tool_watermark_title'),
      _WatermarkEditor(),
    );
  }

  // ------------------------------------------------------------------ leave
  Future<void> _confirmLeave(
      BuildContext context, ProjectEditorState st) async {
    final l10n = context.l10n;
    if (!st.dirty) {
      context.go(AppRoutes.home);
      return;
    }
    final save = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.t('editor_save')),
        content: Text(l10n.t('editor_save_prompt')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: Text(l10n.t('action_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: Text(l10n.t('action_save')),
          ),
        ],
      ),
    );
    if (save == 'save') {
      try {
        await ref.read(projectEditorProvider.notifier).save();
      } catch (e) {
        debugPrint('save failed: $e');
        if (context.mounted) {
          context.snack(context.l10n.t('error_unknown'), isError: true);
        }
      }
    }
    if (context.mounted) context.go(AppRoutes.home);
  }
}

/// Watermark settings: text, size, opacity, 3×3 position, start/end.
/// Like the other sliders in the app, every change commits immediately
/// (the timeline lane additionally supports direct range dragging).
class _WatermarkEditor extends ConsumerWidget {
  const _WatermarkEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final st = ref.watch(projectEditorProvider);
    if (st == null) return const SizedBox.shrink();
    final project = st.project;
    final wm = project.watermark;
    final total = project.totalDuration;
    final notifier = ref.read(projectEditorProvider.notifier);
    final textController = TextEditingController(text: wm?.text ?? '');

    WatermarkSpec edit({
      String? text,
      double? fontScale,
      double? opacity,
      int? position,
      double? start,
      double? end,
    }) {
      final base = wm ??
          WatermarkSpec(text: 'MotionShot', start: 0.0, end: total);
      return base.copyWith(
        text: text ?? base.text,
        fontScale: fontScale,
        opacity: opacity,
        position: position,
        start: start,
        end: end,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.s16),
      children: <Widget>[
        Text(
          l10n.t('watermark_hint'),
          style: context.theme.textTheme.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.s12),
        TextField(
          controller: textController,
          autofocus: wm == null,
          decoration: InputDecoration(
            labelText: l10n.t('watermark_text'),
            hintText: l10n.t('watermark_text_hint'),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (String t) {
            final trimmed = t.trim();
            if (trimmed.isNotEmpty) {
              notifier.setWatermark(edit(text: trimmed));
            }
          },
        ),
        const SizedBox(height: AppTheme.s16),
        if (wm == null)
          FilledButton.icon(
            onPressed: () {
              final trimmed = textController.text.trim();
              notifier.setWatermark(
                  edit(text: trimmed.isEmpty ? 'MotionShot' : trimmed));
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.t('watermark_add')),
          )
        else ...<Widget>[
          ValueSlider(
            label: l10n.t('watermark_size'),
            icon: Icons.format_size_rounded,
            value: wm.fontScale,
            min: 0.02,
            max: 0.15,
            divisions: 13,
            format: (double v) => '${(v * 100).toStringAsFixed(1)}%',
            onChanged: (double v) => notifier.setWatermark(edit(fontScale: v)),
          ),
          const SizedBox(height: AppTheme.s12),
          ValueSlider(
            label: l10n.t('watermark_opacity'),
            icon: Icons.texture_rounded,
            value: wm.opacity,
            min: 0.2,
            max: 1.0,
            divisions: 40,
            format: (double v) => '${(v * 100).round()}%',
            onChanged: (double v) => notifier.setWatermark(edit(opacity: v)),
          ),
          const SizedBox(height: AppTheme.s12),
          Text(l10n.t('watermark_position'),
              style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (var pos = 0; pos < 9; pos++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Material(
                        color: wm.position == pos
                            ? const Color(0xFF46E0C0).withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              notifier.setWatermark(edit(position: pos)),
                          customBorder: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                  Radius.circular(8))),
                          child: Icon(
                            Icons.circle_outlined,
                            size: 10,
                            color: wm.position == pos
                                ? const Color(0xFF9FF3E2)
                                : context.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.s16),
          ValueSlider(
            label: l10n.t('watermark_start'),
            icon: Icons.play_circle_outline_rounded,
            value: wm.start,
            min: 0.0,
            max: math.max(0.3, total - 0.3),
            divisions: math.max(1, ((total - 0.3) * 10).floor()),
            format: (double v) => '${v.toStringAsFixed(1)}s',
            onChanged: (double v) => notifier.setWatermark(
                edit(start: math.min(v, wm.end - 0.3))),
          ),
          const SizedBox(height: AppTheme.s12),
          ValueSlider(
            label: l10n.t('watermark_end'),
            icon: Icons.stop_circle_outlined,
            value: wm.end,
            min: 0.3,
            max: math.max(0.3, total),
            divisions: math.max(1, (total * 10).floor()),
            format: (double v) => '${v.toStringAsFixed(1)}s',
            onChanged: (double v) => notifier.setWatermark(
                edit(end: math.max(v, wm.start + 0.3))),
          ),
          const SizedBox(height: AppTheme.s16),
          OutlinedButton.icon(
            onPressed: () => notifier.setWatermark(null),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(l10n.t('watermark_remove')),
          ),
        ],
      ],
    );
  }
}

/// Uncommitted watermark-lane drag state (committed on release).
class _WmDrag {
  _WmDrag(this.baseStart, this.baseEnd, this.start, this.end);

  final double baseStart;
  final double baseEnd;
  double start;
  double end;
}

/// In-progress trim of the music track: the committed span (base) plus the
/// live start/end while a handle is being dragged.
class _MusicTrimDrag {
  _MusicTrimDrag(this.baseStart, this.baseEnd, this.start, this.end);

  final double baseStart;
  final double baseEnd;
  double start;
  double end;
}

/// The music trim strip: bars of the track's real decoded amplitude laid out
/// across SOURCE time (0→duration), with the selected [trimStart, trimEnd]
/// span highlighted (dim outside) and a red marker at the current source
/// position (loop-aware, derived from the video playhead).
class _MusicTrimPainter extends CustomPainter {
  _MusicTrimPainter({
    required this.peaks,
    required this.sourceDuration,
    required this.trimStart,
    required this.trimEnd,
    required this.loop,
    required this.playhead,
  });

  final List<double> peaks;
  final double sourceDuration;
  final double trimStart;
  final double trimEnd;
  final bool loop;
  final double playhead;

  @override
  void paint(Canvas canvas, Size size) {
    if (sourceDuration <= 0 || size.isEmpty || peaks.isEmpty) return;
    final n = (size.width / 2.5).floor().clamp(24, 400);
    final barW = size.width / n;
    final selPaint =
        Paint()..color = const Color(0xFF46E0C0).withValues(alpha: 0.9);
    final dimPaint = Paint()..color = const Color(0xFF2A2A3A);

    for (var i = 0; i < n; i++) {
      final st = (i + 0.5) / n * sourceDuration;
      final idx = (st / sourceDuration * peaks.length)
          .floor()
          .clamp(0, peaks.length - 1);
      final amp = peaks[idx];
      final selected = st >= trimStart - 0.001 && st <= trimEnd + 0.001;
      final h =
          (amp * (size.height - 6)).clamp(2.0, size.height - 6).toDouble();
      final x = i * barW;
      canvas.drawRect(
        Rect.fromLTWH(x + 0.5, (size.height - h) / 2,
            math.max(1.0, barW - 1.5), h),
        amp > 0 && selected ? selPaint : dimPaint,
      );
    }

    // Current source position from the video playhead (loop-aware).
    final span = (trimEnd - trimStart).clamp(0.01, sourceDuration).toDouble();
    final stNow = loop
        ? trimStart + (playhead % span)
        : (trimStart + playhead).clamp(trimStart, trimEnd);
    if (stNow >= 0 && stNow <= sourceDuration) {
      final px = stNow / sourceDuration * size.width;
      canvas.drawLine(
        Offset(px, 0),
        Offset(px, size.height),
        Paint()
          ..color = const Color(0xFFFF3B5C)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_MusicTrimPainter old) =>
      old.peaks != peaks ||
      old.sourceDuration != sourceDuration ||
      old.trimStart != trimStart ||
      old.trimEnd != trimEnd ||
      old.loop != loop ||
      (old.playhead - playhead).abs() > 0.0005;
}
