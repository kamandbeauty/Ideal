/// Camera math — Dart port of docs/MOTION_SPEC.md §1, §3.2, §4, §5.
///
/// This is the *same* math the Kotlin renderer uses, so the preview and the
/// exported MP4 can never disagree about framing.
library;

import 'dart:math' as math;
import 'dart:ui' show Size;

/// Normalized viewport: shorter side is 1.0 (spec §1.2).
class Viewport {
  const Viewport(this.aspect);

  final double aspect;

  double get vw => aspect >= 1 ? aspect : 1.0;
  double get vh => aspect >= 1 ? 1.0 : 1.0 / aspect;

  static double aspectOf(Size size) =>
      size.height == 0 ? 1.0 : size.width / size.height;
}

/// Cover-fit of a source image inside the viewport (spec §1.4).
class ImageFit {
  const ImageFit({required this.iw, required this.ih});

  /// Half width / half height of the image in normalized units.
  final double iw;
  final double ih;

  factory ImageFit.make(int srcW, int srcH, Viewport vp) {
    if (srcW <= 0 || srcH <= 0) {
      throw ArgumentError('image dimensions must be positive');
    }
    final cover = math.max(vp.vw / srcW, vp.vh / srcH);
    return ImageFit(iw: srcW * cover / 2.0, ih: srcH * cover / 2.0);
  }

  /// Aspect ratio of the source image.
  double get aspect => iw / ih;
}

/// Camera state sampled from a motion profile.
class CameraState {
  const CameraState({
    this.x = 0.0,
    this.y = 0.0,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  /// Camera center offset from the image center, normalized units.
  final double x;
  final double y;

  /// Zoom factor, 1.0 = exact cover fit.
  final double scale;

  /// Clockwise rotation of the image inside the viewport, radians.
  final double rotation;

  CameraState copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) =>
      CameraState(
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
      );

  List<double> toJson() => <double>[x, y, scale, rotation];

  @override
  String toString() => 'CameraState(x: ${x.toStringAsFixed(5)}, '
      'y: ${y.toStringAsFixed(5)}, scale: ${scale.toStringAsFixed(5)}, '
      'rot: ${(rotation * 180 / math.pi).toStringAsFixed(3)}deg)';

  @override
  bool operator ==(Object other) =>
      other is CameraState &&
      other.x == x &&
      other.y == y &&
      other.scale == scale &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(x, y, scale, rotation);
}

/// Visible viewport half-extents in normalized image units (spec §1.3).
({double bw, double bh}) halfExtent(
    Viewport vp, double scale, double rotation) {
  final s = scale <= 0 ? 1e-6 : scale;
  final hw = vp.vw / (2.0 * s);
  final hh = vp.vh / (2.0 * s);
  if (rotation == 0.0) return (bw: hw, bh: hh);
  final c = math.cos(rotation).abs();
  final sn = math.sin(rotation).abs();
  return (bw: hw * c + hh * sn, bh: hw * sn + hh * c);
}

/// Smallest scale that still covers the viewport at this rotation (§4).
double minScaleAtRotation(ImageFit fit, Viewport vp, double rotation) {
  final c = math.cos(rotation).abs();
  final s = math.sin(rotation).abs();
  final sx = (vp.vw * c + vp.vh * s) / (2.0 * fit.iw);
  final sy = (vp.vw * s + vp.vh * c) / (2.0 * fit.ih);
  return math.max(sx, sy);
}

/// Largest legal camera offset from center at this scale/rotation (§5).
({double mx, double my}) maxPan(
    ImageFit fit, Viewport vp, double scale, double rotation) {
  final e = halfExtent(vp, scale, rotation);
  return (mx: math.max(0.0, fit.iw - e.bw), my: math.max(0.0, fit.ih - e.bh));
}

/// Guarantee the viewport never reveals pixels outside the image (§3.2).
CameraState clampCamera(CameraState state, ImageFit fit, Viewport vp) {
  if (state.scale <= 0) {
    throw ArgumentError('scale must be > 0');
  }
  final e = halfExtent(vp, state.scale, state.rotation);
  double x;
  double y;
  if (e.bw >= fit.iw) {
    x = 0.0;
  } else {
    x = state.x.clamp(-fit.iw + e.bw, fit.iw - e.bw);
  }
  if (e.bh >= fit.ih) {
    y = 0.0;
  } else {
    y = state.y.clamp(-fit.ih + e.bh, fit.ih - e.bh);
  }
  return CameraState(
      x: x, y: y, scale: state.scale, rotation: state.rotation);
}

/// Normalized image coordinate (origin at image center) -> texture UV.
///
/// `y` is *down-positive*, matching `screenToImage` and the renderer: the top
/// of the image maps to `v = 0`, the bottom to `v = 1`. (An earlier y-up sign
/// mirrored the safe frame and the camera-path trail vertically for any
/// off-centre or rotated camera.)
({double u, double v}) imageToUv(double x, double y, ImageFit fit) =>
    (u: 0.5 + x / (2 * fit.iw), v: 0.5 + y / (2 * fit.ih));

/// Texture UV -> normalized image coordinate (inverse of [imageToUv]).
({double x, double y}) uvToImage(double u, double v, ImageFit fit) =>
    (x: (u - 0.5) * 2 * fit.iw, y: (v - 0.5) * 2 * fit.ih);

/// The four corners of the visible area, in normalized image space.
///
/// Inverse of the renderer transform (spec §7.1): `q = c + R(-r) * v / scale`
/// where `v` is the offset from the viewport center in *view* units. Corner
/// order: TL, TR, BR, BL (in view space, y down), which lets the editor draw
/// the output frame, the crop bounds and the motion path with one call.
List<({double x, double y})> viewportCorners(CameraState cam, Viewport vp) {
  if (cam.scale <= 0) return const <({double x, double y})>[];
  final hw = vp.vw / (2.0 * cam.scale);
  final hh = vp.vh / (2.0 * cam.scale);
  final cosR = math.cos(cam.rotation);
  final sinR = math.sin(cam.rotation);
  final local = <({double x, double y})>[
    (x: -hw, y: -hh),
    (x: hw, y: -hh),
    (x: hw, y: hh),
    (x: -hw, y: hh),
  ];
  return local
      .map((p) => (
            x: cam.x + p.x * cosR + p.y * sinR,
            y: cam.y - p.x * sinR + p.y * cosR,
          ))
      .toList(growable: false);
}
