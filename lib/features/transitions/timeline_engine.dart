/// Timeline composition — Dart port of docs/MOTION_SPEC.md §6 and §7.2.
///
/// Shared by the preview player, the photo strip, the editor scrubbing and the
/// motion editor's "show me the previous shot" overlay. The Kotlin exporter
/// implements the same functions so seeking matches the rendered file exactly.
library;

import 'dart:math' as math;

import '../../core/models/transition.dart';

/// One photo's slot on the timeline.
class TimelineSegment {
  const TimelineSegment({
    required this.photoId,
    required this.index,
    required this.start,
    required this.duration,
    required this.transition,
  });

  final String photoId;
  final int index;
  final double start;
  final double duration;
  final TransitionSpec transition;

  double get end => start + duration;

  bool contains(double t) => t >= start && t < end;
}

/// The resolved visibility of one photo at a point in time.
class TimelineLayer {
  const TimelineLayer({
    required this.photoIndex,
    required this.localTime,
    required this.role,
    required this.progress,
    this.transitionType = TransitionType.none,
  });

  final int photoIndex;

  /// Time within this photo's own segment (drives its motion profile).
  final double localTime;

  /// `single`, `out` or `in`.
  final LayerRole role;

  /// Transition progress 0..1; 0 for a single layer.
  final double progress;

  final TransitionType transitionType;

  bool get isTransition => role != LayerRole.single;
}

enum LayerRole { single, outPhoto, inPhoto }

/// Builds segments from durations (cumulative starts — spec §6.3).
List<TimelineSegment> buildSegments(
  List<String> photoIds,
  List<double> durations,
  List<TransitionSpec> transitions,
) {
  final out = <TimelineSegment>[];
  var t = 0.0;
  for (var i = 0; i < durations.length; i++) {
    if (durations[i] <= 0) {
      throw ArgumentError('photo duration must be > 0');
    }
    out.add(TimelineSegment(
      photoId: photoIds[i],
      index: i,
      start: t,
      duration: durations[i],
      transition: i < transitions.length
          ? transitions[i]
          : const TransitionSpec(),
    ));
    t += durations[i];
  }
  return out;
}

double totalDuration(List<double> durations) =>
    durations.fold(0.0, (a, b) => a + b);

/// A transition can never consume more than either neighbour (spec §6.2).
double clampedTransitionSeconds(
  int index,
  List<double> durations,
  List<TransitionSpec> transitions,
) {
  if (index < 0 || index >= durations.length - 1) return 0.0;
  final tr = index < transitions.length
      ? transitions[index]
      : const TransitionSpec();
  if (tr.type == TransitionType.none) return 0.0;
  return math.max(0.0, math.min(tr.duration,
      math.min(durations[index], durations[index + 1])));
}

/// Which photo(s) are visible at `t` (spec §6.4).
List<TimelineLayer> resolveLayers(
  double t,
  List<double> durations,
  List<TransitionSpec> transitions,
) {
  final n = durations.length;
  if (n == 0) throw ArgumentError('empty timeline');
  final total = totalDuration(durations);
  if (t < 0) t = 0;
  if (t >= total) {
    return <TimelineLayer>[
      TimelineLayer(
        photoIndex: n - 1,
        localTime: durations[n - 1],
        role: LayerRole.single,
        progress: 1.0,
      ),
    ];
  }

  final starts = <double>[];
  var acc = 0.0;
  for (final d in durations) {
    starts.add(acc);
    acc += d;
  }

  // transition windows straddle segment boundaries
  for (var i = 0; i < n - 1; i++) {
    final d = clampedTransitionSeconds(i, durations, transitions);
    if (d <= 0) continue;
    final boundary = starts[i] + durations[i];
    final half = d / 2;
    if ((t - boundary).abs() < half) {
      final p = (t - (boundary - half)) / d;
      final outLocal =
          math.min(durations[i], math.max(0.0, t - starts[i]));
      final inLocal =
          math.min(durations[i + 1], math.max(0.0, t - starts[i + 1]));
      final type = i < transitions.length
          ? transitions[i].type
          : TransitionType.crossDissolve;
      return <TimelineLayer>[
        TimelineLayer(
          photoIndex: i,
          localTime: outLocal,
          role: LayerRole.outPhoto,
          progress: p.clamp(0.0, 1.0),
          transitionType: type,
        ),
        TimelineLayer(
          photoIndex: i + 1,
          localTime: inLocal,
          role: LayerRole.inPhoto,
          progress: p.clamp(0.0, 1.0),
          transitionType: type,
        ),
      ];
    }
  }

  var lo = 0;
  var hi = n - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (starts[mid] <= t) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  final local = math.min(durations[lo], math.max(0.0, t - starts[lo]));
  return <TimelineLayer>[
    TimelineLayer(
      photoIndex: lo,
      localTime: local,
      role: LayerRole.single,
      progress: 0.0,
    ),
  ];
}

/// Draw parameters for one layer after the transition is applied.
class DrawLayer {
  const DrawLayer({
    required this.photoIndex,
    required this.localTime,
    this.alpha = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.zoomMultiplier = 1.0,
    this.blurRadius = 0.0,
    this.freezeMotion = false,
  });

  final int photoIndex;
  final double localTime;
  final double alpha;

  /// Offset in viewport widths / heights.
  final double offsetX;
  final double offsetY;
  final double zoomMultiplier;

  /// Blur radius at a 1080p reference height.
  final double blurRadius;

  /// `fade` holds the outgoing motion at the boundary frame.
  final bool freezeMotion;
}

const double kBlurMaxRadius = 12.0;

/// Converts resolved layers into concrete draw parameters (spec §7.2).
List<DrawLayer> transitionDrawLayers(List<TimelineLayer> layers) {
  if (layers.length == 1) {
    final l = layers.first;
    return <DrawLayer>[
      DrawLayer(photoIndex: l.photoIndex, localTime: l.localTime),
    ];
  }
  final o = layers[0];
  final i = layers[1];
  final p = o.progress.clamp(0.0, 1.0);
  final tr = o.transitionType;

  var outA = 1.0;
  var inA = 0.0;
  var outOffX = 0.0;
  var inOffX = 0.0;
  var outZoom = 1.0;
  var inZoom = 1.0;
  var outBlur = 0.0;
  var inBlur = 0.0;
  var freeze = false;

  switch (tr) {
    case TransitionType.crossDissolve:
    case TransitionType.none:
      outA = 1 - p;
      inA = p;
    case TransitionType.fade:
      outA = 1 - p;
      inA = p;
      freeze = true;
    case TransitionType.fadeToBlack:
      if (p <= 0.5) {
        outA = math.max(0.0, 1 - 2 * p);
        inA = 0.0;
      } else {
        outA = 0.0;
        inA = math.min(1.0, 2 * p - 1);
      }
    case TransitionType.slideLeft:
      outA = 1;
      inA = 1;
      outOffX = -p;
      inOffX = 1 - p;
    case TransitionType.slideRight:
      outA = 1;
      inA = 1;
      outOffX = p;
      inOffX = p - 1;
    case TransitionType.zoomTransition:
      outA = 1 - p;
      inA = p;
      outZoom = 1 + 0.25 * p;
      inZoom = 0.80 + 0.20 * p;
    case TransitionType.smoothZoom:
      outA = 1 - p;
      inA = p;
      outZoom = 1 + 0.12 * p;
      inZoom = 0.94 + 0.06 * p;
    case TransitionType.blurTransition:
      outA = 1 - p;
      inA = p;
      outBlur = kBlurMaxRadius * p;
      inBlur = kBlurMaxRadius * (1 - p);
  }

  return <DrawLayer>[
    DrawLayer(
      photoIndex: o.photoIndex,
      localTime: o.localTime,
      alpha: outA,
      offsetX: outOffX,
      zoomMultiplier: outZoom,
      blurRadius: outBlur,
      freezeMotion: freeze,
    ),
    DrawLayer(
      photoIndex: i.photoIndex,
      localTime: i.localTime,
      alpha: inA,
      offsetX: inOffX,
      zoomMultiplier: inZoom,
      blurRadius: inBlur,
    ),
  ];
}

/// Convenience: which photo is "current" for editing at time `t`.
int currentPhotoIndex(
    double t, List<double> durations, List<TransitionSpec> transitions) {
  final layers = resolveLayers(t, durations, transitions);
  return layers.last.photoIndex;
}
