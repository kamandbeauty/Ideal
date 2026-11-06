/// The Motion Path Editor — per-photo, full control of the camera path.
///
/// What the brief requires for path editing lives here:
///  * a "map view" of the photo: the valid image bounds, the camera motion
///    path, start / end markers, direction arrows, draggable control points
///    (center, radii, start angle, waypoints) and the live camera frame at
///    the playhead
///  * freehand drawing: trace the trajectory with a finger, it is smoothed
///    (arc-length resample + Chaikin) and stored as a `custom` path
///  * every path parameter: preset, center, radius X/Y, turns, direction,
///    start angle, sweep, curvature, speed, speed profile, zoom envelope,
///    rotation envelope, add/remove waypoints
///  * timeline + playhead
///
/// The screen never bypasses the motion model: every gesture writes a real
/// [MotionPathSpec] through [ProjectEditorController] (sanitized + re-baked),
/// so what is shown is exactly what the native renderer will export.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide ValueSlider;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/strings.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/motion_path.dart';
import '../../core/models/photo_item.dart';
import '../motion_path/motion_path_engine.dart';
import '../preview/motion_preview.dart';
import '../project/project_editor_controller.dart';
import 'camera_math.dart';

/// Which handle is being dragged (null = none).
enum _HandleId { none, center, radiusX, radiusY, startAngle, point }

class _DragState {
  _DragState({required this.id, required this.index, required this.grabOffset});

  final _HandleId id;
  final int index;

  /// Camera-space offset from the grabbed point to the finger at drag
  /// start. Keeping it constant while dragging makes the point follow the
  /// finger 1:1 from where it was grabbed (no jump to the touch position).
  final Offset grabOffset;
}

/// Whether the preset's trajectory actually honours
/// [MotionPathSpec.startAngle] (figureEight does not — its Lissajous
/// parameterization is fixed).
bool startAngleApplies(String preset) =>
    preset == 'circularCw' ||
    preset == 'circularCcw' ||
    preset == 'elliptical' ||
    preset == 'spiral' ||
    preset == 'arc';

/// Default path created when the user opens the editor for a photo that has
/// none yet (committed only on the first real interaction).
MotionPathSpec defaultPathFor(PhotoItem photo, Viewport vp) {
  final fit = ImageFit.make(photo.width, photo.height, vp);
  return sanitizePath(
    const MotionPathSpec(preset: 'circularCw', radiusX: 0.2, radiusY: 0.2),
    fit,
    vp,
  );
}

class PathEditorScreen extends ConsumerStatefulWidget {
  const PathEditorScreen({this.photoId, super.key});

  final String? photoId;

  @override
  ConsumerState<PathEditorScreen> createState() => _PathEditorScreenState();
}

class _PathEditorScreenState extends ConsumerState<PathEditorScreen>
    with SingleTickerProviderStateMixin {
  String? _photoId;
  double _playhead = 0;
  bool _playing = false;
  bool _drawMode = false;
  final List<Offset> _rawStroke = <Offset>[];
  _DragState? _drag;

  /// True once the current handle gesture has recorded its undo step.
  bool _dragCommitted = false;
  double _viewZoom = 1.0;
  Offset _viewPan = Offset.zero;
  final GlobalKey _canvasKey = GlobalKey();
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 5));

  /// Local (not yet committed) spec when entering without a path.
  MotionPathSpec? _pending;

  @override
  void initState() {
    super.initState();
    _photoId =
        widget.photoId ?? ref.read(projectEditorProvider)?.selectedPhotoId;
    _clock.addListener(() {
      if (!_playing || !mounted) return;
      setState(() => _playhead = _clock.value * _duration);
    });
    _clock.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed) setState(() => _playing = false);
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

  ImageFit get _fit {
    final p = _photo;
    if (p == null || p.width <= 0 || p.height <= 0) {
      return const ImageFit(iw: 0.888888, ih: 0.666666);
    }
    return ImageFit.make(p.width, p.height, _viewport);
  }

  /// The spec being edited: the stored one, or the local pending default.
  MotionPathSpec? get _spec {
    final stored = _photo?.motion?.path;
    if (stored != null) return stored;
    final p = _photo;
    if (p == null) return null;
    return _pending ??= defaultPathFor(p, _viewport);
  }

  CameraState _cameraAt(double t) {
    final p = _photo;
    final spec = _spec;
    if (p == null || spec == null) {
      return const CameraState();
    }
    return evaluatePath(spec, _fit, _viewport, t.clamp(0.0, _duration), _duration);
  }

  /// Max legal offset for the path at its maximum zoom / rotation.
  ({double mx, double my}) get _margin {
    final spec = _spec;
    if (spec == null) return (mx: 0.0, my: 0.0);
    final rMax =
        math.max(spec.startRotation.abs(), spec.endRotation.abs());
    final s = math.max(spec.startZoom, spec.endZoom);
    final lim = maxPan(_fit, _viewport, s, rMax);
    return (mx: lim.mx, my: lim.my);
  }

  // ------------------------------------------------------------------ write
  void _write(MotionPathSpec spec, {bool record = false}) {
    final p = _photo;
    if (p == null) return;
    final sanitized = sanitizePath(spec, _fit, _viewport);
    _pending = null;
    ref
        .read(projectEditorProvider.notifier)
        .setMotionPath(p.id, sanitized, record: record);
  }

  /// Applies a change to the *latest* stored spec (slider events can land
  /// while a rebuild is in flight; never edit a stale copy).
  void _edit(MotionPathSpec Function(MotionPathSpec) change,
      {bool record = false}) {
    final s = _spec;
    if (s == null) return;
    _write(change(s), record: record);
  }

  void _play() {
    if (_spec == null) return;
    setState(() => _playing = true);
    _clock.duration = Duration(milliseconds: (_duration * 1000).round());
    _clock.forward(from: _playhead / _duration);
  }

  void _pause() {
    _clock.stop();
    setState(() => _playing = false);
  }

  // ------------------------------------------------------------------ view
  /// Normalized camera space -> canvas pixels (map view: whole image
  /// visible, y up in camera space -> y down on screen).
  Offset _toScreen(double x, double y, Size size) {
    final k = _k(size);
    final cx = size.width / 2;
    final cy = size.height / 2;
    var sx = cx + x * k;
    var sy = cy - y * k;
    sx = (sx - cx) * _viewZoom + cx + _viewPan.dx;
    sy = (sy - cy) * _viewZoom + cy + _viewPan.dy;
    return Offset(sx, sy);
  }

  double _k(Size size) =>
      math.min(size.width / (2 * _fit.iw), size.height / (2 * _fit.ih));

  /// Canvas pixels -> normalized camera space (inverse of [_toScreen]).
  Offset _toCamera(Offset s, Size size) {
    final k = _k(size);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final sx = (s.dx - _viewPan.dx - cx) / _viewZoom + cx;
    final sy = (s.dy - _viewPan.dy - cy) / _viewZoom + cy;
    return Offset((sx - cx) / k, -(sy - cy) / k);
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Register the dependency (the _photo getter reads it via ref.read so it
    // is also safe to call from gesture handlers).
    ref.watch(projectEditorProvider);
    final photo = _photo;
    if (photo == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('path_title'))),
        body: EmptyState(
          icon: Icons.videocam_off_outlined,
          title: l10n.t('editor_select_photo_hint'),
        ),
      );
    }
    final spec = _spec;
    if (spec == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('path_title')),
        actions: <Widget>[
          if (photo.motion?.path != null)
            IconButton(
              tooltip: l10n.t('path_clear'),
              onPressed: () => _clearPath(photo),
              icon: const Icon(Icons.highlight_off_rounded),
            ),
          PopupMenuButton<String>(
            onSelected: (String v) => _onMenu(v, l10n, photo),
            itemBuilder: (BuildContext c) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                  value: 'reset', child: Text(l10n.t('path_reset'))),
              PopupMenuItem<String>(
                  value: 'draw',
                  child: Text(_drawMode
                      ? l10n.t('path_draw_stop')
                      : l10n.t('path_draw'))),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final wide = constraints.maxWidth >= 900;
            final canvas = _canvas(context, photo, spec);
            final controls = _controls(context, l10n, photo, spec);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Padding(
                        padding: const EdgeInsets.all(AppTheme.s16),
                        child: canvas),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTheme.s16),
                        child: controls),
                  ),
                ],
              );
            }
            return Column(
              children: <Widget>[
                Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(AppTheme.s12),
                      child: canvas),
                ),
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

  // ----------------------------------------------------------------- canvas
  Widget _canvas(BuildContext context, PhotoItem photo, MotionPathSpec spec) {
    final l10n = context.l10n;
    final cache = ref.watch(previewImageCacheProvider);
    final thumb = photo.thumbnailPath;
    final src = photo.sourceUri;
    final existingPath = thumb != null && File(thumb).existsSync()
        ? thumb
        : (!src.startsWith('content://') && File(src).existsSync()
            ? src
            : null);
    final provider =
        existingPath != null ? FileImage(File(existingPath)) : null;
    if (provider != null) cache.request(photo.id, provider);
    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
            final size = Size(c.maxWidth, c.maxHeight);
            final image = cache.imageFor(photo.id);
            return GestureDetector(
              key: _canvasKey,
              behavior: HitTestBehavior.opaque,
              onScaleStart: (ScaleStartDetails d) {
                if (_drawMode) return;
                _startHandleDrag(d.localFocalPoint, size);
              },
              onScaleUpdate: (ScaleUpdateDetails d) {
                if (_drawMode) return;
                if (_drag != null && _drag!.id != _HandleId.none) {
                  _updateHandleDrag(d, size);
                } else {
                  _viewZoom = (_viewZoom * d.scale).clamp(0.5, 4.0);
                  _viewPan = _viewPan + d.focalPointDelta;
                  setState(() {});
                }
              },
              onScaleEnd: (_) {
                _finishHandleDrag();
              },
              onScaleCancel: (_) {
                _finishHandleDrag();
              },
              onPanStart: _drawMode ? (details) => _strokeStart(details, size) : null,
              onPanUpdate:
                  _drawMode ? (details) => _strokeUpdate(details, size) : null,
              onPanEnd: _drawMode ? (details) => _strokeEnd(photo) : null,
              child: CustomPaint(
                painter: _PathCanvasPainter(
                  spec: spec,
                  fit: _fit,
                  vp: _viewport,
                  camera: _cameraAt(_playhead),
                  image: image,
                  viewZoom: _viewZoom,
                  viewPan: _viewPan,
                  handles: _handles(spec, size),
                  drawing: _drawMode,
                  stroke: _rawStroke,
                ),
                size: size,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        if (_drawMode)
          Text(
            l10n.t('path_draw_hint'),
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant),
          ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            IconButton.filledTonal(
              onPressed: _playing ? _pause : _play,
              icon: Icon(_playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
              tooltip: l10n.t('motion_play'),
            ),
            Expanded(
              child: Slider(
                value: _playhead.clamp(0.0, _duration),
                min: 0,
                max: _duration,
                onChanged: (double v) {
                  if (_playing) _pause();
                  setState(() => _playhead = v);
                },
              ),
            ),
            Text('${_playhead.toStringAsFixed(1)}s',
                style: context.theme.textTheme.labelMedium),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------- handles
  List<({_HandleId id, int index, Offset screen, String label})> _handles(
      MotionPathSpec spec, Size size) {
    final out = <({_HandleId id, int index, Offset screen, String label})>[];
    final cx = spec.centerX;
    final cy = spec.centerY;
    final usesRadii = spec.preset != 'linear' &&
        spec.preset != 'cubicBezier' &&
        spec.preset != 'sCurve' &&
        spec.preset != 'custom';
    out.add((
        id: _HandleId.center,
        index: 0,
        screen: _toScreen(cx, cy, size),
        label: ''));
    if (usesRadii) {
      out.add((
          id: _HandleId.radiusX,
          index: 0,
          screen: _toScreen(cx + spec.radiusX, cy, size),
          label: ''));
      out.add((
          id: _HandleId.radiusY,
          index: 0,
          screen: _toScreen(cx, cy + spec.radiusY, size),
          label: ''));
      // start-angle handle sits at P(0) of the polar curve
      if (startAngleApplies(spec.preset)) {
        final start = rawPathPoint(spec, 0.0);
        if ((start.x - cx).abs() > 1e-6 || (start.y - cy).abs() > 1e-6) {
          out.add((
              id: _HandleId.startAngle,
              index: 0,
              screen: _toScreen(start.x, start.y, size),
              label: ''));
        }
      }
    }
    if (spec.preset == 'linear' ||
        spec.preset == 'cubicBezier' ||
        spec.preset == 'sCurve' ||
        spec.preset == 'custom') {
      for (var i = 0; i < spec.points.length; i++) {
        final p = spec.points[i];
        out.add((
            id: _HandleId.point,
            index: i,
            screen: _toScreen(p.x, p.y, size),
            label: '${i + 1}'));
      }
    }
    return out;
  }

  void _startHandleDrag(Offset local, Size size) {
    final spec = _spec;
    if (spec == null) return;
    final handles = _handles(spec, size);
    const r = 22.0;
    for (final h in handles) {
      if ((h.screen - local).distance <= r) {
        // Where the handle lives in camera space...
        Offset cam;
        switch (h.id) {
          case _HandleId.center:
            cam = Offset(spec.centerX, spec.centerY);
          case _HandleId.radiusX:
            cam = Offset(spec.centerX + spec.radiusX, spec.centerY);
          case _HandleId.radiusY:
            cam = Offset(spec.centerX, spec.centerY + spec.radiusY);
          case _HandleId.startAngle:
            final s = rawPathPoint(spec, 0.0);
            cam = Offset(s.x, s.y);
          case _HandleId.point:
            final p = spec.points[h.index];
            cam = Offset(p.x, p.y);
          case _HandleId.none:
            continue;
        }
        // ...and how far the finger was from it.
        final finger = _toCamera(local, size);
        _drag = _DragState(
          id: h.id,
          index: h.index,
          grabOffset: Offset(finger.dx - cam.dx, finger.dy - cam.dy),
        );
        _dragCommitted = false;
        HapticFeedback.selectionClick();
        return;
      }
    }
  }

  void _updateHandleDrag(ScaleUpdateDetails d, Size size) {
    final drag = _drag;
    if (drag == null) return;
    // Finger in camera space, shifted by the grab offset: the handle keeps
    // its distance to the finger and follows it 1:1 from where it was
    // grabbed (view zoom included).
    final finger = _toCamera(d.localFocalPoint, size);
    final cam = Offset(
        finger.dx - drag.grabOffset.dx, finger.dy - drag.grabOffset.dy);
    _edit((spec) {
      final m = _margin;
      final x = cam.dx.clamp(-m.mx, m.mx);
      final y = cam.dy.clamp(-m.my, m.my);
      switch (drag.id) {
        case _HandleId.center:
          return spec.copyWith(centerX: x, centerY: y, isUserEdited: true);
        case _HandleId.radiusX:
          final rx = (x - spec.centerX).abs().clamp(0.0, m.mx);
          return spec.copyWith(radiusX: rx, isUserEdited: true);
        case _HandleId.radiusY:
          final ry = (y - spec.centerY).abs().clamp(0.0, m.my);
          return spec.copyWith(radiusY: ry, isUserEdited: true);
        case _HandleId.startAngle:
          final ang = math.atan2(y - spec.centerY, x - spec.centerX);
          return spec.copyWith(startAngle: ang, isUserEdited: true);
        case _HandleId.point:
          final pts = List<MotionPoint>.of(spec.points);
          if (drag.index < pts.length) {
            pts[drag.index] = MotionPoint(x: x, y: y);
          }
          return spec.copyWith(points: pts, isUserEdited: true);
        case _HandleId.none:
          return spec;
      }
    }, record: !_dragCommitted); // one undo step per gesture
    _dragCommitted = true;
    setState(() {});
  }

  void _finishHandleDrag() {
    _drag = null;
    _dragCommitted = false;
  }

  // ------------------------------------------------------------- freehand
  void _strokeStart(DragStartDetails details, Size size) {
    setState(() {
      _rawStroke
        ..clear()
        ..add(_toCamera(details.localPosition, size));
    });
  }

  void _strokeUpdate(DragUpdateDetails details, Size size) {
    final cam = _toCamera(details.localPosition, size);
    final last = _rawStroke.isNotEmpty ? _rawStroke.last : null;
    if (last != null && (last - cam).distance < 2.0 / _k(size) / _viewZoom) {
      return; // min distance in canvas px
    }
    setState(() => _rawStroke.add(cam));
  }

  void _strokeEnd(PhotoItem photo) {
    final raw = List<Offset>.of(_rawStroke);
    _rawStroke.clear();
    setState(() => _drawMode = false);
    if (raw.length < 2) return;
    final smoothed = smoothStroke(
      raw.map((o) => MotionPoint(x: o.dx, y: o.dy)).toList(),
    );
    if (smoothed.length < 2) return;
    final spec = _spec;
    if (spec == null) return;
    _write(
      spec.copyWith(
        preset: 'custom',
        points: smoothed,
        isCustom: true,
        isUserEdited: true,
      ),
      record: true,
    );
    context.snack(context.l10n.t('path_draw_saved'));
  }

  // -------------------------------------------------------------- controls
  Widget _controls(
      BuildContext context, L10n l10n, PhotoItem photo, MotionPathSpec spec) {
    final fit = _fit;
    final m = _margin;
    final sMin = minScaleAtRotation(
        fit, _viewport, math.max(spec.startRotation.abs(),
            spec.endRotation.abs())) *
        AppLimits.minScalePad;
    final usesRadii = spec.preset != 'linear' &&
        spec.preset != 'cubicBezier' &&
        spec.preset != 'sCurve' &&
        spec.preset != 'custom';
    final hasPoints = spec.preset == 'linear' ||
        spec.preset == 'cubicBezier' ||
        spec.preset == 'sCurve' ||
        spec.preset == 'custom';

    final zMin = math.max(1.0, sMin);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: l10n.t('path_preset'),
          icon: Icons.travel_explore_rounded,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final p in MotionPathPreset.values)
                ChoiceChip(
                  label: Text(l10n.t(MotionPathPreset.labelKey(p))),
                  selected: spec.preset == p,
                  onSelected: (_) => _applyPreset(p, spec),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.s12),
        SectionCard(
          title: l10n.t('path_geometry'),
          icon: Icons.architecture_rounded,
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: ValueSlider(
                      label: l10n.t('path_center_x'),
                      value: m.mx > 1e-9
                          ? (spec.centerX / m.mx).clamp(-1.0, 1.0)
                          : 0.0,
                      min: -1,
                      max: 1,
                      format: (double v) => '${(v * 100).round()}%',
                      onChanged: (double v) => _edit((s) => s.copyWith(
                          centerX: v * m.mx, isUserEdited: true)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ValueSlider(
                      label: l10n.t('path_center_y'),
                      value: m.my > 1e-9
                          ? (spec.centerY / m.my).clamp(-1.0, 1.0)
                          : 0.0,
                      min: -1,
                      max: 1,
                      format: (double v) => '${(v * 100).round()}%',
                      onChanged: (double v) => _edit((s) => s.copyWith(
                          centerY: v * m.my, isUserEdited: true)),
                    ),
                  ),
                ],
              ),
              if (usesRadii) ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ValueSlider(
                        label: l10n.t('path_radius_x'),
                        value: m.mx > 1e-9
                            ? (spec.radiusX / m.mx).clamp(0.0, 1.0)
                            : 0.0,
                        min: 0,
                        max: 1,
                        format: (double v) => '${(v * 100).round()}%',
                        onChanged: (double v) => _edit((s) => s.copyWith(
                            radiusX: v * m.mx, isUserEdited: true)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ValueSlider(
                        label: l10n.t('path_radius_y'),
                        value: m.my > 1e-9
                            ? (spec.radiusY / m.my).clamp(0.0, 1.0)
                            : 0.0,
                        min: 0,
                        max: 1,
                        format: (double v) => '${(v * 100).round()}%',
                        onChanged: (double v) => _edit((s) => s.copyWith(
                            radiusY: v * m.my, isUserEdited: true)),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ValueSlider(
                        label: l10n.t('path_turns'),
                        value: spec.turns.clamp(0.25, 3.0),
                        min: 0.25,
                        max: 3,
                        divisions: 11,
                        format: (double v) => v.toStringAsFixed(2),
                        onChanged: (double v) =>
                            _edit((s) => s.copyWith(turns: v, isUserEdited: true)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (startAngleApplies(spec.preset))
                      Expanded(
                        child: ValueSlider(
                          label: l10n.t('path_start_angle'),
                          value: (spec.startAngle * 180 / math.pi).clamp(-180.0, 180.0),
                          min: -180,
                          max: 180,
                          divisions: 180,
                          format: (double v) => '${v.round()}°',
                          onChanged: (double v) => _edit((s) => s.copyWith(
                              startAngle: v * math.pi / 180, isUserEdited: true)),
                        ),
                      ),
                  ],
                ),
                if (spec.preset == 'arc')
                  ValueSlider(
                    label: l10n.t('path_sweep'),
                    value: (spec.sweep * 180 / math.pi).clamp(10.0, 360.0),
                    min: 10,
                    max: 360,
                    divisions: 35,
                    format: (double v) => '${v.round()}°',
                    onChanged: (double v) => _edit((s) => s.copyWith(
                        sweep: v * math.pi / 180, isUserEdited: true)),
                  ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ValueSlider(
                        label: l10n.t('path_curvature'),
                        value: spec.curvature.clamp(0.0, 1.0),
                        min: 0,
                        max: 1,
                        format: (double v) => '${(v * 100).round()}%',
                        onChanged: (double v) => _edit(
                            (s) => s.copyWith(curvature: v, isUserEdited: true)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SegmentedButton<int>(
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment<int>(
                              value: -1,
                              label: Text('CW'),
                              icon: Icons.refresh_rounded),
                          ButtonSegment<int>(
                              value: 1,
                              label: Text('CCW'),
                              icon: Icons.refresh_rounded),
                        ],
                        selected: {spec.direction == -1 ? -1 : 1},
                        onSelectionChanged: (s) => _edit(
                            (sp) => sp.copyWith(
                                direction: s.first, isUserEdited: true)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.s12),
        SectionCard(
          title: l10n.t('path_motion'),
          icon: Icons.speed_rounded,
          child: Column(
            children: <Widget>[
              ValueSlider(
                label: l10n.t('motion_speed'),
                value: spec.speed.clamp(0.25, 3.0),
                min: 0.25,
                max: 3,
                divisions: 23,
                format: (double v) => '${v.toStringAsFixed(2)}×',
                onChanged: (double v) =>
                    _edit((s) => s.copyWith(speed: v, isUserEdited: true)),
              ),
              ValueSlider(
                label: l10n.t('path_speed_ease'),
                value: spec.speedEase.clamp(0.0, 1.0),
                min: 0,
                max: 1,
                format: (double v) => '${(v * 100).round()}%',
                onChanged: (double v) =>
                    _edit((s) => s.copyWith(speedEase: v, isUserEdited: true)),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ValueSlider(
                      label: l10n.t('path_start_zoom'),
                      value: spec.startZoom.clamp(zMin, 4.0),
                      min: zMin,
                      max: 4.0,
                      format: (double v) => '${v.toStringAsFixed(2)}×',
                      onChanged: (double v) => _edit(
                          (s) => s.copyWith(startZoom: v, isUserEdited: true)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ValueSlider(
                      label: l10n.t('path_end_zoom'),
                      value: spec.endZoom.clamp(zMin, 4.0),
                      min: zMin,
                      max: 4.0,
                      format: (double v) => '${v.toStringAsFixed(2)}×',
                      onChanged: (double v) => _edit(
                          (s) => s.copyWith(endZoom: v, isUserEdited: true)),
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ValueSlider(
                      label: l10n.t('path_start_rotation'),
                      value: (spec.startRotation * 180 / math.pi).clamp(-8.0, 8.0),
                      min: -8,
                      max: 8,
                      divisions: 80,
                      format: (double v) => '${v.toStringAsFixed(1)}°',
                      onChanged: (double v) => _edit((s) => s.copyWith(
                          startRotation: v * math.pi / 180, isUserEdited: true)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ValueSlider(
                      label: l10n.t('path_end_rotation'),
                      value: (spec.endRotation * 180 / math.pi).clamp(-8.0, 8.0),
                      min: -8,
                      max: 8,
                      divisions: 80,
                      format: (double v) => '${v.toStringAsFixed(1)}°',
                      onChanged: (double v) => _edit((s) => s.copyWith(
                          endRotation: v * math.pi / 180, isUserEdited: true)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.s12),
        if (hasPoints && spec.points.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.s12),
            child: SectionCard(
              title: l10n.t('path_points'),
              icon: Icons.scatter_plot_rounded,
              child: Column(
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (var i = 0; i < spec.points.length; i++)
                        InputChip(
                          avatar: Text('${i + 1}'),
                          label: Text(
                              '${spec.points[i].x.toStringAsFixed(2)}, '
                              '${spec.points[i].y.toStringAsFixed(2)}'),
                          onDeleted: spec.points.length > 2
                              ? () => _removePoint(spec, i)
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      if (spec.preset == 'sCurve' ||
                          spec.preset == 'custom')
                        OutlinedButton.icon(
                          onPressed: () => _addPoint(spec),
                          icon: const Icon(Icons.add_location_alt_rounded,
                              size: 18),
                          label: Text(l10n.t('path_add_point')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => setState(() => _drawMode = !_drawMode),
              icon: Icon(_drawMode
                  ? Icons.stop_rounded
                  : Icons.draw_rounded),
              label: Text(_drawMode
                  ? l10n.t('path_draw_stop')
                  : l10n.t('path_draw')),
            ),
            OutlinedButton.icon(
              onPressed: () => _resetPath(spec),
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: Text(l10n.t('path_reset')),
            ),
            if (photo.motion?.path != null)
              OutlinedButton.icon(
                onPressed: () => _clearPath(photo),
                icon: const Icon(Icons.highlight_off_rounded, size: 18),
                label: Text(l10n.t('path_clear')),
              ),
          ],
        ),
      ],
    );
  }

  void _applyPreset(String preset, MotionPathSpec spec) {
    // Preset change is an explicit user edit of the path.
    _edit((s) => s.copyWith(preset: preset, isUserEdited: true), record: true);
  }

  void _addPoint(MotionPathSpec spec) {
    final s = _spec;
    if (s == null) return;
    final lut = buildArcLut(s);
    final progress = (_playhead / _duration).clamp(0.0, 1.0);
    final u = paramAtArc(s, lut, progress * lut.total);
    final pt = rawPathPoint(s, u);
    final m = _margin;
    final pts = List<MotionPoint>.of(s.points);
    pts.add(MotionPoint(
        x: pt.x.clamp(-m.mx, m.mx), y: pt.y.clamp(-m.my, m.my)));
    _edit((sp) => sp.copyWith(points: pts, isUserEdited: true), record: true);
  }

  void _removePoint(MotionPathSpec spec, int index) {
    _edit((s) {
      final pts = List<MotionPoint>.of(s.points);
      if (index < pts.length) pts.removeAt(index);
      return s.copyWith(points: pts, isUserEdited: true);
    }, record: true);
  }

  void _resetPath(MotionPathSpec spec) {
    _write(
      defaultPathFor(_photo!, _viewport)
          .copyWith(preset: spec.preset, isUserEdited: true),
      record: true,
    );
    context.snack(context.l10n.t('path_reset_done'));
  }

  void _clearPath(PhotoItem photo) {
    final m = photo.motion;
    if (m == null) return;
    _pending = null;
    ref.read(projectEditorProvider.notifier).setMotionPath(photo.id, null);
    context.snack(context.l10n.t('path_cleared'));
  }

  void _onMenu(String value, L10n l10n, PhotoItem photo) {
    switch (value) {
      case 'reset':
        final spec = _spec;
        if (spec != null) _resetPath(spec);
      case 'draw':
        setState(() => _drawMode = !_drawMode);
    }
  }
}

// ---------------------------------------------------------------------------
// painter
// ---------------------------------------------------------------------------

class _PathCanvasPainter extends CustomPainter {
  _PathCanvasPainter({
    required this.spec,
    required this.fit,
    required this.vp,
    required this.camera,
    required this.image,
    required this.viewZoom,
    required this.viewPan,
    required this.handles,
    required this.drawing,
    required this.stroke,
  });

  final MotionPathSpec spec;
  final ImageFit fit;
  final Viewport vp;
  final CameraState camera;
  final ui.Image? image;
  final double viewZoom;
  final Offset viewPan;
  final List<({_HandleId id, int index, Offset screen, String label})> handles;
  final bool drawing;
  final List<Offset> stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    final k = math.min(size.width / (2 * fit.iw), size.height / (2 * fit.ih));
    Offset toScreen(double x, double y) {
      var sx = size.width / 2 + x * k;
      var sy = size.height / 2 - y * k;
      sx = (sx - size.width / 2) * viewZoom + size.width / 2 + viewPan.dx;
      sy = (sy - size.height / 2) * viewZoom + size.height / 2 + viewPan.dy;
      return Offset(sx, sy);
    }

    // The photo, contain-fitted (map view).
    if (image != null) {
      final r = Rect.fromPoints(toScreen(-fit.iw, fit.ih),
          toScreen(fit.iw, -fit.ih));
      canvas.drawImageRect(
        image!,
        Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
        r,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    // Valid image bounds (crop / safe area): everything outside can never be
    // shown, and the path must stay inside.
    final bounds = Path()
      ..moveTo(toScreen(-fit.iw, -fit.ih).dx, toScreen(-fit.iw, -fit.ih).dy)
      ..lineTo(toScreen(fit.iw, -fit.ih).dx, toScreen(fit.iw, -fit.ih).dy)
      ..lineTo(toScreen(fit.iw, fit.ih).dx, toScreen(fit.iw, fit.ih).dy)
      ..lineTo(toScreen(-fit.iw, fit.ih).dx, toScreen(-fit.iw, fit.ih).dy)
      ..close();
    canvas.drawPath(
        bounds,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF4DD0E1).withValues(alpha: 0.9));

    // The motion path: uniform-arc polyline of the raw trajectory.
    final lut = buildArcLut(spec);
    const steps = 240;
    final pathPts = <Offset>[
      for (var j = 0; j <= steps; j++)
        toScreen(..._rawAt(spec, lut, j / steps)),
    ];
    if (pathPts.length > 1) {
      final path = Path()..moveTo(pathPts.first.dx, pathPts.first.dy);
      for (final p in pathPts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = const Color(0xFFFFB74D).withValues(alpha: 0.95));
    }

    // Direction arrows at fixed arc fractions.
    for (final frac in const <double>[0.15, 0.35, 0.55, 0.75]) {
      final u = paramAtArc(spec, lut, frac * lut.total);
      final pos = toScreen(..._rawAt(spec, lut, frac));
      final tan = pathTangent(spec, u);
      final dir = Offset(tan.x, -tan.y); // y down on screen
      final dl = dir.distance;
      if (dl < 1e-9) continue;
      final d = dir / dl;
      const s = 9.0;
      final tip = pos + d * s;
      final l = pos - d * s * 0.6 + Offset(-d.dy, d.dx) * s * 0.7;
      final r = pos - d * s * 0.6 - Offset(-d.dy, d.dx) * s * 0.7;
      canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(l.dx, l.dy)
            ..lineTo(r.dx, r.dy)
            ..close(),
          Paint()..color = const Color(0xFFFFB74D));
    }

    // Start / end markers.
    final startP = toScreen(..._rawAt(spec, lut, 0.0));
    final endP = toScreen(..._rawAt(spec, lut, 1.0));
    canvas.drawCircle(startP, 8, Paint()..color = const Color(0xFF66BB6A));
    canvas.drawCircle(startP, 11, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white);
    if ((endP - startP).distance > 14) {
      canvas.drawCircle(endP, 8, Paint()..color = const Color(0xFFFFA726));
      canvas.drawCircle(endP, 11, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white);
    }

    // Camera frame at the playhead (the visible output frame).
    final corners = viewportCorners(camera, vp)
        .map((c) => toScreen(c.x, c.y))
        .toList();
    final camPath = Path()
      ..moveTo(corners[0].dx, corners[0].dy);
    for (final c in corners.skip(1)) {
      camPath.lineTo(c.dx, c.dy);
    }
    camPath.close();
    canvas.drawPath(
        camPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.95));
    for (final c in corners) {
      canvas.drawCircle(c, 3, Paint()..color = Colors.white);
    }

    // Live freehand stroke.
    if (drawing && stroke.length > 1) {
      final sp = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        sp.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          sp, Paint()..style = PaintingStyle.stroke..strokeWidth = 2
              ..color = const Color(0xFFEF5350));
    }

    // Draggable handles.
    for (final h in handles) {
      final rect = Rect.fromCenter(center: h.screen, width: 22, height: 22);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect, const Radius.circular(5)),
          Paint()
            ..color = const Color(0xFF29B6F6)
            ..style = PaintingStyle.fill);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect, const Radius.circular(5)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_PathCanvasPainter old) =>
      old.spec != spec ||
      old.camera != camera ||
      old.image != image ||
      old.viewZoom != viewZoom ||
      old.viewPan != viewPan ||
      old.drawing != drawing ||
      old.stroke.length != stroke.length;
}

/// Raw path point at arc fraction [p] (0..1).
(double, double) _rawAt(MotionPathSpec spec, MotionPathLut lut, double p) {
  final u = paramAtArc(spec, lut, p * lut.total);
  final pt = rawPathPoint(spec, u);
  return (pt.x, pt.y);
}
