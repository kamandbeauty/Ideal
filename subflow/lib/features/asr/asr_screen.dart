import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/ids.dart';
import '../../database/dao/subtitle_dao.dart';
import '../../features/subtitles/subtitle_document.dart';
import '../../models/enums.dart';
import '../../models/subtitle.dart';
import '../../models/video_asset.dart';
import '../../services/asr_service.dart';
import '../../services/project_repository.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_button.dart';
import '../../shared/widgets/sf_card.dart';
import '../../shared/widgets/sf_scaffold.dart';

/// Offline speech recognition with whisper.cpp.
///
/// The screen is deliberately honest about the two things that decide whether it
/// works: an engine that is actually compiled into the APK, and a ggml model the
/// user supplied. Both are reported up front; nothing pretends to transcribe.
class AsrScreen extends ConsumerStatefulWidget {
  const AsrScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<AsrScreen> createState() => _AsrScreenState();
}

class _AsrScreenState extends ConsumerState<AsrScreen> {
  String _language = 'auto';
  String? _selectedPath;
  bool _running = false;
  int _progress = 0;
  String? _error;
  bool _importing = false;
  String? _downloadingId;
  AsrDownloadProgress? _download;

  static const List<Map<String, String>> _languages = <Map<String, String>>[
    <String, String>{'code': 'auto', 'label': 'تشخیص خودکار'},
    <String, String>{'code': 'fa', 'label': 'فارسی'},
    <String, String>{'code': 'en', 'label': 'English'},
  ];

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AsrCapabilities> capabilities = ref.watch(asrCapabilitiesProvider);
    final AsyncValue<List<AsrModel>> models = ref.watch(asrModelsProvider);
    final AsyncValue<ProjectDetail> detail = ref.watch(projectDetailProvider(widget.projectId));

    return SfScaffold(
      padded: false,
      appBar: AppBar(
        leadingWidth: 56,
        title: const Text('تشخیص گفتار'),
        actions: <Widget>[
          if (_running)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: TextButton(
                onPressed: _cancel,
                child: const Text('لغو', style: TextStyle(color: AppColors.danger)),
              ),
            ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: <Widget>[
          _EngineCard(capabilities: capabilities),
          const SizedBox(height: 14),
          _SectionTitle(
            title: 'مدل Whisper',
            trailing: TextButton.icon(
              onPressed: _importing ? null : _importModel,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('افزودن مدل'),
            ),
          ),
          models.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (Object error, StackTrace stack) => _ErrorCard(message: '$error'),
            data: (List<AsrModel> list) => _ModelList(
              models: list,
              selectedPath: _selectedPath ?? (list.isEmpty ? null : list.first.path),
              onSelect: (AsrModel model) => setState(() => _selectedPath = model.path),
              onDelete: _running ? null : _deleteModel,
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'دریافت مدل (یک‌بار، بعد آفلاین)'),
          const SizedBox(height: 4),
          const Text(
            'فایل مدل در خود برنامه نیست چون از ۳۲ مگابایت تا چند گیگابایت است؛ '
            'با یک ضربه دانلود می‌شود، بررسی می‌شود و بعد بدون اینترنت کار می‌کند.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.8),
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final AsyncValue<List<AsrCatalogEntry>> catalog = ref.watch(asrCatalogProvider);
              return catalog.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (Object error, StackTrace stack) => _ErrorCard(message: '$error'),
                data: (List<AsrCatalogEntry> entries) => Column(
                  children: entries
                      .map((AsrCatalogEntry entry) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _CatalogTile(
                              entry: entry,
                              busy: _downloadingId == entry.id,
                              progress: _downloadingId == entry.id ? _download : null,
                              onDownload: _running || _downloadingId != null
                                  ? null
                                  : () => _downloadModel(entry),
                            ),
                          ))
                      .toList(growable: false),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'زبان گفتار'),
          const SizedBox(height: 8),
          Row(
            children: _languages.map((Map<String, String> language) {
              final bool selected = language['code'] == _language;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: _running ? null : () => setState(() => _language = language['code']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: selected ? AppColors.accentGradient : null,
                      color: selected ? null : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: selected ? Colors.transparent : AppColors.outline),
                    ),
                    child: Text(
                      language['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 18),
          _RunCard(
            running: _running,
            progress: _progress,
            error: _error,
            detail: detail,
            enabled: capabilities.valueOrNull?.available == true,
            onStart: _start,
            onCancel: _cancel,
          ),
          const SizedBox(height: 16),
          const Text(
            'مدلها فایل‌های ggml هستند و در خود برنامه نیستند: حجمشان از ۷۵ مگابایت '
            '(tiny) تا چند گیگابایت است. برای فارسی، base یا small با کیفیت q5 بهترین '
            'تعادل حجم و دقت روی گوشی است. همهٔ پردازش روی همین دستگاه انجام می‌شود و '
            'هیچ صدایی جایی ارسال نمی‌شود.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.9),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadModel(AsrCatalogEntry entry) async {
    setState(() {
      _downloadingId = entry.id;
      _download = AsrDownloadProgress(id: entry.id, received: 0, total: entry.approxBytes);
      _error = null;
    });
    try {
      final AsrModel? model = await ref.read(asrModelsProvider.notifier).download(
        entry.id,
        onProgress: (AsrDownloadProgress progress) {
          if (mounted) setState(() => _download = progress);
        },
      );
      if (!mounted) return;
      if (model != null) {
        setState(() => _selectedPath = model.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('مدل ${model.label} آماده است.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = _humanize(error));
    } finally {
      if (mounted) {
        setState(() {
          _downloadingId = null;
          _download = null;
        });
      }
    }
  }

  Future<void> _importModel() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final AsrModel? model = await ref.read(asrModelsProvider.notifier).importModel();
      if (!mounted) return;
      if (model != null) setState(() => _selectedPath = model.path);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _humanize(error));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deleteModel(AsrModel model) async {
    await ref.read(asrModelsProvider.notifier).delete(model.path);
    if (!mounted) return;
    if (_selectedPath == model.path) setState(() => _selectedPath = null);
  }

  Future<void> _cancel() async {
    await ref.read(asrServiceProvider).cancel();
    if (!mounted) return;
    setState(() {
      _running = false;
      _error = null;
    });
  }

  Future<void> _start() async {
    final String? path = _selectedPath;
    if (path == null) {
      setState(() => _error = 'اول یک مدل Whisper اضافه کنید.');
      return;
    }
    final ProjectDetail? project = ref.read(projectDetailProvider(widget.projectId)).valueOrNull;
    final VideoAsset? asset = project?.asset;
    if (asset == null) {
      setState(() => _error = 'ویدئوی این پروژه پیدا نشد.');
      return;
    }
    setState(() {
      _running = true;
      _progress = 0;
      _error = null;
    });
    final AsrService service = ref.read(asrServiceProvider);
    final AsrResult result = await service.transcribe(
      uri: asset.uri,
      modelPath: path,
      language: _language,
      durationUs: asset.durationUs,
      onProgress: (int value) {
        if (mounted && _running) setState(() => _progress = value);
      },
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _running = false;
        _error = result.error ?? 'تشخیص گفتار ناموفق بود.';
      });
      return;
    }
    try {
      final int count = await _persist(result.segments);
      if (!mounted) return;
      setState(() {
        _running = false;
        _progress = 100;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count زیرنویس ساخته شد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.push('/project/${widget.projectId}/subtitles');
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = _humanize(error);
        });
      }
    }
  }

  /// Writes the transcript into the project's original track.
  ///
  /// The document, not this method, owns validity: it sorts, keeps captions from
  /// overlapping and spreads per-word timings, so the studio opens on a document
  /// it can retime immediately.
  Future<int> _persist(List<AsrSegmentData> segments) async {
    final SubtitleDao dao = await ref.read(subtitleDaoProvider.future);
    final SubtitleLanguage language = switch (_language) {
      'fa' => SubtitleLanguage.fa,
      'en' => SubtitleLanguage.en,
      _ => SubtitleLanguage.auto,
    };
    final SubtitleTrack track = await dao.ensureOriginalTrack(widget.projectId, language: language);
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, String> texts = <String, String>{};
    SubtitleDocument document = SubtitleDocument(
      trackId: track.id,
      segments: segments.map((AsrSegmentData segment) {
        final String id = Ids.uuid();
        texts[id] = segment.text;
        return SubtitleSegment(
          id: id,
          trackId: track.id,
          ordinal: 0,
          startUs: segment.startUs,
          endUs: segment.endUs,
          text: '',
          source: SubtitleSource.whisper,
          createdAtMs: now,
          updatedAtMs: now,
        );
      }).toList(growable: false),
    );
    for (final SubtitleSegment segment in document.segments) {
      final String? text = texts[segment.id];
      if (text != null) document = document.withText(segment.id, text);
    }
    await dao.replaceSegments(track.id, document.segments);
    ref.invalidate(subtitleEditorProvider(widget.projectId));
    ref.invalidate(projectDetailProvider(widget.projectId));
    return document.segments.length;
  }

  String _humanize(Object error) {
    final String raw = error is PlatformException ? (error.message ?? error.code) : '$error';
    return raw.replaceFirst('Exception: ', '');
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _EngineCard extends StatelessWidget {
  const _EngineCard({required this.capabilities});

  final AsyncValue<AsrCapabilities> capabilities;

  @override
  Widget build(BuildContext context) {
    final AsrCapabilities? value = capabilities.valueOrNull;
    final bool available = value?.available == true;
    final Color accent = available ? AppColors.success : AppColors.warning;
    return SfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Whisper — کاملاً آفلاین',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'صدا روی گوشی به متن تبدیل می‌شود؛ هیچ بایتی به شبکه نمی‌رود.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.7),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withOpacity(0.35)),
                ),
                child: Text(
                  capabilities.isLoading
                      ? 'بررسی موتور…'
                      : available
                          ? 'موتور Whisper فعال است'
                          : 'موتور Whisper در این نسخه نیست',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent),
                ),
              ),
              const Spacer(),
              if (value != null && value.cores > 0)
                Text(
                  '${value.cores} هسته • ${value.recommendedThreads} رشته',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SfCard(
      padding: const EdgeInsets.all(14),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.7),
      ),
    );
  }
}

class _ModelList extends StatelessWidget {
  const _ModelList({
    required this.models,
    required this.selectedPath,
    required this.onSelect,
    required this.onDelete,
  });

  final List<AsrModel> models;
  final String? selectedPath;
  final ValueChanged<AsrModel> onSelect;
  final ValueChanged<AsrModel>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) {
      return SfCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Text(
              'هنوز مدلی اضافه نشده است',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'فایل ggml (مثل ggml-base.bin یا ggml-small-q5_1.bin) را از حافظهٔ گوشی '
              'انتخاب کنید. برنامه آن را یک‌بار کپی و بررسی می‌کند و بعد کاملاً آفلاین کار می‌کند.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.9),
            ),
          ],
        ),
      );
    }
    return Column(
      children: models.map((AsrModel model) {
        final bool selected = model.path == selectedPath;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => onSelect(model),
            child: Row(
              children: <Widget>[
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        model.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        model.sizeLabel,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete == null ? null : () => onDelete!(model),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.textMuted,
                  tooltip: 'حذف مدل',
                ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({
    required this.running,
    required this.progress,
    required this.error,
    required this.detail,
    required this.enabled,
    required this.onStart,
    required this.onCancel,
  });

  final bool running;
  final int progress;
  final String? error;
  final AsyncValue<ProjectDetail> detail;
  final bool enabled;
  final VoidCallback onStart;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final bool mediaReady = detail.valueOrNull?.mediaAvailable ?? false;
    return SfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (running) ...<Widget>[
            Row(
              children: <Widget>[
                Text(
                  'در حال تشخیص… $progress٪',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('لغو', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress <= 0 ? null : progress / 100,
                minHeight: 7,
                backgroundColor: AppColors.surfaceHigher,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'این کار روی گوشی انجام می‌شود؛ برای ویدئوی بلند چند دقیقه طول می‌کشد و '
              'می‌توانید برنامه را باز بگذارید.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.8),
            ),
          ] else ...<Widget>[
            if (error != null) ...<Widget>[
              Text(
                error!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.8),
              ),
              const SizedBox(height: 10),
            ],
            if (!mediaReady)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'فایل ویدئوی این پروژه در دسترس نیست؛ دوباره واردش کنید.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.warning, height: 1.8),
                ),
              ),
            SfPrimaryButton(
              label: 'شروع تشخیص گفتار',
              icon: Icons.auto_awesome_rounded,
              onPressed: enabled ? onStart : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.entry,
    required this.busy,
    required this.progress,
    required this.onDownload,
  });

  final AsrCatalogEntry entry;
  final bool busy;
  final AsrDownloadProgress? progress;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return SfCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                entry.installed ? Icons.download_done_rounded : Icons.cloud_download_outlined,
                size: 18,
                color: entry.installed ? AppColors.success : AppColors.secondarySoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.installed ? 'نصب شده • ${entry.sizeLabel}' : entry.detail,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.6),
                    ),
                  ],
                ),
              ),
              if (!entry.installed)
                TextButton(
                  onPressed: busy ? null : onDownload,
                  child: Text(busy ? '…' : 'دریافت'),
                )
              else
                const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
            ],
          ),
          if (busy) ...<Widget>[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress == null || progress!.fraction == 0 ? null : progress!.fraction,
                minHeight: 6,
                backgroundColor: AppColors.surfaceHigher,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress == null ? 'در حال دریافت…' : '${progress!.label} • ${(progress!.fraction * 100).round()}٪',
              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
