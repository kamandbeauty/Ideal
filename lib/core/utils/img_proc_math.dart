/// Image/transform helpers that must agree with the native renderer.
library;

import 'dart:math' as math;

import '../models/keyframe.dart';
import '../../features/motion/camera_math.dart';

/// The 2D transform that maps image space to viewport space for a camera
/// state, expressed as a column-major 4x4 matrix ready for `Matrix4`.
///
/// Derivation is docs/MOTION_SPEC.md §7.1: the image is rotated by `+rotation`,
/// scaled by `2*scale/viewportShortSide`, and translated by the camera center.
/// Columns are laid out as `[m00, m01, 0, 0, m10, m11, 0, 0, ...]`.
List<double> cameraMatrix(CameraState cam, ImageFit fit, Viewport vp) {
  final cosR = math.cos(cam.rotation);
  final sinR = math.sin(cam.rotation);
  // From normalized image space to NDC.
  final sx = 2 * cam.scale / vp.vw;
  final sy = 2 * cam.scale / vp.vh;
  // Rotate (clockwise) then flip y for NDC.
  final m00 = cosR * sx;
  final m01 = -sinR * sx;
  final m10 = -sinR * sy;
  final m11 = -cosR * sy;
  // Translation uses the camera center in the same normalized space.
  final tx = -cam.x * m00 - cam.y * m10;
  final ty = -cam.x * m01 - cam.y * m11;
  return <double>[
    m00, m10, 0, 0, //
    m01, m11, 0, 0, //
    0, 0, 1, 0, //
    tx, ty, 0, 1, //
  ];
}

/// Scale that must be applied to a `BoxFit.cover` sized image so that the
/// camera zoom matches the exported frame exactly.
double previewCoverScale({
  required int imageWidth,
  required int imageHeight,
  required double viewportAspect,
}) {
  final imageAspect = imageWidth / imageHeight;
  // cover: the image is scaled so both dimensions are >= the viewport.
  return imageAspect > viewportAspect
      ? imageAspect / viewportAspect
      : 1.0;
}

/// Maps a camera keyframe to the `alignment` values Flutter's [Transform]
/// needs (`Alignment` is in [-1, 1] of the *child* box).
({double ax, double ay}) cameraToAlignment(CameraState cam, ImageFit fit) =>
    (ax: cam.x / fit.iw, ay: cam.y / fit.ih);

/// Clamps a keyframe to the legal area; returns the corrected keyframe plus a
/// boolean telling the editor whether it had to intervene.
({Keyframe keyframe, bool corrected}) clampKeyframe(
  Keyframe k,
  ImageFit fit,
  Viewport vp, {
  double pad = 1.002,
}) {
  final sMin = minScaleAtRotation(fit, vp, k.rotation) * pad;
  final scale = math.max(k.scale, sMin);
  final st = clampCamera(
      CameraState(x: k.x, y: k.y, scale: scale, rotation: k.rotation), fit, vp);
  final corrected = (st.x - k.x).abs() > 1e-9 ||
      (st.y - k.y).abs() > 1e-9 ||
      (st.scale - k.scale).abs() > 1e-9;
  return (
    keyframe: k.copyWith(x: st.x, y: st.y, scale: st.scale),
    corrected: corrected,
  );
}
