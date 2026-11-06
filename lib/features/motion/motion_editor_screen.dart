/// Per-photo manual motion editor.
///
/// Everything the brief requires for hands-on control lives here:
///  * pinch to zoom the shot, drag to move it, on a handleable canvas
///  * explicit Start-frame / End-frame selection, with the *other* keyframe
///    ghosted so the move can be composed visually
///  * keyframe add / remove / retime on a per-photo timeline with a playhead
///  * motion type, intensity, easing, duration, rotation
///  * copy / paste / duplicate / reset / lock / randomize
///
/// The screen never bypasses the motion model: every gesture writes real
/// keyframes through [ProjectEditorController], so what is shown is exactly
/// what the native renderer will produce.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

// Viewport/ImageFit are the camera_math.dart classes, not the Flutter ones.
import 'package:flutter/material.dart' hide ValueSlider, Viewport, ImageFit;
import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/strings.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/keyframe.dart';
import '../../core/models/motion_path.dart';
import '../../core/models/motion_profile.dart';
import '../../core/models/motion_type.dart';
import '../../core/models/photo_item.dart';
import '../../core/utils/easing.dart';
import '../../core/utils/img_proc_math.dart';
import '../motion/camera_math.dart';
import '../preview/preview_transform.dart';
import '../project/project_editor_controller.dart';

/// Clipboard for copy / paste motion, shared between photos and screens.
class MotionClipboard {
  static List<Keyframe>? _keyframes;
  static MotionType _type = MotionType.zoomIn;
  static double _intensity = 0.6;

  static bool get hasContent => _keyframes != null;

  static void copy(MotionProfile profile) {
    _keyframes = List<Keyframe>.of(profile.keyframes);
    _type = profile.motionType;
    _intensity = profile.intensity;
  }

  static MotionProfile? pasted(double targetDuration) {
    final kfs = _keyframes;
    if (kfs == null || kfs.length < 2) return null;
    final out = <Keyframe>[];
    final oldEnd = kfs.last.time;
    for (final k in kfs) {
      out.add(k.copyWith(
        time: oldEnd <= 0 ? 0 : k.time / oldEnd * targetDuration,
      ));
    }
    out[0] = out[0].copyWith(time: 0);
    return MotionProfile(
      keyframes: out,
      motionType: _type,
      intensity: _intensity,
    );
  }
}

class MotionEditorScreen extends ConsumerStatefulWidget {
  const MotionEditorScreen({this.photoId, super.key});

  final String? photoId;

  @override
  ConsumerState<MotionEditorScreen> createState() => _MotionEditorScreenState();
}

class _MotionEditorScreenState extends ConsumerState<MotionEditorScreen>
    with SingleTickerProviderStateMixin {
  String? _photoId;
  int _selectedKf = 0;
  double _playhead = 0;
  bool _playing = false;
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 5));

  // gesture accumulation
  double _gestureStartScale = 1.0;
  double _gestureStartRotation = 0.0;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _photoId = widget.photoId ??
        ref.read(projectEditorProvider)?.selectedPhotoId;
    _clock.addListener(() {
      if (!_playing || !mounted) return;
      setState(() => _playhead = _clock.value * _duration);
    });
    _clock.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed) {
        setState(() => _playing = false);
      }
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  // ref.read (not watch): this getter is also used from gesture handlers,
  // where watch is not allowed. build() calls ref.watch directly, so the
  // screen still rebuilds when the editor state changes.
  PhotoItem? get _photo {
    final st = ref.read(projectEditorProvider);
    if (st == null || _photoId == null) return null;
    return st.photoById(_photoId!);
  }

  double get _duration => _photo?.duration ?? 5.0;

  Viewport get _viewport =>
      ref.read(projectEditorProvider)?.viewport ?? const Viewport(16 / 9);

  MotionProfile? get _motion => _photo?.motion;

  void _play() {
    if (_photo?.motion == null) return;
    setState(() => _playing = true);
    _clock.duration = Duration(milliseconds: (_duration * 1000).round());
    _clock.forward(from: _playhead / _duration);
  }

  void _pause() {
    _clock.stop();
    setState(() => _playing = false);
  }

  void _writeKeyframe(Keyframe updated) {
    final motion = _motion;
    final photo = _photo;
    if (motion == null || photo == null) return;
    final kfs = List<Keyframe>.of(motion.keyframes);
    kfs[_selectedKf] = updated;
    final fit = ImageFit.make(photo.width, photo.height, _viewport);
    final clamped = clampKeyframe(updated, fit, _viewport);
    if (clamped.corrected) {
      HapticFeedback.selectionClick();
    }
    kfs[_selectedKf] = clamped.keyframe;
    ref.read(projectEditorProvider.notifier).setMotion(
          photo.id,
          motion.withKeyframes(kfs),
          record: false,
        );
  }

  Keyframe? get _currentKf {
    final m = _motion;
    if (m == null || _selectedKf >= m.keyframes.length) return null;
    return m.keyframes[_selectedKf];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Register the dependency (the _photo getter reads it via ref.read so it
    // is also safe to call from gesture handlers).
    ref.watch(projectEditorProvider);
    final photo = _photo;
    if (photo == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('motion_title'))),
        body: EmptyState(
          icon: Icons.videocam_off_outlined,
          title: l10n.t('editor_select_photo_hint'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('motion_title')),
        actions: <Widget>[
          IconButton(
            tooltip: photo.isLocked
                ? l10n.t('motion_unlock')
                : l10n.t('motion_lock'),
            onPressed: () => ref
                .read(projectEditorProvider.notifier)
                .toggleLock(photo.id),
            icon: Icon(photo.isLocked
                ? Icons.lock_rounded
                : Icons.lock_open_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (String v) => _onMenu(v, l10n),
            itemBuilder: (BuildContext c) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                  value: 'copy', child: Text(l10n.t('motion_copy'))),
              PopupMenuItem<String>(
                value: 'paste',
                enabled: MotionClipboard.hasContent,
                child: Text(l10n.t('motion_paste')),
              ),
              PopupMenuItem<String>(
                  value: 'duplicate', child: Text(l10n.t('motion_duplicate'))),
              PopupMenuItem<String>(
                  value: 'reset', child: Text(l10n.t('motion_reset'))),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'path',
                child: Text(l10n.t('path_title')),
              ),
              PopupMenuItem<String>(
                  value: 'randomize', child: Text(l10n.t('motion_randomize'))),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final wide = constraints.maxWidth >= 900;
            final canvas = _canvas(context, l10n, photo);
            final controls = _controls(context, l10n, photo);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(flex: 3, child: Padding(
                    padding: const EdgeInsets.all(AppTheme.s16),
                    child: canvas,
                  )),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.s16),
                      child: controls,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: <Widget>[
                Expanded(child: Padding(
                  padding: const EdgeInsets.all(AppTheme.s12),
                  child: canvas,
                )),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: controls,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ canvas
  Widget _canvas(BuildContext context, L10n l10n, PhotoItem photo) {
    final motion = photo.motion;
    final st = ref.watch(projectEditorProvider)!;
    final vp = st.viewport;
    final kf = _currentKf;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            _frameChip(l10n.t('motion_start_frame'), 0),
            const SizedBox(width: 8),
            _frameChip(l10n.t('motion_end_frame'),
                (motion?.keyframes.length ?? 2) - 1),
            const Spacer(),
            if (photo.isLocked)
              Pill(
                label: l10n.t('editor_locked'),
                icon: Icons.lock_rounded,
                color: AppColors.amber,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: motion == null
              ? const Center(child: Text('—'))
              : GestureDetector(
                  key: _canvasKey,
                  onScaleStart: (ScaleStartDetails d) {
                    final k = _currentKf;
                    if (k == null) return;
                    _gestureStartScale = k.scale;
                    _gestureStartRotation = k.rotation;
                  },
                  onScaleUpdate: (ScaleUpdateDetails d) {
                    final k = _currentKf;
                    if (k == null) return;
                    final box = _canvasKey.currentContext?.size;
                    if (box == null) return;
                    var next = k;
                    if (d.rotation.abs() > 0.0005) {
                      // Same ±8° legal range as the rotation slider, so a
                      // gesture can never produce a value the UI can't show.
                      next = next.copyWith(
                        rotation: (_gestureStartRotation + d.rotation)
                            .clamp(-8 * math.pi / 180, 8 * math.pi / 180),
                      );
                    }
                    if ((d.scale - 1).abs() > 0.0005) {
                      next = next.copyWith(
                          scale: (_gestureStartScale * d.scale).clamp(1.0, 8.0));
                    }
                    if (d.focalPointDelta.distance > 0.01) {
                      // Delta-based pan: apply each move from the *current*
                      // camera so dragging never runs away from the finger.
                      final cam = CameraState(
                        x: next.x,
                        y: next.y,
                        scale: next.scale,
                        rotation: next.rotation,
                      );
                      final delta = screenDeltaToCamera(
                        deltaPx: d.focalPointDelta,
                        outputSize: box,
                        cam: cam,
                        vp: vp,
                      );
                      next = next.copyWith(
                        x: next.x + delta.dx,
                        y: next.y + delta.dy,
                      );
                    }
                    _writeKeyframe(next);
                  },
                  onScaleEnd: (_) => _commitGesture(photo),
                  child: _MotionCanvas(
                    photo: photo,
                    motion: motion,
                    viewport: vp,
                    playhead: _playing ? _playhead : (_currentKf?.time ?? 0),
                    showOtherFrame: true,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.t('motion_gesture_hint'),
          textAlign: TextAlign.center,
          style: context.theme.textTheme.bodySmall?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _keyframeStrip(context, l10n, photo),
        const SizedBox(height: 8),
        _timeline(context, l10n, photo, kf),
      ],
    );
  }

  Widget _frameChip(String label, int index) {
    final motion = _motion;
    final enabled = motion != null && index < motion.keyframes.length;
    final selected = _selectedKf == index;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled
          ? (_) => setState(() {
                _selectedKf = index;
                _playhead = motion.keyframes[index].time;
              })
          : null,
    );
  }

  Widget _keyframeStrip(BuildContext context, L10n l10n, PhotoItem photo) {
    final motion = photo.motion;
    if (motion == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < motion.keyframes.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: FilterChip(
                selected: _selectedKf == i,
                label: Text(
                    '${i + 1} · ${motion.keyframes[i].time.toStringAsFixed(1)}s'),
                onSelected: (_) => setState(() {
                  _selectedKf = i;
                  _playhead = motion.keyframes[i].time;
                }),
                onDeleted: (i == 0 || i == motion.keyframes.length - 1)
                    ? null
                    : () => _removeKeyframe(photo, i),
                deleteIcon: const Icon(Icons.close_rounded, size: 14),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 16),
            label: Text(l10n.t('motion_add_keyframe')),
            onPressed: () => _addKeyframe(photo),
          ),
        ],
      ),
    );
  }

  Widget _timeline(
      BuildContext context, L10n l10n, PhotoItem photo, Keyframe? kf) {
    final motion = photo.motion;
    if (motion == null) return const SizedBox.shrink();
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton.filledTonal(
              onPressed: _playing ? _pause : _play,
              icon: Icon(_playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
            ),
            Expanded(
              child: Slider(
                value: _playhead.clamp(0.0, _duration),
                min: 0,
                max: _duration,
                onChanged: (double v) {
                  if (_playing) _pause();
                  setState(() {
                    _playhead = v;
                    // Keep the selection in sync with the scrubbed time.
                    var best = 0;
                    var bestDist = double.infinity;
                    for (var i = 0; i < motion.keyframes.length; i++) {
                      final d = (motion.keyframes[i].time - v).abs();
                      if (d < bestDist) {
                        bestDist = d;
                        best = i;
                      }
                    }
                    _selectedKf = best;
                  });
                },
              ),
            ),
            Text('${_playhead.toStringAsFixed(1)}s',
                style: context.theme.textTheme.labelMedium),
          ],
        ),
        if (kf != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${l10n.t('motion_keyframes')}: ${_selectedKf + 1}/${motion.keyframes.length}'
              ' · t=${kf.time.toStringAsFixed(2)}s'
              ' · ${l10n.t('motion_easing')}: ${l10n.t(kf.easing.labelKey)}',
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- controls
  /// Entry point to the camera path editor (also usable on a photo that has
  /// no motion yet — the first edit creates a base motion to ride on).
  Widget _pathEntry(BuildContext context, L10n l10n, PhotoItem photo) {
    final path = photo.motion?.path;
    return OutlinedButton.icon(
      onPressed: () => context
          .push('${AppRoutes.pathEditor}?photo=${Uri.encodeComponent(photo.id)}'),
      icon: const Icon(Icons.travel_explore_rounded, size: 18),
      label: Text(
          path == null
              ? l10n.t('path_title')
              : '${l10n.t('path_title')} · ${l10n.t(MotionPathPreset.labelKey(path.preset))}'),
    );
  }

  Widget _controls(BuildContext context, L10n l10n, PhotoItem photo) {
    final motion = photo.motion;
    if (motion == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _pathEntry(context, l10n, photo),
          const SizedBox(height: AppTheme.s12),
          EmptyState(
            icon: Icons.auto_awesome_outlined,
            title: l10n.t('editor_no_motion'),
            hint: l10n.t('editor_tap_start_hint'),
            action: FilledButton(
              onPressed: () => ref
                  .read(projectEditorProvider.notifier)
                  .regeneratePhotoMotion(photo.id),
              child: Text(l10n.t('motion_randomize')),
            ),
          ),
        ],
      );
    }
    final kf = _currentKf;
    final fit = ImageFit.make(photo.width, photo.height, _viewport);
    final sMin = minScaleAtRotation(fit, _viewport, kf?.rotation ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _pathEntry(context, l10n, photo),
        const SizedBox(height: AppTheme.s12),
        SectionCard(
          title: l10n.t('motion_type'),
          icon: Icons.auto_awesome_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final t in MotionType.values)
                    ChoiceChip(
                      label: Text(l10n.t(t.labelKey)),
                      selected: motion.motionType == t,
                      onSelected: (_) => _applyType(photo, t),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.s8),
              ValueSlider(
                label: l10n.t('motion_intensity'),
                value: motion.intensity,
                min: 0,
                max: 1,
                format: (double v) => '${(v * 100).round()}%',
                onChanged: (double v) => ref
                    .read(projectEditorProvider.notifier)
                    .setMotionIntensity(photo.id, v),
                onChangeEnd: (_) => _reapplyType(photo),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.s12),
        if (kf != null) ...<Widget>[
          SectionCard(
            title: '${l10n.t('motion_keyframes')} ${_selectedKf + 1}',
            icon: Icons.filter_center_focus_rounded,
            trailing: Text(
              '${(kf.rotationDegrees).toStringAsFixed(1)}°',
              style: context.theme.textTheme.labelMedium,
            ),
            child: Column(
              children: <Widget>[
                // Display values are clamped into the slider range: two-finger
                // gestures can store scale up to 8x (beyond the 4x slider max),
                // and ValueSlider asserts when value is outside [min, max].
                ValueSlider(
                  label: l10n.t('motion_zoom'),
                  icon: Icons.zoom_in_rounded,
                  value: kf.scale.clamp(math.max(1.0, sMin), 4.0),
                  min: math.max(1.0, sMin),
                  max: 4.0,
                  format: (double v) => '${v.toStringAsFixed(2)}×',
                  onChanged: (double v) =>
                      _writeKeyframe(kf.copyWith(scale: v)),
                  onChangeEnd: (_) => _commitGesture(photo),
                ),
                ValueSlider(
                  label: l10n.t('motion_rotation'),
                  icon: Icons.rotate_right_rounded,
                  value: kf.rotationDegrees.clamp(-8.0, 8.0),
                  min: -8,
                  max: 8,
                  format: (double v) => '${v.toStringAsFixed(1)}°',
                  onChanged: (double v) => _writeKeyframe(
                      kf.copyWith(rotation: v * math.pi / 180)),
                  onChangeEnd: (_) => _commitGesture(photo),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ValueSlider(
                        label: 'X',
                        value: _panFractionX(kf, fit),
                        min: -1,
                        max: 1,
                        format: (double v) => '${(v * 100).round()}%',
                        onChanged: (double v) => _writeKeyframe(
                            _withPanFractionX(kf, fit, v)),
                        onChangeEnd: (_) => _commitGesture(photo),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ValueSlider(
                        label: 'Y',
                        value: _panFractionY(kf, fit),
                        min: -1,
                        max: 1,
                        format: (double v) => '${(v * 100).round()}%',
                        onChanged: (double v) => _writeKeyframe(
                            _withPanFractionY(kf, fit, v)),
                        onChangeEnd: (_) => _commitGesture(photo),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<Easing>(
                        initialValue: kf.easing,
                        decoration: InputDecoration(
                          labelText: l10n.t('motion_easing'),
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<Easing>>[
                          for (final e in Easing.values)
                            DropdownMenuItem<Easing>(
                              value: e,
                              child: Text(l10n.t(e.labelKey)),
                            ),
                        ],
                        onChanged: (Easing? e) {
                          if (e == null) return;
                          _writeKeyframe(kf.copyWith(easing: e));
                          _commitGesture(photo);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedKf != 0 &&
                        _selectedKf != motion.keyframes.length - 1)
                      OutlinedButton.icon(
                        onPressed: () => _removeKeyframe(photo, _selectedKf),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: Text(l10n.t('action_remove')),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.s12),
        ],
        SectionCard(
          title: l10n.t('editor_photo'),
          icon: Icons.timer_outlined,
          child: ValueSlider(
            label: l10n.t('editor_duration'),
            value: photo.duration,
            min: AppLimits.minPhotoDuration,
            max: 15,
            divisions: 140,
            format: (double v) => '${v.toStringAsFixed(1)}s',
            onChanged: (double v) => ref
                .read(projectEditorProvider.notifier)
                .setPhotoDuration(photo.id, v),
          ),
        ),
        const SizedBox(height: AppTheme.s12),
        SectionCard(
          title: l10n.t('motion_title'),
          icon: Icons.build_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () {
                  MotionClipboard.copy(motion);
                  context.snack(l10n.t('motion_copied'));
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l10n.t('motion_copy')),
              ),
              OutlinedButton.icon(
                onPressed: !MotionClipboard.hasContent
                    ? null
                    : () {
                        final pasted =
                            MotionClipboard.pasted(photo.duration);
                        if (pasted == null) return;
                        ref
                            .read(projectEditorProvider.notifier)
                            .setMotion(photo.id, pasted);
                        context.snack(l10n.t('motion_pasted'));
                      },
                icon: const Icon(Icons.paste_rounded, size: 18),
                label: Text(l10n.t('motion_paste')),
              ),
              OutlinedButton.icon(
                onPressed: () => _duplicateToNext(photo),
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: Text(l10n.t('motion_duplicate')),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(projectEditorProvider.notifier).undo(),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(l10n.t('editor_undo')),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(projectEditorProvider.notifier).redo(),
                icon: const Icon(Icons.redo_rounded, size: 18),
                label: Text(l10n.t('editor_redo')),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(projectEditorProvider.notifier).regeneratePhotoMotion(photo.id),
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: Text(l10n.t('motion_randomize')),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.s12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.t('action_done')),
          ),
        ),
      ],
    );
  }

  /// Pan sliders are expressed as a fraction of the *legal travel* so the same
  /// UI feels identical on a 16:9 and a 9:16 project. The value shown is the
  /// current offset divided by the maximum offset available at this scale.
  double _panFractionX(Keyframe k, ImageFit fit) {
    final lim = maxPan(fit, _viewport, k.scale, k.rotation);
    return lim.mx <= 1e-9 ? 0.0 : (k.x / lim.mx).clamp(-1.0, 1.0);
  }

  double _panFractionY(Keyframe k, ImageFit fit) {
    final lim = maxPan(fit, _viewport, k.scale, k.rotation);
    return lim.my <= 1e-9 ? 0.0 : (k.y / lim.my).clamp(-1.0, 1.0);
  }

  Keyframe _withPanFractionX(Keyframe k, ImageFit fit, double fraction) {
    final lim = maxPan(fit, _viewport, k.scale, k.rotation);
    return k.copyWith(x: fraction * lim.mx);
  }

  Keyframe _withPanFractionY(Keyframe k, ImageFit fit, double fraction) {
    final lim = maxPan(fit, _viewport, k.scale, k.rotation);
    return k.copyWith(y: fraction * lim.my);
  }

  void _commitGesture(PhotoItem photo) {
    final m = _motion;
    if (m == null) return;
    ref
        .read(projectEditorProvider.notifier)
        .setMotion(photo.id, m, record: true);
  }

  void _applyType(PhotoItem photo, MotionType type) {
    final notifier = ref.read(projectEditorProvider.notifier);
    notifier.setMotionType(photo.id, type);
    notifier.regeneratePhotoMotion(photo.id);
    setState(() => _selectedKf = 0);
  }

  void _reapplyType(PhotoItem photo) {
    // intensity changed: rebuild the shot with the same type
    ref.read(projectEditorProvider.notifier).regeneratePhotoMotion(photo.id);
  }

  void _addKeyframe(PhotoItem photo) {
    final motion = photo.motion;
    if (motion == null) return;
    final t = _playhead.clamp(0.05, photo.duration - 0.05);
    final state = sampleKeyframes(motion.keyframes, t);
    final kfs = <Keyframe>[
      ...motion.keyframes,
      Keyframe(
        time: t,
        x: state.x,
        y: state.y,
        scale: state.scale,
        rotation: state.rotation,
        easing: Easing.smoother,
      ),
    ]..sort((Keyframe a, Keyframe b) => a.time.compareTo(b.time));
    final idx = kfs.indexWhere((Keyframe k) => (k.time - t).abs() < 1e-9);
    ref
        .read(projectEditorProvider.notifier)
        .setMotion(photo.id, motion.withKeyframes(kfs));
    setState(() => _selectedKf = math.max(0, idx));
  }

  void _removeKeyframe(PhotoItem photo, int index) {
    final motion = photo.motion;
    if (motion == null) return;
    if (index <= 0 || index >= motion.keyframes.length - 1) return;
    final kfs = List<Keyframe>.of(motion.keyframes)..removeAt(index);
    ref
        .read(projectEditorProvider.notifier)
        .setMotion(photo.id, motion.withKeyframes(kfs));
    setState(() => _selectedKf = math.max(0, index - 1));
  }

  void _duplicateToNext(PhotoItem photo) {
    final st = ref.read(projectEditorProvider)!;
    final index = st.indexOf(photo.id);
    if (index < 0 || index + 1 >= st.project.photos.length) {
      context.snack(context.l10n.t('motion_no_clipboard'));
      return;
    }
    final next = st.project.photos[index + 1];
    final motion = photo.motion;
    if (motion == null) return;
    MotionClipboard.copy(motion);
    final pasted = MotionClipboard.pasted(next.duration);
    if (pasted == null) return;
    ref
        .read(projectEditorProvider.notifier)
        .setMotion(next.id, pasted);
    context.snack(context.l10n.t('motion_pasted'));
  }

  void _onMenu(String value, L10n l10n) {
    final photo = _photo;
    if (photo == null) return;
    final notifier = ref.read(projectEditorProvider.notifier);
    switch (value) {
      case 'copy':
        final m = photo.motion;
        if (m != null) {
          MotionClipboard.copy(m);
          context.snack(l10n.t('motion_copied'));
        }
      case 'paste':
        final pasted = MotionClipboard.pasted(photo.duration);
        if (pasted == null) {
          context.snack(l10n.t('motion_no_clipboard'));
          return;
        }
        notifier.setMotion(photo.id, pasted);
        setState(() => _selectedKf = 0);
        context.snack(l10n.t('motion_pasted'));
      case 'duplicate':
        _duplicateToNext(photo);
      case 'reset':
        notifier.regeneratePhotoMotion(photo.id);
        setState(() => _selectedKf = 0);
      case 'randomize':
        notifier.regeneratePhotoMotion(photo.id);
        setState(() => _selectedKf = 0);
      case 'path':
        context.push('${AppRoutes.pathEditor}?photo=${Uri.encodeComponent(photo.id)}');
    }
  }
}

/// Renders the shot being edited, with the *other* keyframe ghosted so a move
/// can be composed without flipping back and forth.
class _MotionCanvas extends ConsumerWidget {
  const _MotionCanvas({
    required this.photo,
    required this.motion,
    required this.viewport,
    required this.playhead,
    required this.showOtherFrame,
  });

  final PhotoItem photo;
  final MotionProfile motion;
  final Viewport viewport;
  final double playhead;
  final bool showOtherFrame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(previewImageCacheProvider);
    final thumb = photo.thumbnailPath;
    final src = photo.sourceUri;
    final existingPath = thumb != null && File(thumb).existsSync()
        ? thumb
        : (!src.startsWith('content://') && File(src).existsSync() ? src : null);
    final provider = existingPath != null ? FileImage(File(existingPath)) : null;
    if (provider != null) cache.request(photo.id, provider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              painter: _MotionCanvasPainter(
                photo: photo,
                motion: motion,
                viewport: viewport,
                playhead: playhead,
                showOtherFrame: showOtherFrame,
                image: cache.imageFor(photo.id),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _MotionCanvasPainter extends CustomPainter {
  _MotionCanvasPainter({
    required this.photo,
    required this.motion,
    required this.viewport,
    required this.playhead,
    required this.showOtherFrame,
    required this.image,
  });

  final PhotoItem photo;
  final MotionProfile motion;
  final Viewport viewport;
  final double playhead;
  final bool showOtherFrame;
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final vp = viewport;
    final fit = ImageFit.make(photo.width, photo.height, vp);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    CameraState cam() => motion.sample(playhead.clamp(0.0, photo.duration), fit, vp);

    if (image != null) {
      final m = previewMatrix(
          cam: cam(), fit: fit, vp: vp, outputSize: size);
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.transform(m.storage);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      final tp = TextPainter(
        text: const TextSpan(
            text: 'loading preview',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    }

    // Ghost of the counterpart frame.
    if (showOtherFrame) {
      final start = motion.sample(0, fit, vp);
      final end = motion.sample(photo.duration, fit, vp);
      final ghost = (playhead - 0).abs() < (playhead - photo.duration).abs()
          ? end
          : start;
      final gm = previewMatrix(
          cam: ghost, fit: fit, vp: vp, outputSize: size);
      final gCorners = viewportCorners(ghost, vp);
      final gPts = <Offset>[
        for (final p in gCorners)
          MatrixUtils.transformPoint(
              gm, Offset(imageToUv(p.x, p.y, fit).u, imageToUv(p.x, p.y, fit).v)),
      ];
      final path = Path()..addPolygon(gPts, true);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF35D6A4).withValues(alpha: 0.9),
      );
    }

    // Safe frame: shows what the exported video will contain.
    final nowCam = cam();
    final safeM = previewMatrix(cam: nowCam, fit: fit, vp: vp, outputSize: size);
    final safeCorners = viewportCorners(nowCam, vp);
    final pts = <Offset>[
      for (final p in safeCorners)
        MatrixUtils.transformPoint(
            safeM, Offset(imageToUv(p.x, p.y, fit).u, imageToUv(p.x, p.y, fit).v)),
    ];
    canvas.drawPath(
      Path()..addPolygon(pts, true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    for (final p in pts) {
      canvas.drawCircle(p, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_MotionCanvasPainter old) =>
      old.playhead != playhead ||
      old.photo.id != photo.id ||
      old.image != image ||
      !identical(old.motion, motion);
}
