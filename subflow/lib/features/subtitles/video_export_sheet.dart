import 'package:flutter/material.dart';

import '../../services/video_export_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_progress.dart';

/// The three sheets of a video export: choose a quality, watch the render,
/// then look at what was produced.
///
/// They are separate steps on purpose. Burning captions re-encodes the whole
/// clip, which can take a while on a mid-range phone, so the user gets a real
/// progress bar and a working cancel button instead of a frozen editor.

Future<RenderQuality?> showRenderQualitySheet(
  BuildContext context, {
  required int cueCount,
  required int durationSeconds,
  required String styleName,
  required RenderQuality current,
}) {
  RenderQuality selected = current;
  return showModalBottomSheet<RenderQuality>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.movie_creation_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('ویدئوی با زیرنویس سوخته',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$cueCount زیرنویس با استایل «$styleName» روی تصویر ساخته می‌شود '
              '($durationSeconds ثانیه). فایل اصلی دست‌نخورده می‌ماند؛ یک MP4 تازه ساخته می‌شود.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.8),
            ),
            const SizedBox(height: 14),
            for (final RenderQuality quality in RenderQuality.values)
              _QualityTile(
                quality: quality,
                selected: quality == selected,
                onTap: () => setState(() => selected = quality),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primarySoft,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.of(context).pop(selected),
                child: const Text('شروع ساخت ویدئو',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QualityTile extends StatelessWidget {
  const _QualityTile({required this.quality, required this.selected, required this.onTap});

  final RenderQuality quality;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primarySoft : AppColors.outline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? AppColors.primarySoft : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(quality.label,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(quality.hint,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Runs [task] behind a progress dialog. Returns null when the user cancelled.
Future<VideoRenderResult?> showRenderProgressDialog(
  BuildContext context, {
  required Future<VideoRenderResult> Function(void Function(int percent) onProgress) task,
  required Future<void> Function() onCancel,
}) {
  return showDialog<VideoRenderResult>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _RenderDialog(task: task, onCancel: onCancel),
  );
}

class _RenderDialog extends StatefulWidget {
  const _RenderDialog({required this.task, required this.onCancel});

  final Future<VideoRenderResult> Function(void Function(int percent) onProgress) task;
  final Future<void> Function() onCancel;

  @override
  State<_RenderDialog> createState() => _RenderDialogState();
}

class _RenderDialogState extends State<_RenderDialog> {
  final SfProgressController _progress = SfProgressController();
  String? _error;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _progress.begin('در حال آماده‌سازی موتور رندر…');
    _run();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  /// Short, true statements about the stage instead of a fake stage list.
  static String _detailFor(int percent) {
    if (percent < 5) return 'در حال آماده‌سازی موتور رندر…';
    if (percent < 92) return 'زیرنویس‌ها روی تصویر ساخته می‌شوند';
    if (percent < 100) return 'در حال نوشتن فایل ویدئو…';
    return 'پایان';
  }

  Future<void> _run() async {
    try {
      final VideoRenderResult result = await widget.task((int percent) {
        _progress.update(percent / 100, detail: _detailFor(percent));
      });
      if (!mounted) return;
      _progress.update(1, detail: 'ویدئو آماده شد');
      Navigator.of(context).pop(result);
    } on VideoRenderCancelled {
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      _progress.fail();
      setState(() {
        _error = error is VideoRenderException ? error.message : '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? error = _error;
    if (error == null) {
      return SfProgressDialog(
        title: 'در حال ساخت ویدئو…',
        caption: 'هر زیرنویس با استایل خودش رندر می‌شود',
        controller: _progress,
        icon: Icons.movie_creation_outlined,
        footnote: 'تا پایان کار برنامه را نبندید.',
        onCancel: _cancelling
            ? null
            : () async {
                setState(() => _cancelling = true);
                await widget.onCancel();
              },
      );
    }
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('ساخت ویدئو متوقف شد'),
      content: Text(error, style: const TextStyle(fontSize: 13, height: 1.9)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('باشه'),
        ),
      ],
    );
  }
}

Future<void> showRenderResultSheet(
  BuildContext context, {
  required VideoRenderResult result,
  required Future<bool> Function(String path) onShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('ویدئو ساخته شد',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(result.fileName,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Pill(icon: Icons.high_quality_outlined, label: result.resolution),
              _Pill(icon: Icons.schedule_rounded, label: result.durationLabel),
              _Pill(icon: Icons.sd_storage_outlined, label: result.sizeLabel),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primarySoft,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final bool ok = await onShare(result.path);
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('برنامه‌ای برای اشتراک‌گذاری پیدا نشد.'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('اشتراک‌گذاری', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: AppColors.outline),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('بستن'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(result.path,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.primarySoft),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
