import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/platform/contracts.dart';
import '../../core/time_us.dart';
import '../../models/video_asset.dart';
import '../../services/project_repository.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_card.dart';
import '../../shared/widgets/sf_scaffold.dart';
import '../../shared/widgets/stat_chip.dart';
import '../effects/caption_fonts.dart';
import '../effects/caption_labels.dart';
import '../effects/caption_preset.dart';
import '../effects/caption_renderer.dart';
import '../effects/presets_library.dart';
import 'widgets/native_player_view.dart';

/// Phase 1 editor: real Media3 playback of the *original* file plus the real
/// export plan computed by the native quality engine. Subtitle editing, effects
/// and rendering arrive in later phases; nothing here pretends otherwise.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final SfPlayerController _player = SfPlayerController.create();

  /// The active caption look. It is real state, not a placeholder: the overlay
  /// below is painted by the same renderer the export path will use.
  CaptionPreset _preset = PresetsLibrary.byId('viral-fa');

  static const String _sampleCaption = 'متن نمونه برای پیش‌نمایش استایل';

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ProjectDetail> detail = ref.watch(projectDetailProvider(widget.projectId));
    return SfScaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.project.name ?? 'پروژه'),
      ),
      child: detail.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (Object error, StackTrace stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger)),
          ),
        ),
        data: (ProjectDetail loaded) => _buildBody(loaded),
      ),
    );
  }

  Future<void> _pickCaptionStyle() async {
    final CaptionPreset? picked = await context.push<CaptionPreset>('/captions');
    if (picked == null || !mounted) return;
    setState(() => _preset = picked);
  }

  Widget _buildBody(ProjectDetail detail) {
    final VideoAsset? asset = detail.asset;
    if (asset == null) {
      return const Center(child: Text('این پروژه ویدئویی ندارد.'));
    }
    if (!detail.mediaAvailable) {
      return Center(
        child: SfCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.link_off_rounded, color: AppColors.warning, size: 32),
              const SizedBox(height: 12),
              Text('فایل اصلی پیدا نشد', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'فایل ویدئو جابه‌جا یا حذف شده است. پروژه و زیرنویس‌هایت سالم است؛ '
                'برای ادامه، فایل را دوباره انتخاب کن (در فاز کامل، مسیر جایگزین هم قابل انتخاب است).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.8),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 28),
      children: <Widget>[
        ValueListenableBuilder<SfPlayerState>(
          valueListenable: _player.state,
          builder: (BuildContext context, SfPlayerState state, Widget? child) {
            return Column(
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    NativeVideoPlayer(uri: asset.uri, controller: _player),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CaptionSurface(preset: _preset, text: _sampleCaption),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TransportBar(state: state, player: _player),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('مشخصات منبع', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  StatChip(label: asset.resolutionLabel, icon: Icons.aspect_ratio_rounded),
                  StatChip(label: '${asset.fpsLabel} fps', icon: Icons.speed_rounded),
                  StatChip(label: '${(asset.bitrateBps / 1000000).toStringAsFixed(2)} Mbps'),
                  StatChip(label: asset.videoCodec ?? 'codec?'),
                  StatChip(label: TimeUs.humanDuration(asset.durationUs)),
                  if (asset.hdr) const StatChip(label: 'HDR', tint: AppColors.warning),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _CaptionStyleCard(
          preset: _preset,
          onPick: _pickCaptionStyle,
        ),
        const SizedBox(height: 14),
        _ExportPlanCard(asset: asset),
        const SizedBox(height: 14),
        SfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.rocket_launch_outlined,
                      color: AppColors.primarySoft, size: 20),
                  const SizedBox(width: 8),
                  Text('گام بعدی', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'در فاز ۲ موتور Whisper به این پروژه وصل می‌شود: استخراج صدا، تشخیص گفتار فارسی/'
                'انگلیسی و تولید Timestamp. تا زمانی که مدل روی دستگاه نصب نشده باشد، دکمه '
                '«تشخیص گفتار» عمداً غیرفعال است تا درصد پیشرفت ساختگی نمایش داده نشود.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.9),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportBar extends StatelessWidget {
  const _TransportBar({required this.state, required this.player});

  final SfPlayerState state;
  final SfPlayerController player;

  @override
  Widget build(BuildContext context) {
    final int duration = state.durationUs;
    final int position = state.positionUs > duration ? duration : state.positionUs;
    return SfCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: <Widget>[
          Slider(
            value: duration == 0 ? 0 : position.clamp(0, duration).toDouble(),
            max: duration == 0 ? 1 : duration.toDouble(),
            onChanged: duration == 0
                ? null
                : (double value) => player.seekTo(value.round()),
          ),
          Row(
            children: <Widget>[
              IconButton.filled(
                onPressed: () => state.isPlaying ? player.pause() : player.play(),
                icon: Icon(state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                '${TimeUs.precise(position)} / ${TimeUs.precise(duration)}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (state.isBuffering)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (state.error != null)
                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the *real* numbers the C++ planner would use for an Original Quality
/// burn-in export, straight from `PlanExport`. No invented estimates.
class _ExportPlanCard extends ConsumerStatefulWidget {
  const _ExportPlanCard({required this.asset});

  final VideoAsset asset;
  @override
  ConsumerState<_ExportPlanCard> createState() => _ExportPlanCardState();
}

class _ExportPlanCardState extends ConsumerState<_ExportPlanCard> {
  late final Future<ExportPlanDto> _plan = _load();

  Future<ExportPlanDto> _load() {
    final VideoAsset asset = widget.asset;
    return ref.read(nativeBridgeProvider).planExport(
          source: VideoProbeResult(
            uri: asset.uri,
            displayName: asset.displayName,
            sizeBytes: asset.sizeBytes,
            durationUs: asset.durationUs,
            width: asset.width,
            height: asset.height,
            rotationDegrees: asset.rotationDegrees,
            fpsMilli: asset.fpsMilli,
            bitrateBps: asset.bitrateBps,
            hdr: asset.hdr,
            videoCodec: asset.videoCodec,
            colorTransfer: asset.colorTransfer,
            audioCodec: asset.audioCodec,
            audioSampleRate: asset.audioSampleRate,
            audioChannels: asset.audioChannels,
            audioBitrateBps: asset.audioBitrateBps,
          ),
          burnIn: true,
          keepSourceAudio: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExportPlanDto>(
      future: _plan,
      builder: (BuildContext context, AsyncSnapshot<ExportPlanDto> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SfCard(child: Text('در حال محاسبه پلن خروجی…'));
        }
        if (snapshot.hasError || !(snapshot.data?.ok ?? false)) {
          return SfCard(
            child: Text(
              'پلن خروجی در دسترس نیست: ${snapshot.error ?? snapshot.data?.errorCode ?? 'خطای نامشخص'}',
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          );
        }
        final ExportPlanDto plan = snapshot.data!;
        return SfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('پلن خروجی «کیفیت اصلی»',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'محاسبه‌شده توسط موتور بومی؛ همین اعداد به رندرکننده داده می‌شود.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  StatChip(label: '${plan.width}×${plan.height}'),
                  StatChip(label: '${plan.fps.toStringAsFixed(2)} fps'),
                  StatChip(label: '${(plan.videoBitrateBps / 1000000).toStringAsFixed(1)} Mbps'),
                  StatChip(label: plan.codec.toUpperCase()),
                  StatChip(
                    label: plan.passthroughVideo ? 'بدون کدگذاری مجدد' : 'رندر مجدد',
                    tint: plan.passthroughVideo ? AppColors.success : AppColors.warning,
                  ),
                  StatChip(label: _size(plan.estimatedBytes)),
                ],
              ),
              if (plan.warnings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                ...plan.warnings.map(
                  (String code) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _warningText(code),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary, height: 1.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _size(int bytes) {
    if (bytes <= 0) return '—';
    final double mb = bytes / (1024 * 1024);
    return mb >= 1024 ? '${(mb / 1024).toStringAsFixed(2)} GB' : '${mb.toStringAsFixed(0)} MB';
  }

  static String _warningText(String code) => switch (code) {
        'UPSCALE_CLAMPED' => 'رزولوشن درخواستی از منبع بزرگ‌تر بود؛ روی کیفیت منبع نگه داشته شد.',
        'UPSCALE_INTERPOLATED' =>
          'بزرگ‌نمایی مجاز است، اما پیکسل‌های اضافه واقعاً جزئیات جدید نیستند.',
        'FPS_CHANGED' => 'نرخ فریم تغییر می‌کند؛ فریم‌های میانی فقط تکرار می‌شوند.',
        'HEVC_UNAVAILABLE_H264' => 'سخت‌افزار HEVC ندارد؛ خروجی H.264 می‌شود.',
        'BITRATE_BELOW_SOURCE' => 'بیت‌ریت برنامه‌ریزی‌شده از منبع کمتر است.',
        'HDR_NOT_PRESERVED' => 'منبع HDR است اما رندر با تغییر تصویر، HDR را حفظ نمی‌کند.',
        'AUDIO_REENCODED' => 'صدا دوباره کدگذاری می‌شود.',
        'STREAM_COPY' => 'تصویر بدون کدگذاری مجدد کپی می‌شود (بهترین حالت برای کیفیت).',
        'UNKNOWN_SOURCE_BITRATE' => 'بیت‌ریت منبع نامشخص بود؛ مقدار محافظه‌کارانه انتخاب شد.',
        _ => code,
      };
}

/// Entry point to the caption gallery plus a readout of the active look, so the
/// user always knows which style the overlay above is painting.
class _CaptionStyleCard extends StatelessWidget {
  const _CaptionStyleCard({required this.preset, required this.onPick});

  final CaptionPreset preset;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final CaptionFont font = CaptionFonts.byFamily(preset.fontFamily);
    return SfCard(
      onTap: onPick,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primarySoft, size: 20),
              const SizedBox(width: 8),
              Text('استایل زیرنویس', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              const Icon(Icons.chevron_left_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${preset.name} • ${font.label} • ${captionAnimationLabel(preset.effects.enter)} / ${captionExitLabel(preset.effects.exit)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              StatChip(label: 'پیش‌نمایش زنده', icon: Icons.play_circle_outline_rounded),
              StatChip(label: 'موتور رندر مشترک با خروجی', icon: Icons.layers_outlined),
            ],
          ),
        ],
      ),
    );
  }
}
