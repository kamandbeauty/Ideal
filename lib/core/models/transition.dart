import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// The nine transition types required for v1 (product brief §7).
enum TransitionType {
  crossDissolve('crossDissolve'),
  fade('fade'),
  fadeToBlack('fadeToBlack'),
  slideLeft('slideLeft'),
  slideRight('slideRight'),
  zoomTransition('zoomTransition'),
  blurTransition('blurTransition'),
  smoothZoom('smoothZoom'),
  none('none');

  const TransitionType(this.id);
  final String id;

  String get labelKey => 'transition_$id';

  bool get isBlackByDesign => this == TransitionType.fadeToBlack;

  static TransitionType parse(String? id) => TransitionType.values.firstWhere(
        (e) => e.id == id,
        orElse: () => TransitionType.crossDissolve,
      );
}

@immutable
class TransitionSpec {
  const TransitionSpec({
    this.type = TransitionType.crossDissolve,
    this.duration = AppLimits.defaultTransition,
  });

  final TransitionType type;
  final double duration;

  TransitionSpec copyWith({TransitionType? type, double? duration}) =>
      TransitionSpec(
        type: type ?? this.type,
        duration: (duration ?? this.duration)
            .clamp(AppLimits.minTransition, AppLimits.maxTransition),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.id,
        'duration': duration,
      };

  factory TransitionSpec.fromJson(Map<String, dynamic> json) => TransitionSpec(
        type: TransitionType.parse(json['type'] as String?),
        duration: (json['duration'] as num?)?.toDouble() ??
            AppLimits.defaultTransition,
      );

  @override
  bool operator ==(Object other) =>
      other is TransitionSpec &&
      other.type == type &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(type, duration);
}
