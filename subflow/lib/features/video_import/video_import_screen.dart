import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/platform/contracts.dart';
import '../../models/project.dart';
import '../../services/media_service.dart';
import '../../services/project_repository.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_button.dart';
import '../../shared/widgets/sf_card.dart';
import '../../shared/widgets/sf_scaffold.dart';
import '../../shared/widgets/stat_chip.dart';

/// Import flow: Photo Picker -> MediaMetadataRetriever probe -> project row.
/// The video file itself is never copied or re-encoded here.
class VideoImportScreen extends ConsumerStatefulWidget {
  const VideoImportScreen({super.key});

  @override
  ConsumerState<VideoImportScreen> createState() => _VideoImportScreenState();
}

class _VideoImportScreenState extends ConsumerState<VideoImportScreen> {
  bool _busy = false;
  String? _error;
  VideoProbeResult? _probe;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final MediaService media = ref.read(mediaServiceProvider);
      final VideoProbeResult? probe = await media.pickAndProbe();
      if (probe == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _probe = probe;
        _busy = false;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.message;
        _busy = false;
      });
    }
  }

  Future<void> _createProject() async {
    final VideoProbeResult? probe = _probe;
    if (probe == null) return;
    setState(() => _busy = true);
    try {
      final ProjectRepository repo = ref.read(projectRepositoryProvider);
      final Project project = await repo.createFromProbe(probe);
      await ref.read(projectsControllerProvider.notifier).refresh();
      if (!mounted) return;
      context.pushReplacement('/project/${project.id}');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final VideoProbeResult? probe = _probe;
    return SfScaffold(
      appBar: AppBar(title: const Text('ورود ویدئو')),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: <Widget>[
          SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('۱. فایل را انتخاب کن',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                const Text(
                  'از گالری اندروید (Photo Picker) یا مرور فایل‌ها. دسترسی به فایل فقط '
                  'برای خواندن است و ویدئو از گوشی خارج نمی‌شود.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13, height: 1.8),
                ),
                const SizedBox(height: 16),
                SfPrimaryButton(
                  label: probe == null ? 'انتخاب ویدئو' : 'انتخاب ویدئوی دیگر',
                  icon: Icons.video_library_outlined,
                  loading: _busy && probe == null,
                  onPressed: _busy ? null : _pick,
                ),
              ],
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            SfCard(
              child: Row(
                children: <Widget>[
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
          if (probe != null) ...<Widget>[
            const SizedBox(height: 14),
            SfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('۲. مشخصات فایل', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _Row(label: 'نام فایل', value: probe.displayName),
                  _Row(label: 'حجم', value: _sizeLabel(probe.sizeBytes)),
                  _Row(label: 'مدت', value: _durationLabel(probe.durationUs)),
                  _Row(label: 'رزولوشن', value: '${probe.width}×${probe.height}'),
                  _Row(label: 'نرخ فریم', value: '${(probe.fpsMilli / 1000).toStringAsFixed(3)} fps'),
                  _Row(label: 'بیت‌ریت', value: '${(probe.bitrateBps / 1000000).toStringAsFixed(2)} Mbps'),
                  _Row(label: 'کدک ویدئو', value: probe.videoCodec ?? 'نامشخص'),
                  _Row(label: 'صدا', value: probe.audioCodec == null
                      ? 'بدون صدا'
                      : '${probe.audioCodec} · ${probe.audioChannels}ch · ${probe.audioSampleRate} Hz'),
                  if (probe.hdr) ...<Widget>[
                    const SizedBox(height: 10),
                    const StatChip(
                      label: 'HDR — خروجی با تغییر تصویر، HDR را حفظ نمی‌کند',
                      tint: AppColors.warning,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SfPrimaryButton(
                    label: 'ساخت پروژه و ادامه',
                    icon: Icons.arrow_forward_rounded,
                    loading: _busy,
                    onPressed: _busy ? null : _createProject,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _sizeLabel(int bytes) {
    if (bytes <= 0) return 'نامشخص';
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  static String _durationLabel(int us) {
    final int totalSeconds = us ~/ 1000000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 12.5, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
