/// Export progress + completion, wired to the native renderer.
///
/// The screen is honest about failure: when the native engine is missing it
/// reports BLOCKED and never shows a fake "done" state. A cancelled or failed
/// export leaves no usable partial file behind (the manager deletes it).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../app/l10n/strings.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/ratio_utils.dart';
import '../export/export_manager.dart';
import '../platform/native_video_bridge/video_bridge.dart';
import '../project/project_editor_controller.dart';

class ExportProgressScreen extends ConsumerStatefulWidget {
  const ExportProgressScreen({super.key});

  @override
  ConsumerState<ExportProgressScreen> createState() =>
      _ExportProgressScreenState();
}

class _ExportProgressScreenState extends ConsumerState<ExportProgressScreen> {
  ExportJobState _job = const ExportJobState();
  StreamSubscription<ExportJobState>? _sub;
  AppFailure? _failure;
  bool _blocked = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    final manager = ref.read(exportManagerProvider);
    _sub = manager.states.listen((ExportJobState s) {
      if (!mounted) return;
      setState(() => _job = s);
    });

    final st = ref.read(projectEditorProvider);
    if (st == null) {
      if (mounted) context.go(AppRoutes.home);
      return;
    }
    final project = st.project;
    final settings = project.exportSettings;
    final dims = settings.dimensions(project.firstPhotoAspect);
    try {
      final result = await manager.start(
        project: project,
        width: dims.width,
        height: dims.height,
        fps: settings.fps.value,
        codec: settings.codec.id,
        bitrate: settings.bitrateFor(dims.width, dims.height),
      );
      if (!mounted) return;
      setState(() => _job = _job.copyWith(
            result: result,
            stage: ExportStage.done,
            progress: 1,
            isRunning: false,
          ));
      // Save the project so the run is reproducible later.
      await ref.read(projectEditorProvider.notifier).save();
    } on ExportBlocked catch (e) {
      if (!mounted) return;
      setState(() {
        _blocked = true;
        _job = _job.copyWith(isRunning: false);
      });
      debugPrint('export blocked: ${e.reason}');
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = e;
        _job = _job.copyWith(isRunning: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = AppFailure(FailureKind.unknown, technicalDetail: '$e');
        _job = _job.copyWith(isRunning: false);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _job.result;

    Widget body;
    if (_blocked) {
      body = _blockedView(context, l10n);
    } else if (_failure != null) {
      body = _failureView(context, l10n, _failure!);
    } else if (result != null) {
      body = _completeView(context, l10n, result);
    } else {
      body = _progressView(context, l10n);
    }

    return PopScope(
      canPop: !_job.isRunning,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        await ref.read(exportManagerProvider).cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t(result != null
              ? 'export_complete'
              : _failure != null
                  ? 'export_failed'
                  : 'export_progress')),
          automaticallyImplyLeading: !_job.isRunning,
        ),
        body: SafeArea(child: PageBody(child: body)),
      ),
    );
  }

  Widget _progressView(BuildContext context, L10n l10n) {
    final pct = (_job.progress * 100).clamp(0, 100);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CircularProgressIndicator(
                  value: _job.progress <= 0 ? null : _job.progress,
                  strokeWidth: 6,
                ),
                Center(
                  child: Text(
                    '${pct.round()}%',
                    style: context.theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.s24),
          Text(l10n.t(_job.stage.messageKey),
              style: context.theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.s8),
          Text(
            '${_job.framesDone}/${_job.framesTotal} · '
            '${l10n.t('export_elapsed')} ${formatClock(_job.elapsed.inSeconds.toDouble())}',
            style: context.theme.textTheme.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_job.eta != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              l10n.t('export_remaining').replaceAll(
                  '{time}', formatClock(_job.eta!.inSeconds.toDouble())),
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.s32),
          OutlinedButton.icon(
            onPressed: _job.cancelling
                ? null
                : () => ref.read(exportManagerProvider).cancel(),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text(l10n.t(
                _job.cancelling ? 'export_cancelling' : 'export_cancel')),
          ),
        ],
      ),
    );
  }

  Widget _blockedView(BuildContext context, L10n l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.extension_off_rounded,
              size: 56, color: context.theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(l10n.t('export_blocked'),
              textAlign: TextAlign.center,
              style: context.theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.s24),
          FilledButton(
            onPressed: () => context.pop(),
            child: Text(l10n.t('action_back')),
          ),
        ],
      ),
    );
  }

  Widget _failureView(BuildContext context, L10n l10n, AppFailure f) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.error_outline_rounded,
              size: 56, color: context.theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(l10n.t(f.messageKey),
              textAlign: TextAlign.center,
              style: context.theme.textTheme.titleMedium),
          if (f.recoverableWith != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(f.recoverableWith!,
                textAlign: TextAlign.center,
                style: context.theme.textTheme.bodySmall),
          ],
          if (f.technicalDetail != null)
            ExpansionTile(
              title: Text(l10n.t('error_details'),
                  style: context.theme.textTheme.bodySmall),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(AppTheme.s12),
                  child: SelectableText(
                    f.technicalDetail!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppTheme.s24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => context.pop(),
                child: Text(l10n.t('action_back')),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _failure = null;
                    _started = false;
                  });
                  _start();
                },
                child: Text(l10n.t('action_retry')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _completeView(
      BuildContext context, L10n l10n, NativeExportResult result) {
    return ListView(
      children: <Widget>[
        const SizedBox(height: AppTheme.s8),
        Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded,
                color: AppColors.mint, size: 28),
            const SizedBox(width: 8),
            Text(l10n.t('export_complete'),
                style: context.theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n
              .t('export_complete_sub')
              .replaceAll('{w}', '${result.width}')
              .replaceAll('{h}', '${result.height}')
              .replaceAll('{fps}', '${result.fps}')
              .replaceAll('{size}', formatBytes(result.sizeBytes)),
          style: context.theme.textTheme.bodySmall?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.s16),
        _ExportPlayer(path: result.path),
        const SizedBox(height: AppTheme.s16),
        if (result.galleryUri != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.s8),
            child: Row(
              children: <Widget>[
                const Icon(Icons.photo_library_rounded,
                    size: 16, color: AppColors.mint),
                const SizedBox(width: 6),
                Text(l10n.t('export_save_gallery'),
                    style: context.theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.mint)),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.s16),
            child: Column(
              children: <Widget>[
                _kv(context, l10n.t('export_resolution'),
                    '${result.width} × ${result.height}'),
                _kv(context, l10n.t('export_fps'), '${result.fps} fps'),
                _kv(context, l10n.t('export_codec'), result.codec.toUpperCase()),
                _kv(context, l10n.t('export_bitrate'),
                    '${(result.bitrate / 1000000).toStringAsFixed(1)} Mbps'),
                _kv(context, l10n.t('export_frames'), '${result.frameCount}'),
                _kv(context, l10n.t('editor_total'),
                    formatClock(result.durationMs / 1000)),
                _kv(context,
                    l10n.t('audio_title'),
                    result.hasAudio
                        ? l10n.t('common_on')
                        : l10n.t('common_off')),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.s16),
        GradientButton(
          label: l10n.t('export_share'),
          icon: Icons.share_rounded,
          onPressed: () async {
            try {
              await ref.read(exportManagerProvider).share(result);
            } on AppFailure catch (e) {
              if (context.mounted) {
                context.snack(l10n.t(e.messageKey), isError: true);
              }
            } on BridgeUnavailable {
              if (context.mounted) {
                context.snack(l10n.t('export_blocked'), isError: true);
              }
            }
          },
        ),
        const SizedBox(height: AppTheme.s8),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(projectEditorProvider.notifier).detach();
            context.go(AppRoutes.gallery);
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.t('export_new_project')),
        ),
        const SizedBox(height: AppTheme.s8),
        TextButton(
          onPressed: () {
            ref.read(projectEditorProvider.notifier).detach();
            context.go(AppRoutes.home);
          },
          child: Text(l10n.t('nav_home')),
        ),
        const SizedBox(height: AppTheme.s24),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(k,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            Text(v),
          ],
        ),
      );
}

/// Plays the freshly exported file so the user can verify it immediately.
class _ExportPlayer extends StatefulWidget {
  const _ExportPlayer({required this.path});

  final String path;

  @override
  State<_ExportPlayer> createState() => _ExportPlayerState();
}

class _ExportPlayerState extends State<_ExportPlayer> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final file = File(widget.path);
    if (!file.existsSync()) {
      setState(() => _error = 'missing');
      return;
    }
    final c = VideoPlayerController.file(file);
    try {
      await c.initialize();
      await c.setLooping(true);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
      await c.play();
    } catch (e) {
      // The user may have left the screen while the preview was initializing.
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _error = '$e');
      await c.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Text('Player error',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
        ),
      );
    }
    final c = _controller;
    if (c == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            VideoPlayer(c),
            Positioned(
              bottom: 8,
              child: Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    onPressed: () =>
                        c.value.isPlaying ? c.pause() : c.play(),
                    icon: Icon(c.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: () =>
                        c.seekTo(Duration.zero).then((_) => c.play()),
                    icon: const Icon(Icons.replay_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
