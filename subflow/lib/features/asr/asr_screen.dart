import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/ids.dart';
import '../../database/dao/subtitle_dao.dart';
import '../../features/subtitles/subtitle_document.dart';
import '../../models/asr_provider.dart';
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
  const AsrScreen({required this.projectId, this.translate = false, super.key});

  final String projectId;

  /// Opened from the "translate" tile: speech is recognised in the source
  /// language and written out in English.
  final bool translate;

  @override
  ConsumerState<AsrScreen> createState() => _AsrScreenState();
}

class _AsrScreenState extends ConsumerState<AsrScreen> {
  String _language = 'fa';
  late bool _translate = widget.translate;
  String? _selectedPath;
  bool _running = false;
  int _progress = 0;
  String? _error;
  bool _importing = false;
  String? _downloadingId;
  AsrDownloadProgress? _download;
  bool _userCancelled = false;
  AsrProviderMode _mode = AsrProviderMode.onDevice;
  AsrCloudConfig _cloud = AsrCloudConfig.empty;

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
    final AsyncValue<AsrProviderMode> modeValue = ref.watch(asrProviderModeProvider);
    final AsyncValue<AsrCloudConfig> cloudValue = ref.watch(asrCloudConfigProvider);
    _mode = modeValue.valueOrNull ?? _mode;
    _cloud = cloudValue.valueOrNull ?? _cloud;

    return SfScaffold(
      padded: false,
      appBar: AppBar(
        leadingWidth: 56,
        title: const Text('تشخیص گفتار'),
        actions: <Widget>[
          if (_running || _downloadingId != null)
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
          _ProviderSwitch(
            mode: _mode,
            enabled: !_running && _downloadingId == null,
            onChanged: _setMode,
          ),
          const SizedBox(height: 14),
          if (_mode == AsrProviderMode.onDevice) ...<Widget>[
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
          const _SectionTitle(title: 'مدل‌های بیشتر (اختیاری)'),
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
          ],
          if (_mode == AsrProviderMode.cloud) ...<Widget>[
            if (_cloud.ready)
              _CloudCard(config: _cloud, onOpenSettings: () => context.go('/settings'))
            else
              const _CloudSetupCard(),
            const SizedBox(height: 18),
          ],
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
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Icon(Icons.translate_rounded, size: 17, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ترجمه به انگلیسی (به‌جای متن اصلی)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Switch(
                value: _translate,
                onChanged: _running ? null : (bool value) => setState(() => _translate = value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _RunCard(
            running: _running,
            progress: _progress,
            error: _error,
            detail: detail,
            enabled: _mode == AsrProviderMode.cloud
                ? _cloud.ready
                : capabilities.valueOrNull?.available == true,
            cloud: _mode == AsrProviderMode.cloud,
            onStart: _start,
            onCancel: _cancel,
          ),
          const SizedBox(height: 16),
          if (_mode == AsrProviderMode.cloud)
            const Text(
              'صدا فقط برای همان درخواست به سرویس انتخابی فرستاده می‌شود و فایل موقت '
              'بعد از پاسخ پاک می‌شود. کلید API در تنظیمات برنامه نگه داشته می‌شود و '
              'به هیچ جای دیگری نمی‌رود.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.9),
            ),
          if (_mode == AsrProviderMode.onDevice) ...<Widget>[
            const Text(
              'مدل base با کیفیت q5 همراه خود برنامه نصب می‌شود؛ نه دانلودی لازم است و نه '
              'حسابی. همهٔ پردازش روی همین دستگاه انجام می‌شود و هیچ صدایی جایی ارسال '
              'نمی‌شود. برای دقت بیشتر می‌توانید مدل small را هم اضافه کنید.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.9),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _running || _downloadingId != null ? null : _selfTest,
                icon: const Icon(Icons.medical_information_outlined, size: 16),
                label: const Text('تست کامل موتور (برای عیب‌یابی)'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setMode(AsrProviderMode mode) async {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _error = null;
      _progress = 0;
    });
    await ref.read(asrSettingsControllerProvider).setMode(mode);
  }

  Future<void> _selfTest() async {
    final ProjectDetail? project = ref.read(projectDetailProvider(widget.projectId)).valueOrNull;
    final AsrService service = ref.read(asrServiceProvider);
    setState(() => _error = null);
    Map<String, Object?> report;
    try {
      report = await service.selfTest(
        uri: project?.asset?.uri,
        modelPath: _selectedPath,
        language: _language,
        durationUs: project?.asset?.durationUs ?? 0,
      );
    } on Object catch (error) {
      report = <String, Object?>{'fatal': _humanize(error)};
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext context) => _SelfTestSheet(report: report),
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
      if (mounted && !_userCancelled) setState(() => _error = _humanize(error));
    } finally {
      _userCancelled = false;
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
    _userCancelled = true;
    await ref.read(asrServiceProvider).cancel();
    if (!mounted) return;
    setState(() {
      _running = false;
      _downloadingId = null;
      _download = null;
      _error = null;
    });
  }

  Future<void> _start() async {
    final AsrProviderMode mode = _mode;
    final AsrCloudConfig cloud = _cloud;
    // The bundled model is already installed on a fresh install, so "nothing
    // picked yet" must mean "use it", not "go find a model".
    final String? path = _selectedPath ??
        ref.read(asrModelsProvider).valueOrNull?.firstOrNull?.path;
    if (mode == AsrProviderMode.onDevice && path == null) {
      setState(() => _error = 'اول یک مدل Whisper اضافه کنید.');
      return;
    }
    if (mode == AsrProviderMode.cloud && !cloud.ready) {
      setState(() => _error = 'سرویس آنلاین تنظیم نشده است؛ در تنظیمات آدرس، مدل و کلید را وارد کنید.');
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
    final AsrResult result = mode == AsrProviderMode.cloud
        ? await service.transcribeCloud(
            uri: asset.uri,
            config: cloud,
            language: _language,
            durationUs: asset.durationUs,
            translate: _translate,
            onProgress: (int value) {
              if (mounted && _running) setState(() => _progress = value);
            },
          )
        : await service.transcribe(
            uri: asset.uri,
            modelPath: path!,
            language: _language,
            durationUs: asset.durationUs,
            translate: _translate,
            onProgress: (int value) {
              if (mounted && _running) setState(() => _progress = value);
            },
          );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _running = false;
        if (!_userCancelled) _error = result.error ?? 'تشخیص گفتار ناموفق بود.';
      });
      _userCancelled = false;
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
          if (value != null && !available && value.nativeError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'جزئیات: ${value.nativeError}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.6),
              ),
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
              'مدل همراه برنامه در دسترس نیست',
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
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              model.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (model.builtin) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'همراه برنامه',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        model.builtin
                            ? '${model.sizeLabel} • از قبل نصب است، نیازی به دانلود نیست'
                            : model.sizeLabel,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (!model.builtin)
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

/// "Where does the work happen" - the first decision on this screen.
class _ProviderSwitch extends StatelessWidget {
  const _ProviderSwitch({required this.mode, required this.enabled, required this.onChanged});

  final AsrProviderMode mode;
  final bool enabled;
  final ValueChanged<AsrProviderMode> onChanged;

  static const List<(AsrProviderMode, String, IconData)> _options =
      <(AsrProviderMode, String, IconData)>[
    (AsrProviderMode.cloud, 'آنلاین', Icons.cloud_outlined),
    (AsrProviderMode.onDevice, 'روی گوشی', Icons.smartphone_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          for (final option in _options)
            Expanded(
              child: GestureDetector(
                onTap: enabled ? () => onChanged(option.$1) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: option.$1 == mode ? AppColors.accentGradient : null,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        option.$3,
                        size: 15,
                        color: option.$1 == mode ? Colors.white : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        option.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: option.$1 == mode ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The one-time setup for the online provider, answered where the problem
/// appears instead of sending the user into a settings maze.
///
/// Online is the default on a fresh install precisely because it needs no model
/// download; the single thing standing between the user and a transcript is a
/// key, so the key is the only field that is in the way, with the free option
/// preselected and the address and model already filled in.
class _CloudSetupCard extends ConsumerStatefulWidget {
  const _CloudSetupCard();

  @override
  ConsumerState<_CloudSetupCard> createState() => _CloudSetupCardState();
}

class _CloudSetupCardState extends ConsumerState<_CloudSetupCard> {
  final TextEditingController _key = TextEditingController();
  final TextEditingController _url = TextEditingController(text: AsrCloudPreset.groq.baseUrl);
  final TextEditingController _model = TextEditingController(text: AsrCloudPreset.groq.model);

  String _preset = AsrCloudPreset.groq.id;
  bool _busy = false;
  bool _obscure = true;
  String? _status;
  bool _statusOk = false;

  @override
  void dispose() {
    _key.dispose();
    _url.dispose();
    _model.dispose();
    super.dispose();
  }

  AsrCloudConfig get _config => AsrCloudConfig(
        baseUrl: _url.text,
        model: _model.text,
        apiKey: _key.text,
        presetId: _preset,
      );

  void _applyPreset(AsrCloudPreset preset) {
    setState(() {
      _preset = preset.id;
      if (preset != AsrCloudPreset.custom) {
        _url.text = preset.baseUrl;
        _model.text = preset.model;
      }
      _status = null;
    });
  }

  Future<void> _saveAndTest() async {
    final AsrCloudConfig config = _config;
    if (config.apiKey.trim().isEmpty) {
      setState(() {
        _statusOk = false;
        _status = 'کلید API را وارد کنید.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    await ref.read(asrSettingsControllerProvider).saveCloud(config);
    final AsrCloudCheck check = await ref.read(asrServiceProvider).checkCloud(config);
    if (!mounted) return;
    final bool modelListed = check.models.isEmpty ||
        check.models.any((String name) => name.contains(config.model.trim()));
    setState(() {
      _busy = false;
      _statusOk = check.ok;
      if (!check.ok) {
        _status = check.error.isEmpty ? 'اتصال برقرار نشد.' : check.error;
      } else if (!modelListed) {
        _statusOk = false;
        _status = 'کلید درست است اما مدل «${config.model.trim()}» در این سرویس نیست.';
      } else {
        _status = 'آماده است؛ حالا دکمهٔ «شروع تشخیص گفتار» را بزنید.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.cloud_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'تشخیص گفتار آنلاین، بدون دانلود مدل',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'صدا به سرویس Whisper ارسال می‌شود و زیرنویس برمی‌گردد؛ هیچ فایل مدلی '
            'دانلود نمی‌کنید. یک کلید API لازم است و Groq کلید رایگان می‌دهد.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.9),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AsrCloudPreset.all
                .map((AsrCloudPreset preset) => _CloudPresetChip(
                      preset: preset,
                      selected: preset.id == _preset,
                      onTap: _busy ? null : () => _applyPreset(preset),
                    ))
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          if (_preset == AsrCloudPreset.custom.id) ...<Widget>[
            _CloudField(
              controller: _url,
              label: 'آدرس سرویس',
              hint: 'https://…/v1',
              enabled: !_busy,
            ),
            const SizedBox(height: 10),
            _CloudField(
              controller: _model,
              label: 'نام مدل',
              hint: 'whisper-large-v3',
              enabled: !_busy,
            ),
            const SizedBox(height: 10),
          ] else
            Text(
              '${AsrCloudPreset.byId(_preset).note} • ${AsrCloudPreset.byId(_preset).model}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.8),
            ),
          const SizedBox(height: 10),
          _CloudField(
            controller: _key,
            label: 'کلید API',
            hint: _preset == AsrCloudPreset.groq.id ? 'gsk_…' : 'sk-…',
            enabled: !_busy,
            obscure: _obscure,
            trailing: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _preset == AsrCloudPreset.groq.id
                ? 'کلید رایگان: console.groq.com/keys'
                : _preset == AsrCloudPreset.openai.id
                    ? 'کلید: platform.openai.com/api-keys'
                    : 'هر سرویس سازگار با OpenAI؛ اگر سرویس مستقیم باز نمی‌شود، آدرس پروکسی خودتان را بگذارید.',
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.9),
          ),
          const SizedBox(height: 12),
          SfPrimaryButton(
            label: _busy ? 'در حال بررسی…' : 'ذخیره و تست اتصال',
            onPressed: _busy ? null : _saveAndTest,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _status!,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.9,
                  color: _statusOk ? AppColors.success : AppColors.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CloudPresetChip extends StatelessWidget {
  const _CloudPresetChip({required this.preset, required this.selected, required this.onTap});

  final AsrCloudPreset preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.16) : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.outline),
        ),
        child: Text(
          preset.label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CloudField extends StatelessWidget {
  const _CloudField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
    this.obscure = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        suffixIcon: trailing,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Summary of the online service, with the one action that matters when it is
/// not configured yet.
class _CloudCard extends StatelessWidget {
  const _CloudCard({required this.config, required this.onOpenSettings});

  final AsrCloudConfig config;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final bool ready = config.ready;
    return SfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.cloud_done_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                config.presetId == AsrCloudPreset.custom.id
                    ? 'سرویس آنلاین'
                    : 'سرویس ${AsrCloudPreset.byId(config.presetId).label}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onOpenSettings,
                child: const Text('تنظیمات'),
              ),
            ],
          ),
          if (ready) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'مدل ${config.model} • ${config.host} • کلید ${config.maskedKey}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.9),
            ),
            const SizedBox(height: 6),
            const Text(
              'زمان‌بندی جمله‌ها را همین سرویس می‌دهد؛ کیفیت زیرنویس فارسی با مدل‌های '
              'بزرگ (large-v3) به‌طور محسوسی بهتر از مدل کوچک روی گوشی است.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.9),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 6),
            const Text(
              'برای استفاده از Whisper آنلاین، آدرس سرویس و کلید API را در تنظیمات وارد '
              'کنید. تا آن موقع دکمهٔ شروع فعال نمی‌شود.',
              style: TextStyle(fontSize: 11.5, color: AppColors.warning, height: 1.9),
            ),
          ],
        ],
      ),
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
    required this.cloud,
    required this.onStart,
    required this.onCancel,
  });

  final bool running;
  final int progress;
  final String? error;
  final AsyncValue<ProjectDetail> detail;
  final bool enabled;
  final bool cloud;
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
            Text(
              cloud
                  ? 'صدا در حال ارسال به سرویس آنلاین است؛ بسته به حجم ویدئو و سرعت '
                      'اینترنت چند دقیقه طول می‌کشد.'
                  : 'این کار روی گوشی انجام می‌شود؛ برای ویدئوی بلند چند دقیقه طول می‌کشد و '
                      'می‌توانید برنامه را باز بگذارید.',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.8),
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

/// Plain, copyable evidence of what each stage did.
class _SelfTestSheet extends StatelessWidget {
  const _SelfTestSheet({required this.report});

  final Map<String, Object?> report;

  static const Map<String, String> _labels = <String, String>{
    'nativeLib': 'کتابخانهٔ بومی',
    'nativeError': 'خطای کتابخانهٔ بومی',
    'whisperCompiled': 'موتور Whisper کامپایل شده',
    'abi': 'معماری',
    'sdkInt': 'نسخهٔ اندروید',
    'cores': 'هسته‌های CPU',
    'threads': 'رشته‌های استفاده‌شده',
    'modelPath': 'مدل',
    'modelExists': 'فایل مدل موجود',
    'modelBytes': 'حجم مدل (بایت)',
    'modelLoadMs': 'زمان بارگذاری مدل (ms)',
    'modelLoad': 'بارگذاری مدل',
    'modelError': 'خطای مدل',
    'decodeMs': 'زمان دیکد صدا (ms)',
    'samples': 'نمونه‌های صوتی',
    'audioSeconds': 'ثانیهٔ صوتی دیکدشده',
    'peak': 'بلندی صدا (۰..۱)',
    'decodeError': 'خطای دیکد',
    'transcribeMs': 'زمان تشخیص (ms)',
    'transcribeOk': 'نتیجه',
    'transcribe': 'خروجی خام',
    'fatal': 'خطای کل',
    'audio': 'صدا',
  };

  @override
  Widget build(BuildContext context) {
    final String text = report.entries
        .map((MapEntry<String, Object?> entry) =>
            '${_labels[entry.key] ?? entry.key}: ${entry.value}')
        .join('\n');
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'گزارش تست موتور',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('کپی'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.9,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
