/// Full-screen real-time preview with transport, timeline and per-shot entry.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/strings.dart';
import '../../app/router.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../app/widgets/progress.dart';
import '../../core/utils/ratio_utils.dart';
import '../project/project_editor_controller.dart';
import '../transitions/timeline_engine.dart';
import 'motion_preview.dart';
import 'playback_controller.dart';
import 'preview_audio.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  /// Overlays the active photo's camera path on the preview.
  bool _showMotionPath = true;

  @override
  void initState() {
    super.initState();
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
    final frame = ref.watch(playbackProvider);
    // Keep the playback clock in sync if the project is edited while this
    // screen is open (e.g. via the per-shot motion editor): bind preserves
    // the playhead and playback state, it only re-derives durations.
    // The listener fires during build, so the bind is deferred until the
    // frame is done (mutating a provider mid-build is not allowed).
    ref.listen(projectEditorProvider, (_, next) {
      if (next == null) return;
      final changed = next.project;
      Future.microtask(
          () => ref.read(playbackProvider.notifier).bind(changed));
    });
    if (st == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('preview_title'))),
        body: const Center(child: HeroSpinner()),
      );
    }
    final ctrl = ref.read(playbackProvider.notifier);
    final segments = buildSegments(
      st.project.photos.map((p) => p.id).toList(growable: false),
      st.project.photos.map((p) => p.duration).toList(growable: false),
      st.project.photos.map((p) => p.transition).toList(growable: false),
    );
    final currentIndex = frame.layers.isEmpty ? 0 : frame.layers.last.photoIndex;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l10n.t('preview_title')),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.t('motion_show_path'),
            onPressed: () => setState(() => _showMotionPath = !_showMotionPath),
            icon: Icon(
              _showMotionPath ? Icons.route_rounded : Icons.route_outlined,
              color: _showMotionPath
                  ? AppColors.blue
                  : context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: l10n.t('preview_edit_current'),
            onPressed: currentIndex < st.project.photos.length
                ? () {
                    final id = st.project.photos[currentIndex].id;
                    ref.read(projectEditorProvider.notifier).selectPhoto(id);
                    context.push('${AppRoutes.motionEditor}?photo=$id');
                  }
                : null,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.s16),
                  // Music plays here too, in sync with the playhead.
                  child: PreviewAudioSync(
                    child: MotionPreview(
                      project: st.project,
                      frame: frame,
                      showMotionPath: _showMotionPath,
                      activePhotoIndex: currentIndex,
                      activeLocalTime:
                          frame.layers.isEmpty ? 0 : frame.layers.last.localTime,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16),
              child: Column(
                children: <Widget>[
                  // Timeline with one marker per photo and the transition zones.
                  SizedBox(
                    height: 26,
                    child: LayoutBuilder(
                      builder: (BuildContext c, BoxConstraints box) {
                        return GestureDetector(
                          onTapDown: (TapDownDetails d) {
                            final f = (d.localPosition.dx / box.maxWidth)
                                .clamp(0.0, 1.0);
                            ctrl.seekFraction(f);
                          },
                          onHorizontalDragStart: (_) => ctrl.beginScrub(),
                          onHorizontalDragUpdate: (DragUpdateDetails d) {
                            final f = (d.localPosition.dx / box.maxWidth)
                                .clamp(0.0, 1.0);
                            ctrl.seekFraction(f);
                          },
                          onHorizontalDragEnd: (_) => ctrl.endScrub(),
                          child: CustomPaint(
                            painter: _TimelinePainter(
                              segments: segments,
                              total: frame.total,
                              position: frame.progress,
                              accent: Theme.of(context).colorScheme.primary,
                              activeIndex: currentIndex,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: ctrl.previousPhoto,
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      IconButton.filled(
                        onPressed: ctrl.togglePlay,
                        icon: Icon(frame.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                      ),
                      IconButton(
                        onPressed: ctrl.stop,
                        icon: const Icon(Icons.stop_rounded),
                      ),
                      IconButton(
                        onPressed: ctrl.nextPhoto,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${formatClockPrecise(frame.time)} / '
                        '${formatClock(frame.total)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures()
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        l10n.t('editor_shot').replaceAll(
                            '{n}', '${currentIndex + 1}/${st.project.photos.length}'),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t('preview_low_res'),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.s12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.segments,
    required this.total,
    required this.position,
    required this.accent,
    required this.activeIndex,
  });

  final List<TimelineSegment> segments;
  final double total;
  final double position;
  final Color accent;
  final int activeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || segments.isEmpty) return;
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(6));
    canvas.drawRRect(r, Paint()..color = Colors.white10);
    // Alternating segment shading so shot boundaries are visible.
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final x0 = s.start / total * size.width;
      final x1 = s.end / total * size.width;
      final shade = i.isEven ? Colors.white.withValues(alpha: 0.06) : Colors.transparent;
      canvas.drawRect(Rect.fromLTRB(x0, 0, x1, size.height), Paint()..color = shade);
      if (i == activeIndex) {
        canvas.drawRect(
          Rect.fromLTRB(x0, 0, x1, size.height),
          Paint()..color = accent.withValues(alpha: 0.18),
        );
      }
      // transition zone
      final d = clampedTransitionSeconds(
          i,
          segments.map((e) => e.duration).toList(growable: false),
          segments.map((e) => e.transition).toList(growable: false));
      if (d > 0 && i < segments.length - 1) {
        final mid = x1;
        final w = d / total * size.width / 2;
        canvas.drawRect(
          Rect.fromLTRB(mid - w, 0, mid + w, size.height),
          Paint()..color = Colors.white.withValues(alpha: 0.10),
        );
      }
    }
    final px = position * size.width;
    canvas.drawRect(
      Rect.fromLTWH(px - 1, -3, 2, size.height + 6),
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(Offset(px, size.height / 2), 4, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.position != position ||
      old.activeIndex != activeIndex ||
      old.total != total;
}
