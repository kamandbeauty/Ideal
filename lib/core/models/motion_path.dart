/// Motion Path Engine data model — docs/MOTION_SPEC.md §12.
///
/// A [MotionPathSpec] describes a parametric camera trajectory (one of ten
/// presets, or a freehand drawn stroke) plus the zoom / rotation envelope
/// applied while travelling it. It is persisted inside a [MotionProfile]
/// (`path` field) and restored from the project file.
///
/// The JSON keys are part of the project-file and export-request contract
/// and must match `MotionPathSpec.to_json` in
/// `tools/validate/motionshot/motion_path.py` and `MotionPathSpec` in
/// `android/.../motion/MotionPathEngine.kt`.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A point in normalized camera space (spec §1.2), used for path waypoints
/// and control points.
@immutable
class MotionPoint {
  const MotionPoint({required this.x, required this.y});

  final double x;
  final double y;

  MotionPoint copyWith({double? x, double? y}) =>
      MotionPoint(x: x ?? this.x, y: y ?? this.y);

  Map<String, dynamic> toJson() => <String, dynamic>{'x': x, 'y': y};

  factory MotionPoint.fromJson(Map<dynamic, dynamic> json) => MotionPoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is MotionPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'MotionPoint(${x.toStringAsFixed(4)}, '
      '${y.toStringAsFixed(4)})';
}

/// The ten motion path presets (spec §12.1). The ids are persisted and must
/// match `PATH_PRESETS` in the Python reference and `MotionPathPreset` in
/// Kotlin.
@immutable
class MotionPathPreset {
  const MotionPathPreset._();

  static const List<String> values = <String>[
    'linear', // 1 straight pan A -> B
    'circularCw', // 2 full circle, clockwise on screen
    'circularCcw', // 3 full circle, counter-clockwise on screen
    'elliptical', // 4 full ellipse
    'spiral', // 5 Archimedean spiral
    'sCurve', // 6 Catmull-Rom through 3..n waypoints
    'figureEight', // 7 closed Lissajous figure eight
    'arc', // 8 partial circle (sweep < 2*pi)
    'cubicBezier', // 9 cubic Bezier with two control points
    'custom', // 10 freehand drawn, smoothed stroke
  ];

  static bool isValid(String? id) => id != null && values.contains(id);

  /// Human readable label key for localization.
  static String labelKey(String id) => 'motion_path_$id';
}

/// One persisted camera path (spec §12.1).
///
/// * direction: `1` = counter-clockwise on screen, `-1` = clockwise.
/// * points: waypoints / control points, per preset:
///   linear = 2 endpoints (optional), cubicBezier = 4 (P0,P1c,P2c,P3),
///   sCurve = 3..n waypoints, custom = the smoothed stroke.
@immutable
class MotionPathSpec {
  const MotionPathSpec({
    required this.preset,
    this.centerX = 0.0,
    this.centerY = 0.0,
    this.radiusX = 0.25,
    this.radiusY = 0.25,
    this.turns = 1.0,
    this.startAngle = -1.5707963267948966, // -pi/2
    this.sweep = 6.283185307179586, // 2*pi
    this.curvature = 0.5,
    this.speed = 1.0,
    this.speedEase = 0.0,
    this.startZoom = 1.15,
    this.endZoom = 1.30,
    this.startRotation = 0.0,
    this.endRotation = 0.0,
    this.direction = 1,
    this.points = const <MotionPoint>[],
    this.isCustom = false,
    this.isUserEdited = false,
  });

  final String preset;
  final double centerX;
  final double centerY;

  /// Horizontal / vertical radius of the path envelope (normalized units).
  final double radiusX;
  final double radiusY;

  /// Number of turns. figureEight snaps to int 1..3 (closed C1 seam).
  final double turns;

  /// Starting angle (radians, +x axis, y up).
  final double startAngle;

  /// Arc sweep in radians (only `arc`; others use 2*pi*turns).
  final double sweep;

  /// 0..1: S-curve bend / spiral tightness.
  final double curvature;

  /// Path progress per clip (0.25..3). > 1 finishes early and holds.
  final double speed;

  /// 0..1: blend from constant speed (0) to a smootherstep velocity profile
  /// (1) — the controllable speed profile (spec §12.6).
  final double speedEase;

  /// Zoom envelope along the path (log-interpolated, spec §3.1).
  final double startZoom;
  final double endZoom;

  /// Rotation envelope along the path (radians, shortest arc).
  final double startRotation;
  final double endRotation;

  /// +1 counter-clockwise, -1 clockwise (on screen).
  final int direction;

  final List<MotionPoint> points;

  /// True when the user drew this path with the finger.
  final bool isCustom;

  /// True when the user edited any path field. Such paths are protected
  /// from Randomize unless the user explicitly requests a re-roll.
  final bool isUserEdited;

  /// True for paths Randomize must never silently replace.
  bool get isProtected => isCustom || isUserEdited;

  MotionPathSpec copyWith({
    String? preset,
    double? centerX,
    double? centerY,
    double? radiusX,
    double? radiusY,
    double? turns,
    double? startAngle,
    double? sweep,
    double? curvature,
    double? speed,
    double? speedEase,
    double? startZoom,
    double? endZoom,
    double? startRotation,
    double? endRotation,
    int? direction,
    List<MotionPoint>? points,
    bool? isCustom,
    bool? isUserEdited,
  }) =>
      MotionPathSpec(
        preset: preset ?? this.preset,
        centerX: centerX ?? this.centerX,
        centerY: centerY ?? this.centerY,
        radiusX: radiusX ?? this.radiusX,
        radiusY: radiusY ?? this.radiusY,
        turns: turns ?? this.turns,
        startAngle: startAngle ?? this.startAngle,
        sweep: sweep ?? this.sweep,
        curvature: curvature ?? this.curvature,
        speed: speed ?? this.speed,
        speedEase: speedEase ?? this.speedEase,
        startZoom: startZoom ?? this.startZoom,
        endZoom: endZoom ?? this.endZoom,
        startRotation: startRotation ?? this.startRotation,
        endRotation: endRotation ?? this.endRotation,
        direction: direction ?? this.direction,
        points: points ?? this.points,
        isCustom: isCustom ?? this.isCustom,
        isUserEdited: isUserEdited ?? this.isUserEdited,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'preset': preset,
        'centerX': centerX,
        'centerY': centerY,
        'radiusX': radiusX,
        'radiusY': radiusY,
        'turns': turns,
        'startAngle': startAngle,
        'sweep': sweep,
        'curvature': curvature,
        'speed': speed,
        'speedEase': speedEase,
        'startZoom': startZoom,
        'endZoom': endZoom,
        'startRotation': startRotation,
        'endRotation': endRotation,
        'direction': direction,
        'points': points.map((p) => p.toJson()).toList(growable: false),
        'isCustom': isCustom,
        'isUserEdited': isUserEdited,
      };

  /// Throws [FormatException] for unknown preset data; the loader then falls
  /// back to the baked keyframes (lenient load, spec §12.1).
  factory MotionPathSpec.fromJson(Map<dynamic, dynamic> json) {
    final preset = json['preset'] as String?;
    if (!MotionPathPreset.isValid(preset)) {
      throw FormatException('unknown motion path preset: $preset');
    }
    final rawPoints = (json['points'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => MotionPoint.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList(growable: false);
    return MotionPathSpec(
      preset: preset,
      centerX: (json['centerX'] as num?)?.toDouble() ?? 0.0,
      centerY: (json['centerY'] as num?)?.toDouble() ?? 0.0,
      radiusX: (json['radiusX'] as num?)?.toDouble() ?? 0.25,
      radiusY: (json['radiusY'] as num?)?.toDouble() ?? 0.25,
      turns: (json['turns'] as num?)?.toDouble() ?? 1.0,
      startAngle: (json['startAngle'] as num?)?.toDouble() ?? -math.pi / 2,
      sweep: (json['sweep'] as num?)?.toDouble() ?? 2 * math.pi,
      curvature: (json['curvature'] as num?)?.toDouble() ?? 0.5,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      speedEase: (json['speedEase'] as num?)?.toDouble() ?? 0.0,
      startZoom: (json['startZoom'] as num?)?.toDouble() ?? 1.15,
      endZoom: (json['endZoom'] as num?)?.toDouble() ?? 1.30,
      startRotation: (json['startRotation'] as num?)?.toDouble() ?? 0.0,
      endRotation: (json['endRotation'] as num?)?.toDouble() ?? 0.0,
      direction: (json['direction'] as num?)?.toInt() ?? 1,
      points: rawPoints,
      isCustom: json['isCustom'] as bool? ?? false,
      isUserEdited: json['isUserEdited'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'MotionPathSpec($preset, '
      'r=(${radiusX.toStringAsFixed(3)},${radiusY.toStringAsFixed(3)}), '
      '${points.length} pts)';
}
