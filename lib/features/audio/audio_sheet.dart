/// Music picker / settings bottom sheet.
library;

import 'dart:io';

import 'package:flutter/material.dart' hide ValueSlider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/strings.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../app/widgets/progress.dart';
import '../../core/errors/app_failure.dart';
import '../../core/models/audio_settings.dart';
import '../../core/utils/ratio_utils.dart';
import '../project/project_editor_controller.dart';

Future<void> showAudioSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext ctx) => const _AudioSheet(),
  );
}

class _AudioSheet extends ConsumerStatefulWidget {
  const _AudioSheet();

  @override
  ConsumerState<_AudioSheet> createState() => _AudioSheetState();
}

class _AudioSheetState extends ConsumerState<_AudioSheet> {
  bool _busy = false;
  bool _syncing = false;

  /// Aligns every photo switch to the nearest quiet moment of the project's
  /// audio. The silence map is decoded natively (a few seconds on long
  /// tracks); the state change itself is a single undoable commit.
  Future<void> _syncCutsToSilence(AudioSettings audio) async {
    final l10n = context.l10n;
    final path = audio.uri;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      context.snack(l10n.t('error_audioUnreadable'), isError: true);
      return;
    }
    setState(() => _syncing = true);
    try {
      final silences =
          await ref.read(bootstrapProvider).mediaPicker.analyzeSilences(path);
      final moved = ref
          .read(projectEditorProvider.notifier)
          .syncToAudio(silences);
      if (mounted) {
        context.snack(l10n.t(moved > 0 ? 'audio_synced' : 'audio_sync_none'));
      }
    } on AppFailure catch (e) {
      if (mounted) context.snack(context.l10n.t(e.messageKey), isError: true);
    } catch (e) {
      debugPrint('silence sync failed: $e');
      if (mounted) {
        context.snack(context.l10n.t('error_unknown'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _pick() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      // The overlay stays behind the native picker, then covers the copy of
      // the file (which the native side does after selection).
      final file = await runHeroProgress<File>(
        context,
        title: l10n.t('import_audio_title'),
        detail: l10n.t('import_audio_selecting'),
        task: (report, token) =>
            ref.read(bootstrapProvider).mediaPicker.pickAudio(),
      );
      if (file == null) return;
      final st = ref.read(projectEditorProvider);
      final current = st?.project.audio ?? const AudioSettings();
      final settings = current.copyWith(
        uri: file.path,
        displayName: file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'audio',
        trimStart: 0,
        trimEnd: null,
      );
      ref.read(projectEditorProvider.notifier).setAudio(settings);
      if (mounted) setState(() {});
    } on AppFailure catch (e) {
      if (mounted) context.snack(context.l10n.t(e.messageKey), isError: true);
    } catch (e) {
      if (mounted) {
        context.snack(context.l10n.t('error_audioUnreadable'), isError: true);
      }
      debugPrint('audio pick failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final st = ref.watch(projectEditorProvider);
    final audio = st?.project.audio;
    final duration = st?.project.totalDuration ?? 0;
    final notifier = ref.read(projectEditorProvider.notifier);

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.s20,
        right: AppTheme.s20,
        top: AppTheme.s8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.s20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.t('audio_title'),
              style: context.theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(l10n.t('audio_supported'),
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: AppTheme.s16),
          if (audio == null || !audio.hasAudio)
            FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.library_music_outlined),
              label: Text(l10n.t('audio_pick')),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.audiotrack_rounded),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(audio.displayName,
                        overflow: TextOverflow.ellipsis)),
                if (audio.sourceDuration != null)
                  Pill(
                      label: formatClock(audio.sourceDuration!),
                      icon: Icons.schedule_rounded),
              ],
            ),
            const SizedBox(height: AppTheme.s8),
            ValueSlider(
              label: l10n.t('audio_volume'),
              icon: Icons.volume_up_outlined,
              value: audio.volume,
              min: 0,
              max: 1,
              format: (double v) => '${(v * 100).round()}%',
              onChanged: (double v) =>
                  notifier.setAudio(audio.copyWith(volume: v)),
            ),
            ValueSlider(
              label: l10n.t('audio_fade_in'),
              icon: Icons.gradient_rounded,
              value: audio.fadeIn,
              min: 0,
              max: 5,
              divisions: 50,
              format: (double v) => '${v.toStringAsFixed(1)}s',
              onChanged: (double v) =>
                  notifier.setAudio(audio.copyWith(fadeIn: v)),
            ),
            ValueSlider(
              label: l10n.t('audio_fade_out'),
              icon: Icons.gradient_rounded,
              value: audio.fadeOut,
              min: 0,
              max: 5,
              divisions: 50,
              format: (double v) => '${v.toStringAsFixed(1)}s',
              onChanged: (double v) =>
                  notifier.setAudio(audio.copyWith(fadeOut: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.t('audio_loop')),
              value: audio.loop,
              onChanged: (bool v) =>
                  notifier.setAudio(audio.copyWith(loop: v)),
            ),
            const SizedBox(height: AppTheme.s8),
            Text(
              '${l10n.t('audio_sync_note')} (${formatClock(duration)})',
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.s12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text(l10n.t('audio_pick')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => notifier.setAudio(null),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(l10n.t('audio_remove')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.s8),
            OutlinedButton.icon(
              onPressed: (_busy || _syncing) ? null : () => _syncCutsToSilence(audio),
              icon: _syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.graphic_eq_rounded, size: 18),
              label: Text(l10n.t('audio_sync_cuts')),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('audio_sync_hint'),
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.s16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('action_done')),
          ),
        ],
      ),
    );
  }
}
