import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../utils/easing.dart';

/// A single camera keyframe (docs/MOTION_SPEC.md §3).
@immutable
class Keyframe {
  const Keyframe({
    required this.time,
    required this.x,
    required this.y,
    required this.scale,
    this.rotation = 0.0,
    this.easing = Easing.smoother,
    this.curve,
  });

  /// Seconds from the start of this photo's segment.
  final double time;

  /// Camera center in normalized image space (spec §1.2).
  final double x;
  final double y;

  /// Zoom factor, always >= 1.0.
  final double scale;

  /// Clockwise rotation, radians.
  final double rotation;

  /// Easing of the segment that *starts* at this keyframe.
  final Easing easing;

  /// Control points for [Easing.custom].
  final List<double>? curve;

  Keyframe copyWith({
    double? time,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    Easing? easing,
    List<double>? curve,
  }) =>
      Keyframe(
        time: time ?? this.time,
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        easing: easing ?? this.easing,
        curve: curve ?? this.curve,
      );

  /// Moves the camera fields only, keeping time/easing identity.
  Keyframe withCamera({double? x, double? y, double? scale, double? rotation}) =>
      copyWith(x: x, y: y, scale: scale, rotation: rotation);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': time,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'easing': easing.name,
        if (curve != null) 'curve': curve,
      };

  factory Keyframe.fromJson(Map<String, dynamic> json) => Keyframe(
        time: (json['time'] as num).toDouble(),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        scale: (json['scale'] as num).toDouble(),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        easing: Easing.parse(json['easing'] as String?),
        curve: (json['curve'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(growable: false),
      );

  double get rotationDegrees => rotation * 180 / math.pi;

  bool approxEquals(Keyframe other, {double tol = 1e-9}) =>
      (time - other.time).abs() <= tol &&
      (x - other.x).abs() <= tol &&
      (y - other.y).abs() <= tol &&
      (scale - other.scale).abs() <= tol &&
      (rotation - other.rotation).abs() <= tol &&
      easing == other.easing;

  @override
  bool operator ==(Object other) =>
      other is Keyframe && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => Object.hash(time, x, y, scale, rotation, easing);
}
