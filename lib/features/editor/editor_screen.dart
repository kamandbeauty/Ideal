/// The editor — InShot-style workspace:
/// big canvas, centered transport, an icon+label tool bar, and a thumbnail
/// timeline with a prominent "+" add button. Every tool opens a bottom
/// sheet (motion, transition, music, duration, canvas/aspect).
library;

import 'dart:io';

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
import '../../core/utils/ratio_utils.dart';
import '../transitions/timeline_engine.dart';
import '../audio/audio_sheet.dart';
import '../preview/motion_preview.dart';
import '../preview/playback_controller.dart';
import '../project/project_editor_controller.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _picking = false;

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
                  child: MotionPreview(
                    project: st.project,
                    frame: playback,
                    showSafeFrame: false,
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
  Widget _timeline(
      BuildContext context, L10n l10n, ProjectEditorState st, FrameState playback) {
    final photos = st.project.photos;
    final currentIndex =
        playback.layers.isEmpty ? 0 : playback.layers.last.photoIndex;
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
                child: SizedBox(
                  height: 54,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (BuildContext c, int i) {
                      final p = photos[i];
                      final selected = p.id == st.selectedPhotoId;
                      final path = p.thumbnailPath;
                      final exists = path != null && File(path).existsSync();
                      return SizedBox(
                        width: 54,
                        child: PhotoTile(
                          selected: selected || i == currentIndex,
                          missing: p.missing,
                          image: exists
                              ? Image.file(File(path), fit: BoxFit.cover)
                              : null,
                          badge: p.isLocked
                              ? const Icon(Icons.lock_rounded,
                                  size: 12, color: Colors.white)
                              : null,
                          onTap: () {
                            ref
                                .read(projectEditorProvider.notifier)
                                .selectPhoto(p.id);
                            final notifier =
                                ref.read(playbackProvider.notifier);
                            final segs = buildSegments(
                                st.photoIds, st.durations, st.transitions);
                            if (i < segs.length) {
                              notifier.seek(segs[i].start + 0.001);
                            }
                          },
                          onLongPress: () => context.push(
                              '${AppRoutes.motionEditor}?photo=${p.id}'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
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
