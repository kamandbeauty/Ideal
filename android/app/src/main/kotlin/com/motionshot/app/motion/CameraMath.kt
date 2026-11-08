package com.motionshot.app.motion

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Camera math — Kotlin port of docs/MOTION_SPEC.md §1, §3, §4, §5.
 *
 * This is the *renderer's* copy of the same maths the Dart preview uses. The
 * conformance tests in `app/src/test` replay the golden vectors produced by
 * `tools/validate` so the two implementations cannot drift silently.
 *
 * All camera state is `Double`. Never `Float`: a 4K frame is ~8000 normalized
 * units wide and float precision would show up as sub-pixel crawl.
 */

/** Normalized viewport: shorter side is 1.0 (spec §1.2). */
data class Viewport(val aspect: Double) {
    val vw: Double get() = if (aspect >= 1.0) aspect else 1.0
    val vh: Double get() = if (aspect >= 1.0) 1.0 else 1.0 / aspect
}

/** Cover-fit of a source image into the viewport (spec §1.4). */
data class ImageFit(val iw: Double, val ih: Double) {
    companion object {
        @JvmStatic
        fun make(srcW: Int, srcH: Int, vp: Viewport): ImageFit {
            require(srcW > 0 && srcH > 0) { "image dimensions must be positive" }
            val cover = max(vp.vw / srcW, vp.vh / srcH)
            return ImageFit(iw = srcW * cover / 2.0, ih = srcH * cover / 2.0)
        }
    }
}

/** Camera state sampled from a motion profile. */
data class CameraState(
    val x: Double = 0.0,
    val y: Double = 0.0,
    val scale: Double = 1.0,
    val rotation: Double = 0.0,
)

/** Visible viewport half-extents in normalized image units (spec §1.3). */
fun halfExtent(vp: Viewport, scale: Double, rotation: Double): Pair<Double, Double> {
    val s = if (scale <= 0.0) 1e-6 else scale
    val hw = vp.vw / (2.0 * s)
    val hh = vp.vh / (2.0 * s)
    if (rotation == 0.0) return hw to hh
    val c = abs(cos(rotation))
    val sn = abs(sin(rotation))
    return (hw * c + hh * sn) to (hw * sn + hh * c)
}

/** Smallest scale that still covers the viewport at this rotation (§4). */
fun minScaleAtRotation(fit: ImageFit, vp: Viewport, rotation: Double): Double {
    val c = abs(cos(rotation))
    val s = abs(sin(rotation))
    val sx = (vp.vw * c + vp.vh * s) / (2.0 * fit.iw)
    val sy = (vp.vw * s + vp.vh * c) / (2.0 * fit.ih)
    return max(sx, sy)
}

/** Largest legal camera offset from center at this scale/rotation (§5). */
fun maxPan(fit: ImageFit, vp: Viewport, scale: Double, rotation: Double): Pair<Double, Double> {
    val (bw, bh) = halfExtent(vp, scale, rotation)
    return max(0.0, fit.iw - bw) to max(0.0, fit.ih - bh)
}

/** Guarantee the viewport never reveals pixels outside the image (§3.2). */
fun clampCamera(state: CameraState, fit: ImageFit, vp: Viewport): CameraState {
    require(state.scale > 0.0) { "scale must be > 0" }
    val (bw, bh) = halfExtent(vp, state.scale, state.rotation)
    val x = if (bw >= fit.iw) 0.0 else state.x.coerceIn(-fit.iw + bw, fit.iw - bw)
    val y = if (bh >= fit.ih) 0.0 else state.y.coerceIn(-fit.ih + bh, fit.ih - bh)
    return state.copy(x = x, y = y)
}

/** Image point (normalized, origin at image center) -> texture UV. */
fun imageToUv(x: Double, y: Double, fit: ImageFit): Pair<Double, Double> =
    (0.5 + x / (2.0 * fit.iw)) to (0.5 - y / (2.0 * fit.ih))

/** Perceptually uniform zoom interpolation (§3.1). */
fun logLerp(a: Double, b: Double, t: Double): Double {
    if (a <= 0.0 || b <= 0.0) return a + (b - a) * t
    return exp(ln(a) + (ln(b) - ln(a)) * t)
}

/** Shortest signed angular distance (§3.1). */
fun shortestAngle(a: Double, b: Double): Double {
    var d = (b - a) % (2 * Math.PI)
    if (d > Math.PI) d -= 2 * Math.PI
    if (d < -Math.PI) d += 2 * Math.PI
    return d
}

/**
 * The 4x4 matrix that maps a unit image quad (0..1 in u,v) to clip space, for
 * the given camera and viewport. Column-major, ready for `glUniformMatrix4fv`
 * with `transpose = false`.
 *
 * Spec §7.1. Kept here (not in the renderer) so it can be unit tested on the
 * JVM without a GL context.
 */
fun cameraMatrix(cam: CameraState, fit: ImageFit, vp: Viewport): FloatArray {
    val cosR = cos(cam.rotation)
    val sinR = sin(cam.rotation)
    val s = cam.scale
    // uv -> viewport units, scaled and rotated, then to NDC [-1,1].
    // At scale = 1 a cover-fitted image (fit.iw = vw/2 in the covering
    // dimension) spans NDC [-1, 1] exactly, with the bitmap's top row at
    // the top of the frame — the same convention as the Dart preview
    // matrix and the Python reference (spec §7.1). The y row is negative
    // because NDC is y-up while image rows are y-down.
    val m00 = s * cosR * (2.0 * fit.iw) / (vp.vw / 2.0)
    val m01 = -s * sinR * (2.0 * fit.ih) / (vp.vw / 2.0)
    val m10 = -s * sinR * (2.0 * fit.iw) / (vp.vh / 2.0)
    val m11 = -s * cosR * (2.0 * fit.ih) / (vp.vh / 2.0)
    // Constant term
    val t0 = -s * (cosR * cam.x - sinR * cam.y) / (vp.vw / 2.0) - (m00 + m01) * 0.5
    val t1 = s * (sinR * cam.x + cosR * cam.y) / (vp.vh / 2.0) - (m10 + m11) * 0.5
    return floatArrayOf(
        m00.toFloat(), m10.toFloat(), 0f, 0f,
        m01.toFloat(), m11.toFloat(), 0f, 0f,
        0f, 0f, 1f, 0f,
        t0.toFloat(), t1.toFloat(), 0f, 1f,
    )
}

/** Linear interpolation helper used by the keyframe engine. */
fun lerp(a: Double, b: Double, t: Double): Double = a + (b - a) * t

/** Clamp helper matching the Dart/Python `clamp` semantics used by tests. */
fun clamp(v: Double, lo: Double, hi: Double): Double = if (hi < lo) (lo + hi) / 2.0 else min(max(v, lo), hi)

/** Even-dimension rounding required by 4:2:0 chroma (spec §8.1). */
fun roundEven(v: Int): Int = max(2, (v / 2) * 2)

/** Canonical bitrate formula (spec §8.2), matching Dart and Python bit for bit. */
fun deriveBitrate(
    outW: Int,
    outH: Int,
    fps: Int,
    quality: String,
    codec: String,
    custom: Int = 0,
): Int {
    if (quality == "custom" && custom > 0) {
        return custom.coerceIn(1_500_000, 100_000_000)
    }
    val bpp = when (quality) {
        "standard" -> 0.10
        "maximum" -> 0.24
        else -> 0.16
    }
    val hevc = if (codec == "hevc") 0.70 else 1.0
    val raw = (outW.toDouble() * outH.toDouble() * fps.toDouble() * bpp * hevc).toInt()
    return raw.coerceIn(1_500_000, 100_000_000)
}
