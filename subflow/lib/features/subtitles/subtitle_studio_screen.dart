import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/time_us.dart';
import '../../database/dao/subtitle_dao.dart';
import '../../models/subtitle.dart';
import '../../models/subtitle_style.dart';
import '../../models/video_asset.dart';
import '../../services/project_repository.dart';
import '../../services/subtitle_export_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_button.dart';
import '../../shared/widgets/sf_card.dart';
import 'studio_waveform.dart';
import 'studio_widgets.dart';
import '../editor/widgets/native_player_view.dart';
import '../effects/caption_effect.dart';
import '../effects/caption_preset.dart';
import '../effects/preset_style_mapper.dart';
import '../effects/presets_library.dart';
import '../effects/caption_renderer.dart';
import 'subtitle_document.dart';
import 'subtitle_editor_model.dart';

/// The Subtitle Studio: edit captions against the real playback position, with
/// real word-level karaoke driven by `subtitle_words`.
///
/// Everything here operates on the same `CaptionPreset` the gallery renders, so
/// what the overlay shows is what the ASS export describes.
class SubtitleStudioScreen extends ConsumerStatefulWidget {
  const SubtitleStudioScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<SubtitleStudioScreen> createState() => _SubtitleStudioScreenState();
}

class _SubtitleStudioScreenState extends ConsumerState<SubtitleStudioScreen> {
  late final SfPlayerController _player = SfPlayerController.create();
  CaptionPreset _preset = PresetsLibrary.byId('viral-fa');
  SubtitleStyle? _style;
  bool _exporting = false;
  StudioTool _tool = StudioTool.style;
  bool _fullscreen = false;
  bool _rainbow = false;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadStyle() async {
    try {
      final SubtitleDao dao = await ref.read(subtitleDaoProvider.future);
      final SubtitleStyle? saved = await dao.loadProjectStyle(widget.projectId);
      if (!mounted) return;
      setState(() => _style = saved);
    } on Object {
      // A missing style row is normal on a fresh project; nothing to report.
    }
  }

  SubtitleEditorNotifier get _notifier =>
      ref.read(subtitleEditorProvider(widget.projectId).notifier);

  int get _playheadUs => _player.state.value.positionUs;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SubtitleEditorSnapshot> snapshot =
        ref.watch(subtitleEditorProvider(widget.projectId));
    final ProjectDetail? detail = ref.watch(projectDetailProvider(widget.projectId)).valueOrNull;
    final VideoAsset? asset = detail?.asset;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: snapshot.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (Object error, StackTrace stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger, height: 1.8),
              ),
            ),
          ),
          data: (SubtitleEditorSnapshot data) => _buildEditor(data, asset),
        ),
      ),
    );
  }

  Widget _buildEditor(SubtitleEditorSnapshot snapshot, VideoAsset? asset) {
    final SubtitleDocument document = snapshot.document;
    return Column(
      children: <Widget>[
        if (!_fullscreen)
          StudioTopBar(
            title: 'ویرایش زیرنویس',
            exporting: _exporting,
            onBack: () => context.pop(),
            onExport: snapshot.document.isEmpty || _exporting
                ? null
                : () => _exportDialog(snapshot, asset),
          ),
        Expanded(
          child: asset == null
              ? _noAssetState()
              : Column(
                  children: <Widget>[
                    Flexible(flex: 5, child: _stage(snapshot, asset)),
                    if (!_fullscreen)
                      Flexible(
                        flex: 6,
                        child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _transport(snapshot),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                              child: StudioTimeline(
                                segments: document.segments,
                                durationUs: _player.state.value.durationUs,
                                positionUs: _player.state.value.positionUs,
                                onSeek: _player.seekTo,
                                onBlockTap: (SubtitleSegment segment) =>
                                    _openSegmentSheet(segment.id),
                                waveform: _waveform(asset),
                                strip: Filmstrip(uri: asset.uri, durationUs: asset.durationUs),
                              ),
                            ),
                            const SizedBox(height: 10),
                            StudioToolRow(tool: _tool, onSelect: _selectTool),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 208,
                              child: SingleChildScrollView(child: _panel(snapshot, asset)),
                            ),
                          ],
                        ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _stage(SubtitleEditorSnapshot snapshot, VideoAsset asset) {
    return ValueListenableBuilder<SfPlayerState>(
      valueListenable: _player.state,
      builder: (BuildContext context, SfPlayerState state, Widget? child) {
        final SubtitleDocument document = snapshot.document;
        final int position = state.positionUs;
        final int? index = document.indexAt(position);
        final SubtitleSegment? segment = index == null ? null : document.segments[index];
        final int activeWord =
            segment == null ? -1 : (document.wordIndexAt(segment.id, position) ?? -1);
        final List<double> fills = segment == null
            ? const <double>[]
            : segment.words
                .map((SubtitleWord word) => word.endUs <= position
                    ? 1.0
                    : (position <= word.startUs
                        ? 0.0
                        : ((position - word.startUs) / (word.endUs - word.startUs))
                            .clamp(0.0, 1.0)
                            .toDouble()))
                .toList(growable: false);
        return CaptionStage(
          hasCaption: segment != null,
          onTap: () => state.isPlaying ? _player.pause() : _player.play(),
          player: NativeVideoPlayer(uri: asset.uri, controller: _player),
          caption: CaptionSurface(
            preset: _preset,
            text: segment?.text ?? '',
            activeWord: activeWord,
            wordFills: fills,
            minFontSize: 9,
          ),
        );
      },
    );
  }

  Widget _transport(SubtitleEditorSnapshot snapshot) {
    return ValueListenableBuilder<SfPlayerState>(
      valueListenable: _player.state,
      builder: (BuildContext context, SfPlayerState state, Widget? child) {
        return StudioTransportRow(
          playing: state.isPlaying,
          positionUs: state.positionUs,
          durationUs: state.durationUs,
          onPlayPause: () => state.isPlaying ? _player.pause() : _player.play(),
          canUndo: snapshot.canUndo,
          canRedo: snapshot.canRedo,
          onUndo: _notifier.undo,
          onRedo: _notifier.redo,
          onFullscreen: () => setState(() => _fullscreen = !_fullscreen),
        );
      },
    );
  }

  List<int> _waveform(VideoAsset asset) {
    final AsyncValue<List<int>> values =
        ref.watch(waveformProvider(WaveformRequest(uri: asset.uri, durationUs: asset.durationUs)));
    return values.valueOrNull ?? const <int>[];
  }

  void _selectTool(StudioTool tool) {
    if (tool == StudioTool.more) {
      _openMoreSheet();
      return;
    }
    setState(() => _tool = tool);
  }

  Widget _panel(SubtitleEditorSnapshot snapshot, VideoAsset? asset) {
    switch (_tool) {
      case StudioTool.style:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _panelLabel('استایل'),
            const SizedBox(height: 4),
            StudioPresetRow(
              presets: _faPresets,
              currentId: _preset.id,
              onPick: _applyPreset,
            ),
            const SizedBox(height: 8),
            _panelLabel('رنگ'),
            const SizedBox(height: 4),
            StudioColorRow(current: _preset.textColor, onPick: _applyColor, rainbowSelected: _rainbow),
            const SizedBox(height: 6),
            _panelLabel('جایگاه'),
            const SizedBox(height: 6),
            _positionRow(),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _pickStyle,
              icon: const Icon(Icons.grid_view_rounded, size: 16),
              label: const Text('گالری کامل استایل‌ها و افکت‌ها'),
            ),
          ],
        );
      case StudioTool.color:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _panelLabel('رنگ متن'),
            const SizedBox(height: 6),
            StudioColorRow(current: _preset.textColor, onPick: _applyColor, rainbowSelected: _rainbow),
            const SizedBox(height: 10),
            _panelLabel('رنگ تأکید کلمه'),
            const SizedBox(height: 6),
            StudioColorRow(current: _preset.accentColor, onPick: _applyAccent),
          ],
        );
      case StudioTool.animation:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _panelLabel('انیمیشن ورود'),
            const SizedBox(height: 6),
            _animationRow(),
            const SizedBox(height: 10),
            _panelLabel('افکت کلمه'),
            const SizedBox(height: 6),
            _wordEffectRow(),
          ],
        );
      case StudioTool.position:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _panelLabel('جایگاه زیرنویس'),
            const SizedBox(height: 8),
            _positionRow(),
            const SizedBox(height: 12),
            _panelLabel('عرض کپشن'),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (final (double value, String label) in <(double, String)>[
                  (0.7, 'باریک'),
                  (0.88, 'معمولی'),
                  (1.0, 'کامل'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _chipButton(
                      label,
                      selected: (_preset.widthFraction - value).abs() < 0.02,
                      onTap: () => _applyPreset(_preset.copyWith(widthFraction: value)),
                    ),
                  ),
              ],
            ),
          ],
        );
      case StudioTool.more:
        return const SizedBox.shrink();
    }
  }

  Widget _panelLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      );

  List<CaptionPreset> get _faPresets {
    final List<CaptionPreset> persian =
        PresetsLibrary.all.where((CaptionPreset p) => p.language == 'fa').toList(growable: false);
    return persian.isEmpty ? PresetsLibrary.all.take(10).toList(growable: false) : persian.take(12).toList(growable: false);
  }

  Widget _positionRow() {
    return Row(
      children: <Widget>[
        for (final (double value, String label) in <(double, String)>[
          (0.14, 'بالا'),
          (0.5, 'وسط'),
          (0.82, 'پایین'),
        ])
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _chipButton(
              label,
              selected: (_preset.positionY - value).abs() < 0.06,
              onTap: () => _applyPreset(_preset.copyWith(positionY: value)),
            ),
          ),
      ],
    );
  }

  Widget _animationRow() {
    const List<(CaptionAnimation, String)> options = <(CaptionAnimation, String)>[
      (CaptionAnimation.fade, 'محو'),
      (CaptionAnimation.slideUp, 'از پایین'),
      (CaptionAnimation.zoomIn, 'بزرگ‌شدن'),
      (CaptionAnimation.pop, 'پاپ'),
      (CaptionAnimation.bounce, 'پرش'),
      (CaptionAnimation.blurIn, 'بلور'),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final (CaptionAnimation animation, String label) in options)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _chipButton(
                label,
                selected: _preset.effects.enter == animation,
                onTap: () => _applyPreset(
                  _preset.copyWith(effects: _preset.effects.copyWith(enter: animation)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _wordEffectRow() {
    const List<(CaptionWordEffect, String)> options = <(CaptionWordEffect, String)>[
      (CaptionWordEffect.karaokeFill, 'کاراوکه'),
      (CaptionWordEffect.activeColor, 'رنگ کلمه'),
      (CaptionWordEffect.activeScale, 'بزرگ‌شدن'),
      (CaptionWordEffect.wordPop, 'پاپ'),
      (CaptionWordEffect.activeBackground, 'پس‌زمینه'),
      (CaptionWordEffect.none, 'بدون'),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final (CaptionWordEffect effect, String label) in options)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _chipButton(
                label,
                selected: _preset.effects.wordEffect == effect,
                onTap: () => _applyPreset(
                  _preset.copyWith(effects: _preset.effects.copyWith(wordEffect: effect)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipButton(String label, {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.18) : AppColors.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? AppColors.primary : AppColors.outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primarySoft : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _applyColor(int color) {
    if (color == 0) return;
    setState(() => _rainbow = color == -1);
    if (color == -1) {
      // A gradient caption: white core with a blue-violet tail, which is what the
      // rainbow swatch promises.
      _applyPreset(_preset.copyWith(textColor: 0xFFFFFF, gradientEnd: 0x5B8CFF));
      return;
    }
    _applyPreset(_preset.copyWith(textColor: color, clearGradient: true));
  }

  void _applyAccent(int color) {
    if (color == 0 || color == -1) return;
    _applyPreset(_preset.copyWith(accentColor: color));
  }

  Future<void> _applyPreset(CaptionPreset preset) async {
    final SubtitleStyle style = PresetStyleMapper.toStyle(
      preset,
      id: 'style-${widget.projectId}',
      projectId: widget.projectId,
    );
    await _notifier.applyStyle(style);
    if (!mounted) return;
    setState(() {
      _preset = preset;
      _style = style;
    });
  }

  void _openMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _SheetAction(
              icon: Icons.add_rounded,
              label: 'افزودن زیرنویس در این لحظه',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _notifier.insertAt(_playheadUs);
              },
            ),
            _SheetAction(
              icon: Icons.list_alt_rounded,
              label: 'فهرست متن‌ها',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openSegmentsSheet();
              },
            ),
            _SheetAction(
              icon: Icons.copy_all_rounded,
              label: 'کپی استایل',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _notifier.copyStyle();
              },
            ),
            _SheetAction(
              icon: Icons.timer_outlined,
              label: 'جابه‌جایی کل زیرنویس',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _shiftAllDialog();
              },
            ),
            _SheetAction(
              icon: Icons.graphic_eq_rounded,
              label: 'تشخیص گفتار',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/project/${widget.projectId}/asr');
              },
            ),
            _SheetAction(
              icon: Icons.tune_rounded,
              label: 'تنظیمات پروژه',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/project/${widget.projectId}');
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openSegmentsSheet() {
    final SubtitleEditorSnapshot? snapshot =
        ref.read(subtitleEditorProvider(widget.projectId)).valueOrNull;
    if (snapshot == null) return;
    final SubtitleDocument document = snapshot.document;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            itemCount: document.segments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) => _SegmentTile(
              segment: document.segments[index],
              index: index,
              selected: false,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openSegmentSheet(document.segments[index].id);
              },
              onSplit: () => _notifier.split(document.segments[index].id, _playheadUs),
              onMerge: () => _notifier.mergeWithNext(document.segments[index].id),
              onDelete: () => _confirmDelete(document.segments[index]),
            ),
          ),
        ),
      ),
    );
  }

  /// The project's video is gone (moved or deleted): say so, and offer the one
  /// action that helps.
  Widget _noAssetState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SfCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.videocam_off_outlined, size: 30, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'ویدئوی این پروژه در دسترس نیست',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'فایل از حافظهٔ گوشی پاک یا جابه‌جا شده است. برای دیدن و ویرایش زیرنویس، فایل '
                'را دوباره وارد کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStyle() async {
    final CaptionPreset? picked = await context.push<CaptionPreset>('/captions');
    if (picked == null || !mounted) return;
    final SubtitleStyle style = PresetStyleMapper.toStyle(
      picked,
      id: 'style-${widget.projectId}',
      projectId: widget.projectId,
    );
    await _notifier.applyStyle(style);
    if (!mounted) return;
    setState(() {
      _preset = picked;
      _style = style;
    });
  }

  Future<void> _openSegmentSheet(String segmentId) async {
    _notifier.select(segmentId);
    final SubtitleEditorSnapshot? snapshot =
        ref.read(subtitleEditorProvider(widget.projectId)).valueOrNull;
    final SubtitleSegment? segment = snapshot?.document.byId(segmentId);
    if (segment == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => _SegmentEditorSheet(
        segment: segment,
        playheadUs: _playheadUs,
        onText: (String text) => _notifier.setText(segmentId, text),
        onTiming: (int startUs, int endUs) =>
            _notifier.retime(segmentId, startUs: startUs, endUs: endUs),
        onSplit: () => _notifier.split(segmentId, _playheadUs),
        onMerge: () => _notifier.mergeWithNext(segmentId),
        onDelete: () {
          _notifier.remove(segmentId);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _confirmDelete(SubtitleSegment segment) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف این زیرنویس؟'),
        content: Text(
          '"${segment.text.isEmpty ? 'بدون متن' : segment.text}" حذف می‌شود. با «واگرد» قابل بازگشت است.',
          style: const TextStyle(height: 1.8),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) _notifier.remove(segment.id);
  }

  Future<void> _shiftAllDialog() async {
    final TextEditingController controller = TextEditingController(text: '0');
    final int? deltaMs = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('جابه‌جایی کل زیرنویس'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: const InputDecoration(
            labelText: 'میلی‌ثانیه (مثبت یا منفی)',
            helperText: 'برای همگام‌سازی وقتی صدا کمی جلو/عقب است.',
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text.trim()) ?? 0),
            child: const Text('اعمال'),
          ),
        ],
      ),
    );
    if (deltaMs != null && deltaMs != 0) {
      _notifier.shiftAll(TimeUs.fromMilliseconds(deltaMs));
    }
  }

  Future<void> _exportDialog(SubtitleEditorSnapshot snapshot, VideoAsset? asset) async {
    final String? format = await showModalBottomSheet<String>(
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
            Text('خروجی زیرنویس', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'فایل ویدئوی اصلی دست‌نخورده می‌ماند؛ فقط فایل متن ساخته می‌شود (حالت اول خروجی).',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.8),
            ),
            const SizedBox(height: 16),
            _FormatTile(
              title: 'SRT',
              subtitle: 'همه‌جا باز می‌شود، بدون استایل',
              onTap: () => Navigator.of(context).pop('srt'),
            ),
            _FormatTile(
              title: 'ASS',
              subtitle: 'با فونت، رنگ، دورخط و موقعیت همین استایل',
              onTap: () => Navigator.of(context).pop('ass'),
            ),
            _FormatTile(
              title: 'TXT',
              subtitle: 'متن ساده و بدون زمان‌بندی (برای زیرنویس‌گذاری دستی)',
              onTap: () => Navigator.of(context).pop('txt'),
            ),
          ],
        ),
      ),
    );
    if (format == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      await _notifier.flush();
      final SubtitleExportService service = ref.read(subtitleExportServiceProvider);
      final SubtitleDocument document =
          ref.read(subtitleEditorProvider(widget.projectId)).valueOrNull?.document ?? snapshot.document;
      final int idLength = widget.projectId.length < 8 ? widget.projectId.length : 8;
      final String baseName = 'subflow-${widget.projectId.substring(0, idLength)}';
      final ExportedSubtitle result;
      if (format == 'srt') {
        result = await service.exportSrt(document, baseName: baseName);
      } else if (format == 'ass') {
        final int width = asset?.width ?? 1080;
        final int height = asset?.height ?? 1920;
        result = await service.exportAss(
          document,
          videoWidth: width,
          videoHeight: height,
          fontName: _style?.fontFamily ?? _preset.fontFamily,
          fontSize: PresetStyleMapper.fontSizeFor(_preset, width, height),
          primaryColor: _style?.textColor ?? _preset.textColor,
          outlineColor: _style?.strokeColor ?? _preset.strokeColor,
          outlineWidth: _style?.strokeWidth ?? _preset.strokeWidth,
          shadowDepth: _style?.shadowOffsetY ?? _preset.shadowOffsetY,
          bold: _preset.fontWeight >= 700,
          alignment: PresetStyleMapper.alignmentFor(_preset.positionY),
          baseName: baseName,
        );
      } else {
        result = await service.exportTxt(document, baseName: baseName);
      }
      if (!mounted) return;
      await _showExportResult(result);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خروجی ناموفق بود: $error'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _showExportResult(ExportedSubtitle result) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('فایل ساخته شد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${result.segmentCount} زیرنویس در قالب ${result.format.toUpperCase()}',
                style: const TextStyle(fontSize: 13, height: 1.8)),
            const SizedBox(height: 8),
            Text('${(result.bytes / 1024).toStringAsFixed(1)} کیلوبایت',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            SelectableText(
              result.path,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('باشه')),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 16,
                  color: enabled ? AppColors.primarySoft : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.segment,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onSplit,
    required this.onMerge,
    required this.onDelete,
  });

  final SubtitleSegment segment;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSplit;
  final VoidCallback onMerge;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final int words = segment.words.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceHigher : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : AppColors.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text('${index + 1}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${TimeUs.precise(segment.startUs)} → ${TimeUs.precise(segment.endUs)}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (words > 0)
                      Text('• $words کلمه',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    if (segment.styleId != null) ...<Widget>[
                      const SizedBox(width: 6),
                      const Icon(Icons.brush_rounded, size: 12, color: AppColors.primarySoft),
                    ],
                    const Spacer(),
                    IconButton(
                      onPressed: onSplit,
                      tooltip: 'برش در نقطه پخش',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.content_cut_rounded, size: 17),
                    ),
                    IconButton(
                      onPressed: onMerge,
                      tooltip: 'ادغام با بعدی',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.merge_rounded, size: 17),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      tooltip: 'حذف',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 17, color: AppColors.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  segment.text.isEmpty ? '— بدون متن —' : segment.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.7,
                    color: segment.text.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Draft-based editor for one caption: the text/timing are only written back on
/// "apply", so a whole manual edit is a single undo step instead of one per
/// keystroke.
class _SegmentEditorSheet extends StatefulWidget {
  const _SegmentEditorSheet({
    required this.segment,
    required this.playheadUs,
    required this.onText,
    required this.onTiming,
    required this.onSplit,
    required this.onMerge,
    required this.onDelete,
  });

  final SubtitleSegment segment;
  final int playheadUs;
  final ValueChanged<String> onText;
  final void Function(int startUs, int endUs) onTiming;
  final VoidCallback onSplit;
  final VoidCallback onMerge;
  final VoidCallback onDelete;

  @override
  State<_SegmentEditorSheet> createState() => _SegmentEditorSheetState();
}

class _SegmentEditorSheetState extends State<_SegmentEditorSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.segment.text);
  late final TextEditingController _start =
      TextEditingController(text: TimeUs.toSeconds(widget.segment.startUs).toStringAsFixed(3));
  late final TextEditingController _end =
      TextEditingController(text: TimeUs.toSeconds(widget.segment.endUs).toStringAsFixed(3));
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _apply() {
    final double? startSeconds = double.tryParse(_start.text.trim());
    final double? endSeconds = double.tryParse(_end.text.trim());
    if (startSeconds == null || endSeconds == null) {
      setState(() => _error = 'زمان‌ها را به ثانیه وارد کن، مثلاً 12.500');
      return;
    }
    final int startUs = TimeUs.fromSeconds(startSeconds);
    final int endUs = TimeUs.fromSeconds(endSeconds);
    if (endUs - startUs < SubtitleDocument.minSegmentUs) {
      setState(() => _error = 'پایان باید حداقل 0.12 ثانیه بعد از شروع باشد.');
      return;
    }
    widget.onText(_text.text);
    widget.onTiming(startUs, endUs);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.outline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('ویرایش زیرنویس', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              maxLines: 4,
              minLines: 2,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.start,
              decoration: const InputDecoration(
                labelText: 'متن (چندخطی مجاز است)',
                helperText: 'نیم‌فاصله و علائم فارسی حفظ می‌شوند.',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(child: _timeField(_start, 'شروع (ثانیه)')),
                const SizedBox(width: 10),
                Expanded(child: _timeField(_end, 'پایان (ثانیه)')),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () {
                    _end.text = TimeUs.toSeconds(widget.playheadUs).toStringAsFixed(3);
                    setState(() {});
                  },
                  icon: const Icon(Icons.south_rounded, size: 16),
                  label: const Text('پایان = پخش'),
                ),
                TextButton.icon(
                  onPressed: () {
                    _start.text = TimeUs.toSeconds(widget.playheadUs).toStringAsFixed(3);
                    setState(() {});
                  },
                  icon: const Icon(Icons.north_rounded, size: 16),
                  label: const Text('شروع = پخش'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _SheetAction(
                  icon: Icons.content_cut_rounded,
                  label: 'برش در پخش',
                  onTap: () {
                    widget.onSplit();
                    Navigator.of(context).pop();
                  },
                ),
                _SheetAction(
                  icon: Icons.merge_rounded,
                  label: 'ادغام با بعدی',
                  onTap: () {
                    widget.onMerge();
                    Navigator.of(context).pop();
                  },
                ),
                _SheetAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف',
                  danger: true,
                  onTap: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SfPrimaryButton(
                label: 'اعمال تغییرات',
                icon: Icons.check_rounded,
                onPressed: _apply,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color tint = danger ? AppColors.danger : AppColors.textSecondary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: tint),
      label: Text(label, style: TextStyle(fontSize: 12, color: tint)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: danger ? AppColors.danger : AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
