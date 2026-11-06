/// Export settings: resolution, fps, codec, quality, aspect, then start.
///
/// Every option is checked against the device's real encoder capabilities, so an
/// impossible combination is disabled with an explanation instead of failing
/// halfway through a render.
library;

import 'package:flutter/material.dart' hide ValueSlider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/strings.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/export_settings.dart';
import '../../core/utils/ratio_utils.dart';
import 'export_request_builder.dart';
import '../platform/native_video_bridge/video_bridge.dart';
import '../project/project_editor_controller.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportSettings? _draft;

  ExportSettings _settings(ProjectEditorState st) =>
      _draft ?? st.project.exportSettings;

  void _update(ExportSettings s) => setState(() => _draft = s);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final st = ref.watch(projectEditorProvider);
    if (st == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('export_title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final settings = _settings(st);
    final dims = settings.dimensions(st.project.firstPhotoAspect);
    final bitrate = settings.bitrateFor(dims.width, dims.height);
    final caps = ref.watch(capabilitiesProvider);
    final hasAudio = st.project.audio?.hasAudio ?? false;
    final estimate = estimateOutputBytes(
      bitrate: bitrate,
      durationSeconds: st.project.totalDuration,
      hasAudio: hasAudio,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('export_title'))),
      body: SafeArea(
        child: PageBody(
          child: ListView(
            children: <Widget>[
              SectionCard(
                title: l10n.t('export_resolution'),
                icon: Icons.high_quality_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SegmentedChoice<ResolutionPreset>(
                      values: ResolutionPreset.values,
                      selected: settings.resolution,
                      labelBuilder: (ResolutionPreset r) => r.label,
                      enabledBuilder: (ResolutionPreset r) {
                        final c = caps.valueOrNull;
                        if (c == null) return true;
                        final d = settings
                            .copyWith(resolution: r)
                            .dimensions(st.project.firstPhotoAspect);
                        return c.canEncode(
                            width: d.width, height: d.height,
                            fps: settings.fps.value);
                      },
                      onChanged: (ResolutionPreset r) =>
                          _update(settings.copyWith(resolution: r)),
                    ),
                    const SizedBox(height: 8),
                    Text('${dims.width} × ${dims.height}',
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              SectionCard(
                title: l10n.t('export_fps'),
                icon: Icons.speed_rounded,
                child: SegmentedChoice<FpsPreset>(
                  values: FpsPreset.values,
                  selected: settings.fps,
                  labelBuilder: (FpsPreset f) => '${f.value}',
                  enabledBuilder: (FpsPreset f) {
                    final c = caps.valueOrNull;
                    if (c == null) return true;
                    return c.canEncode(
                        width: dims.width, height: dims.height, fps: f.value);
                  },
                  onChanged: (FpsPreset f) => _update(settings.copyWith(fps: f)),
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              SectionCard(
                title: l10n.t('export_codec'),
                icon: Icons.memory_rounded,
                subtitle: !(caps.valueOrNull?.supportsHevc ?? true)
                    ? l10n.t('export_hevc_unavailable')
                    : l10n.t('export_hardware'),
                child: SegmentedChoice<VideoCodecPreset>(
                  values: VideoCodecPreset.values,
                  selected: settings.codec,
                  labelBuilder: (VideoCodecPreset c) => c.label,
                  enabledBuilder: (VideoCodecPreset c) =>
                      c == VideoCodecPreset.h264 ||
                      (caps.valueOrNull?.supportsHevc ?? false),
                  onChanged: (VideoCodecPreset c) =>
                      _update(settings.copyWith(codec: c)),
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              SectionCard(
                title: l10n.t('export_quality'),
                icon: Icons.tune_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SegmentedChoice<QualityPreset>(
                      values: QualityPreset.values,
                      selected: settings.quality,
                      labelBuilder: (QualityPreset q) =>
                          l10n.t('export_quality_${q.id}'),
                      onChanged: (QualityPreset q) =>
                          _update(settings.copyWith(quality: q)),
                    ),
                    if (settings.quality == QualityPreset.custom) ...<Widget>[
                      const SizedBox(height: 8),
                      ValueSlider(
                        label: l10n.t('export_bitrate'),
                        icon: Icons.graphic_eq_rounded,
                        value: settings.customBitrate.toDouble().clamp(
                            1500000, 60000000),
                        min: 1500000,
                        max: 60000000,
                        format: (double v) =>
                            '${(v / 1000000).toStringAsFixed(1)} Mbps',
                        onChanged: (double v) => _update(settings.copyWith(
                            customBitrate: v.round())),
                      ),
                    ],
                    Row(
                      children: <Widget>[
                        const Icon(Icons.graphic_eq_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${l10n.t('export_bitrate')}: '
                          '${(bitrate / 1000000).toStringAsFixed(1)} Mbps · '
                          '${l10n.t('export_estimate')}: ${formatBytes(estimate)}',
                          style: context.theme.textTheme.bodySmall?.copyWith(
                            color: context.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              SectionCard(
                title: l10n.t('export_aspect'),
                icon: Icons.crop_landscape_rounded,
                child: SegmentedChoice<AspectPreset>(
                  values: AspectPreset.values,
                  selected: settings.aspect,
                  labelBuilder: (AspectPreset a) =>
                      a == AspectPreset.original
                          ? l10n.t('export_aspect_original')
                          : a.id,
                  onChanged: (AspectPreset a) =>
                      _update(settings.copyWith(aspect: a)),
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.s16),
                  child: Column(
                    children: <Widget>[
                      _row(context, l10n.t('export_total'),
                          formatClock(st.project.totalDuration)),
                      _row(context, l10n.t('export_frames'),
                          '${st.project.photos.length} × '
                          '${(st.project.totalDuration / st.project.photos.length).toStringAsFixed(1)}s '
                          '→ ${(st.project.totalDuration * settings.fps.value).round()}'),
                      _row(context,
                          l10n.t('audio_title'),
                          hasAudio
                              ? (st.project.audio?.displayName ?? '')
                              : l10n.t('audio_no_audio_short')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.s8),
              if (!(caps.valueOrNull?.supportsHevc ?? true))
                _notice(context, l10n.t('export_hevc_unavailable')),
              if (caps.hasValue &&
                  !caps.value!.canEncode(
                      width: dims.width, height: dims.height,
                      fps: settings.fps.value))
                _notice(
                  context,
                  l10n
                      .t('export_resolution_capped')
                      .replaceAll('{w}', '${caps.value!.maxWidth}')
                      .replaceAll('{h}', '${caps.value!.maxHeight}'),
                  isWarning: true,
                ),
              if (_lowSourcePhotos(st))
                _notice(context, l10n.t('export_low_source')),
              if (caps.hasError)
                _notice(context, l10n.t('export_blocked'), isWarning: true),
              const SizedBox(height: AppTheme.s16),
              GradientButton(
                label: l10n.t('export_start'),
                icon: Icons.movie_creation_outlined,
                onPressed: () {
                  // Persist the choice on the project so the request builder
                  // and the renderer see exactly what the user picked.
                  ref
                      .read(projectEditorProvider.notifier)
                      .setExportSettings(settings);
                  ref
                      .read(projectEditorProvider.notifier)
                      .save()
                      .catchError((Object e) {
                    // Non-fatal here: export progress saves again after the
                    // run. Log only, to keep the unhandled-error path quiet.
                    debugPrint('export pre-save failed: $e');
                  });
                  context.push(AppRoutes.exportProgress);
                },
              ),
              const SizedBox(height: AppTheme.s8),
              Text(
                l10n.t('settings_privacy'),
                textAlign: TextAlign.center,
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.s24),
            ],
          ),
        ),
      ),
    );
  }

  bool _lowSourcePhotos(ProjectEditorState st) {
    final dims = _settings(st).dimensions(st.project.firstPhotoAspect);
    final target = dims.width * dims.height;
    return st.project.photos
        .any((p) => p.width * p.height < target * 0.6);
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(k,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            Flexible(child: Text(v, textAlign: TextAlign.end)),
          ],
        ),
      );

  Widget _notice(BuildContext context, String text, {bool isWarning = false}) {
    final color = isWarning ? AppColors.amber : context.theme.colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.s8),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.s12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            Icon(isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
                size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: color,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
