import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'motion_profile.dart';
import 'transition.dart';

/// One photo on the timeline.
///
/// The original file is never copied or modified: we keep a stable content URI
/// plus the intrinsic size, and a thumbnail file for the UI (brief §14).
@immutable
class PhotoItem {
  const PhotoItem({
    required this.id,
    required this.sourceUri,
    required this.width,
    required this.height,
    this.duration = AppLimits.defaultPhotoDuration,
    this.order = 0,
    this.motion,
    this.transition = const TransitionSpec(),
    this.displayName = '',
    this.thumbnailPath,
    this.missing = false,
    this.rotationDegrees = 0,
  });

  final String id;

  /// `content://` URI with persisted read permission, or a file path.
  final String sourceUri;

  /// Intrinsic size of the EXIF-corrected image.
  final int width;
  final int height;

  /// Full display window on the timeline, including transition overlap.
  final double duration;
  final int order;
  final MotionProfile? motion;
  final TransitionSpec transition;
  final String displayName;
  final String? thumbnailPath;

  /// True when the source file could not be opened (deleted / permission lost).
  final bool missing;

  /// User-applied extra rotation (0/90/180/270) on top of EXIF.
  final int rotationDegrees;

  double get aspect => height == 0 ? 1.0 : width / height;

  bool get hasMotion => motion != null;

  bool get isLocked => motion?.isLocked ?? false;

  PhotoItem copyWith({
    String? id,
    String? sourceUri,
    int? width,
    int? height,
    double? duration,
    int? order,
    MotionProfile? motion,
    TransitionSpec? transition,
    String? displayName,
    String? thumbnailPath,
    bool? missing,
    int? rotationDegrees,
  }) =>
      PhotoItem(
        id: id ?? this.id,
        sourceUri: sourceUri ?? this.sourceUri,
        width: width ?? this.width,
        height: height ?? this.height,
        duration: duration ?? this.duration,
        order: order ?? this.order,
        motion: motion ?? this.motion,
        transition: transition ?? this.transition,
        displayName: displayName ?? this.displayName,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        missing: missing ?? this.missing,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sourceUri': sourceUri,
        'width': width,
        'height': height,
        'duration': duration,
        'order': order,
        'motionProfile': motion?.toJson(),
        'transitionProfile': transition.toJson(),
        'displayName': displayName,
        'thumbnailPath': thumbnailPath,
        'rotationDegrees': rotationDegrees,
      };

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    final motionJson = json['motionProfile'];
    return PhotoItem(
      id: json['id'] as String,
      sourceUri: json['sourceUri'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      duration: (json['duration'] as num?)?.toDouble() ??
          AppLimits.defaultPhotoDuration,
      order: (json['order'] as num?)?.toInt() ?? 0,
      motion: motionJson == null
          ? null
          : MotionProfile.fromJson(Map<String, dynamic>.from(motionJson as Map)),
      transition: json['transitionProfile'] == null
          ? const TransitionSpec()
          : TransitionSpec.fromJson(
              Map<String, dynamic>.from(json['transitionProfile'] as Map)),
      displayName: json['displayName'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String?,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toInt() ?? 0,
    );
  }
}
