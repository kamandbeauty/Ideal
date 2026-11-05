/// The editor: preview, photo strip, motion + transition + audio + project
/// panels, Auto Motion and Export entry points.
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
import '../../core/models/photo_item.dart';
import '../../core/models/project.dart';
import '../../core/models/transition.dart';
import '../../core/utils/ratio_utils.dart';
import '../audio/audio_sheet.dart';
import '../preview/motion_preview.dart';
import '../preview/playback_controller.dart';
import '../project/project_editor_controller.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
    // Keep the playback clock bound to the current timeline.
    ref.listen<ProjectEditorState?>(projectEditorProvider, (_, ProjectEditorState? next) {
      if (next == null) return;
      ref.read(playbackProvider.notifier).bind(next.project);
    });
    ref.read(playbackProvider.notifier).bind(project);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _confirmLeave(context, st),
        ),
        title: Text(project.name, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.t('editor_undo'),
            onPressed: st.canUndo
                ? () => ref.read(projectEditorProvider.notifier).undo()
                : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: l10n.t('editor_redo'),
            onPressed: st.canRedo
                ? () => ref.read(projectEditorProvider.notifier).redo()
                : null,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: l10n.t('editor_save'),
            onPressed: () async {
              await ref.read(projectEditorProvider.notifier).save();
              if (context.mounted) {
                context.snack(l10n.t('editor_saved'));
              }
            },
            icon: Icon(st.dirty
                ? Icons.save_rounded
                : Icons.cloud_done_outlined),
          ),
          IconButton(
            tooltip: l10n.t('preview_title'),
            onPressed: () => context.push(AppRoutes.preview),
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final wide = c.maxWidth >= 900;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: _previewColumn(context, l10n, st, playback),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 2,
                    child: _panels(context, l10n, st),
                  ),
                ],
              );
            }
            return Column(
              children: <Widget>[
                _previewColumn(context, l10n, st, playback, compact: true),
                const SizedBox(height: 8),
                Expanded(child: _panels(context, l10n, st)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _bottomBar(context, l10n, st),
    );
  }

  Widget _previewColumn(
    BuildContext context,
    L10n l10n,
    ProjectEditorState st,
    FrameState playback, {
    bool compact = false,
  }) {
    final currentIndex = playback.layers.isEmpty
        ? 0
        : playback.layers.last.photoIndex;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.s12),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: MotionPreview(
                project: st.project,
                frame: playback,
                showSafeFrame: false,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _transport(context, l10n, playback, currentIndex, st),
          const SizedBox(height: 8),
          _strip(context, l10n, st, currentIndex, compact: compact),
        ],
      ),
    );
  }

  Widget _transport(
    BuildContext context,
    L10n l10n,
    FrameState playback,
    int currentIndex,
    ProjectEditorState st,
  ) {
    final ctrl = ref.read(playbackProvider.notifier);
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: l10n.t('preview_previous'),
              onPressed: ctrl.previousPhoto,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            IconButton.filled(
              tooltip: playback.playing
                  ? l10n.t('preview_pause')
                  : l10n.t('preview_play'),
              onPressed: ctrl.togglePlay,
              icon: Icon(playback.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
            ),
            IconButton(
              tooltip: l10n.t('preview_stop'),
              onPressed: ctrl.stop,
              icon: const Icon(Icons.stop_rounded),
            ),
            IconButton(
              tooltip: l10n.t('preview_next'),
              onPressed: ctrl.nextPhoto,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            Expanded(
              child: Slider(
                value: playback.progress,
                onChanged: (double v) => ctrl.seekFraction(v),
                onChangeStart: (_) => ctrl.beginScrub(),
                onChangeEnd: (_) => ctrl.endScrub(),
              ),
            ),
            Text(
              '${formatClockPrecise(playback.time)} / ${formatClock(playback.total)}',
              style: context.theme.textTheme.labelSmall?.copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _strip(
    BuildContext context,
    L10n l10n,
    ProjectEditorState st,
    int currentIndex, {
    bool compact = false,
  }) {
    final photos = st.project.photos;
    return SizedBox(
      height: compact ? 64 : 78,
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
            width: compact ? 64 : 78,
            child: PhotoTile(
              selected: selected || i == currentIndex,
              missing: p.missing,
              image: exists ? Image.file(File(path), fit: BoxFit.cover) : null,
              badge: p.isLocked
                  ? const Icon(Icons.lock_rounded, size: 14, color: Colors.white)
                  : null,
              onTap: () {
                ref.read(projectEditorProvider.notifier).selectPhoto(p.id);
                final notifier = ref.read(playbackProvider.notifier);
                final segs = st.segments();
                if (i < segs.length) notifier.seek(segs[i].start + 0.001);
              },
              onLongPress: () => context.push(
                  '${AppRoutes.motionEditor}?photo=${p.id}'),
              overlay: i == currentIndex
                  ? Align(
                      alignment: AlignmentDirectional.bottomCenter,
                      child: Container(
                        height: 3,
                        color: context.theme.colorScheme.primary,
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _panels(BuildContext context, L10n l10n, ProjectEditorState st) {
    return Column(
      children: <Widget>[
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: <Widget>[
            Tab(text: l10n.t('editor_motion')),
            Tab(text: l10n.t('editor_transition')),
            Tab(text: l10n.t('editor_audio')),
            Tab(text: l10n.t('editor_project')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: <Widget>[
              _motionPanel(context, l10n, st),
              _transitionPanel(context, l10n, st),
              _audioPanel(context, l10n, st),
              _projectPanel(context, l10n, st),
            ],
          ),
        ),
      ],
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
                ValueSlider(
                  label: l10n.t('editor_duration'),
                  icon: Icons.timer_outlined,
                  value: photo.duration,
                  min: 1,
                  max: 15,
                  divisions: 140,
                  format: (double v) => '${v.toStringAsFixed(1)}s',
                  onChanged: (double v) => notifier.setPhotoDuration(photo.id, v),
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
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
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
                icon: const Icon(Icons.refresh_rounded, size: 18),
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

  // ------------------------------------------------------------------- audio
  Widget _audioPanel(BuildContext context, L10n l10n, ProjectEditorState st) {
    final audio = st.project.audio;
    final notifier = ref.read(projectEditorProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(AppTheme.s16),
      children: <Widget>[
        SectionCard(
          title: l10n.t('audio_title'),
          icon: Icons.music_note_outlined,
          subtitle: l10n.t('audio_supported'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (audio == null || !audio.hasAudio)
                EmptyState(
                  icon: Icons.library_music_outlined,
                  title: l10n.t('audio_no_music'),
                  action: FilledButton.icon(
                    onPressed: () => showAudioSheet(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.t('audio_pick')),
                  ),
                )
              else ...<Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.audiotrack_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(audio.displayName,
                          overflow: TextOverflow.ellipsis),
                    ),
                    TextButton(
                      onPressed: () => notifier.setAudio(null),
                      child: Text(l10n.t('audio_remove')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => showAudioSheet(context, ref),
                  child: Text(l10n.t('audio_title')),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- project
  Widget _projectPanel(
      BuildContext context, L10n l10n, ProjectEditorState st) {
    final notifier = ref.read(projectEditorProvider.notifier);
    final project = st.project;
    final caps = ref.watch(capabilitiesProvider);
    return ListView(
      padding: const EdgeInsets.all(AppTheme.s16),
      children: <Widget>[
        SectionCard(
          title: l10n.t('editor_project'),
          icon: Icons.movie_outlined,
          child: Column(
            children: <Widget>[
              _kv(context, l10n.t('editor_total'), formatClock(project.totalDuration)),
              _kv(context, l10n.t('editor_photo'),
                  '${project.photos.length}'),
              _kv(context, l10n.t('export_frames'),
                  '${project.videoFrameCount}'),
              _kv(context, l10n.t('export_aspect'),
                  aspectLabel(project.outputAspect)),
              _kv(context, l10n.t('export_resolution'),
                  '${project.exportSettings.dimensions(project.firstPhotoAspect).width}'
                  '×${project.exportSettings.dimensions(project.firstPhotoAspect).height}'),
              const Divider(height: 24),
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
        ),
        const SizedBox(height: AppTheme.s12),
        SectionCard(
          title: l10n.t('settings_device'),
          icon: Icons.memory_rounded,
          child: caps.when(
            data: (c) => Column(
              children: <Widget>[
                _kv(context, l10n.t('settings_device_encoder'), c.codecName),
                _kv(
                    context,
                    l10n.t('settings_device_max'),
                    '${c.maxWidth}×${c.maxHeight} @ ${c.maxFps}fps'),
                _kv(context, l10n.t('settings_device_ram'),
                    '${c.totalRamMb} MB'),
                _kv(context, l10n.t('export_hardware'),
                    c.hasGlEs3 ? 'OpenGL ES 3.0' : 'OpenGL ES 2.0'),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (Object e, StackTrace s) => Text(
              l10n.t('export_blocked'),
              style: TextStyle(color: context.theme.colorScheme.error),
            ),
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

  // --------------------------------------------------------------- bottom bar
  Widget _bottomBar(
      BuildContext context, L10n l10n, ProjectEditorState st) {
    final missing = st.project.missingPhotos.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.read(projectEditorProvider.notifier).autoMotion(),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(l10n.t('editor_start')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GradientButton(
                label: l10n.t('editor_export'),
                icon: Icons.file_download_outlined,
                onPressed: () {
                  if (missing) {
                    context.snack(l10n.t('error_photoMissing'), isError: true);
                    return;
                  }
                  context.push(AppRoutes.export);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      await ref.read(projectEditorProvider.notifier).save();
    }
    if (context.mounted) context.go(AppRoutes.home);
  }
}
