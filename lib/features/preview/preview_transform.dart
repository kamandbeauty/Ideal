/// Transform maths for the in-app preview painter.
///
/// Single responsibility: convert a camera state into the exact `Matrix4` that
/// Flutter must apply so the on-screen frame matches the native renderer's
/// `layer_affine` (see tools/validate/motionshot/renderer.py and
/// android/.../RenderEngine.kt). Preview and export therefore agree by
/// construction, not by eye.
///
/// Domain convention:
///   * `previewMatrix` maps the **unit image rect** `(u,v) in [0,1]²`
///     (u right, v down) to **output pixels** — that is what `Canvas.drawImageRect`
///     with a transform needs.
///   * `screenToImage` is the inverse, used by gestures and hit testing.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';

import '../motion/camera_math.dart';

/// Maps the unit image rect to output pixels for one camera state.
///
/// Spec §7.1: `q = c + R(-r)·n/scale`, so forward:
///   n   = scale · R(r) · (q - c)
///   out = outCenter + (n.x/kx, n.y/ky)
/// where `kx = vw/outW`, `ky = vh/outH`, and `q` comes from the uv coordinate.
Matrix4 previewMatrix({
  required CameraState cam,
  required ImageFit fit,
  required Viewport vp,
  required Size outputSize,
  double zoomMultiplier = 1.0,
  double offsetX = 0.0,
  double offsetY = 0.0,
}) {
  final scale = cam.scale * zoomMultiplier;
  if (scale <= 0 || outputSize.width <= 0 || outputSize.height <= 0) {
    return Matrix4.identity();
  }
  final cosR = math.cos(cam.rotation);
  final sinR = math.sin(cam.rotation);

  // viewport units per output pixel
  final kx = vp.vw / outputSize.width;
  final ky = vp.vh / outputSize.height;

  // uv -> image space, then scale, then rotate, then to pixels
  final m00 = scale * cosR * (2 * fit.iw) / kx;
  final m01 = -scale * sinR * (2 * fit.ih) / kx;
  final m10 = scale * sinR * (2 * fit.iw) / ky;
  final m11 = scale * cosR * (2 * fit.ih) / ky;

  final ox = outputSize.width / 2;
  final oy = outputSize.height / 2;

  // Constant term: camera centre and the (0.5, 0.5) image centre, plus the
  // transition slide expressed in viewport widths/heights.
  final shiftPxX = offsetX * vp.vw / kx;
  final shiftPxY = offsetY * vp.vh / ky;
  final t0 = ox +
      shiftPxX +
      scale * (-cosR * cam.x + sinR * cam.y) / kx -
      (m00 + m01) * 0.5;
  final t1 = oy +
      shiftPxY +
      scale * (-sinR * cam.x - cosR * cam.y) / ky -
      (m10 + m11) * 0.5;

  return Matrix4.fromList(<double>[
    m00, m10, 0, 0, //
    m01, m11, 0, 0, //
    0, 0, 1, 0, //
    t0, t1, 0, 1, //
  ]);
}

/// `Float64List` form ready for `Canvas.transform`.
Float64List previewMatrixStorage({
  required CameraState cam,
  required ImageFit fit,
  required Viewport vp,
  required Size outputSize,
  double zoomMultiplier = 1.0,
  double offsetX = 0.0,
  double offsetY = 0.0,
}) =>
    previewMatrix(
      cam: cam,
      fit: fit,
      vp: vp,
      outputSize: outputSize,
      zoomMultiplier: zoomMultiplier,
      offsetX: offsetX,
      offsetY: offsetY,
    ).storage;

/// Inverse map: output pixels -> normalized image coordinates `(u, v)`.
///
/// Used by gesture editing to know which part of the photo is under the finger.
({double u, double v}) screenToImage({
  required Offset point,
  required Size outputSize,
  required CameraState cam,
  required ImageFit fit,
  required Viewport vp,
  double zoomMultiplier = 1.0,
  double offsetX = 0.0,
  double offsetY = 0.0,
}) {
  final scale = cam.scale * zoomMultiplier;
  if (scale <= 0) return (u: 0.5, v: 0.5);
  final cosR = math.cos(cam.rotation);
  final sinR = math.sin(cam.rotation);
  final kx = vp.vw / outputSize.width;
  final ky = vp.vh / outputSize.height;

  final nx = (point.dx - outputSize.width / 2 - offsetX * vp.vw / kx) * kx;
  final ny = (point.dy - outputSize.height / 2 - offsetY * vp.vh / ky) * ky;

  // n = scale·R(r)·(q - c)  =>  q = c + R(-r)·n/scale
  final inv = 1 / scale;
  final qx = cam.x + (cosR * nx + sinR * ny) * inv;
  final qy = cam.y + (-sinR * nx + cosR * ny) * inv;
  return (u: 0.5 + qx / (2 * fit.iw), v: 0.5 + qy / (2 * fit.ih));
}

/// Converts a finger drag (in pixels) into a camera delta.
///
/// Dragging right must move the image right, which means moving the camera
/// left in image space. Rotation is compensated so the gesture always follows
/// the finger, even on a rotated shot.
({double dx, double dy}) screenDeltaToCamera({
  required Offset deltaPx,
  required Size outputSize,
  required CameraState cam,
  required Viewport vp,
  double zoomMultiplier = 1.0,
}) {
  final scale = cam.scale * zoomMultiplier <= 0
      ? 1.0
      : cam.scale * zoomMultiplier;
  final kx = vp.vw / outputSize.width;
  final ky = vp.vh / outputSize.height;
  final cosR = math.cos(cam.rotation);
  final sinR = math.sin(cam.rotation);
  final nx = -deltaPx.dx * kx;
  final ny = -deltaPx.dy * ky;
  final inv = 1 / scale;
  return (
    dx: (cosR * nx + sinR * ny) * inv,
    dy: (-sinR * nx + cosR * ny) * inv,
  );
}
