package com.motionshot.app.motion

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.pow

/**
 * Easing curves — Kotlin port of docs/MOTION_SPEC.md §2.
 *
 * Identical to `lib/core/utils/easing.dart`; conformance is checked by the JVM
 * tests against `tools/validate/motionshot/golden/easing.json`.
 */
enum class Easing {
    LINEAR, EASE_IN, EASE_OUT, EASE_IN_OUT, SMOOTH, SMOOTHER, CUSTOM;

    companion object {
        /** Parses the JSON `easing` field; unknown values fall back to SMOOTHER. */
        @JvmStatic
        fun parse(name: String?): Easing = when (name) {
            "linear" -> LINEAR
            "easeIn" -> EASE_IN
            "easeOut" -> EASE_OUT
            "easeInOut" -> EASE_IN_OUT
            "smooth" -> SMOOTH
            "custom" -> CUSTOM
            else -> SMOOTHER
        }
    }
}

private const val DEFAULT_X1 = 0.42
private const val DEFAULT_Y1 = 0.0
private const val DEFAULT_X2 = 0.58
private const val DEFAULT_Y2 = 1.0

/** Maps t in [0,1] to an eased value using the given curve. */
fun ease(kind: Easing, tRaw: Double, curve: DoubleArray? = null): Double {
    val t = when {
        tRaw <= 0.0 -> 0.0
        tRaw >= 1.0 -> 1.0
        else -> tRaw
    }
    return when (kind) {
        Easing.LINEAR -> t
        Easing.EASE_IN -> t * t
        Easing.EASE_OUT -> 1.0 - (1.0 - t) * (1.0 - t)
        Easing.EASE_IN_OUT ->
            if (t < 0.5) 2.0 * t * t else 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
        Easing.SMOOTH -> t * t * (3.0 - 2.0 * t)
        Easing.SMOOTHER -> t * t * t * (t * (6.0 * t - 15.0) + 10.0)
        Easing.CUSTOM -> {
            val c = curve ?: doubleArrayOf(DEFAULT_X1, DEFAULT_Y1, DEFAULT_X2, DEFAULT_Y2)
            cubicBezier(
                c.getOrElse(0) { DEFAULT_X1 },
                c.getOrElse(1) { DEFAULT_Y1 },
                c.getOrElse(2) { DEFAULT_X2 },
                c.getOrElse(3) { DEFAULT_Y2 },
                t,
            )
        }
    }
}

/** CSS `cubic-bezier`: solve x(u) = t, return y(u). */
private fun cubicBezier(x1Raw: Double, y1: Double, x2Raw: Double, y2: Double, t: Double): Double {
    if (t <= 0.0) return 0.0
    if (t >= 1.0) return 1.0
    val x1 = x1Raw.coerceIn(0.0, 1.0)
    val x2 = x2Raw.coerceIn(0.0, 1.0)

    fun cx(u: Double): Double {
        val iu = 1.0 - u
        return 3.0 * iu * iu * u * x1 + 3.0 * iu * u * u * x2 + u * u * u
    }

    fun cy(u: Double): Double {
        val iu = 1.0 - u
        return 3.0 * iu * iu * u * y1 + 3.0 * iu * u * u * y2 + u * u * u
    }

    fun dx(u: Double): Double {
        val iu = 1.0 - u
        return 3.0 * iu * iu * x1 + 6.0 * iu * u * (x2 - x1) + 3.0 * u * u * (1.0 - x2)
    }

    var u = t
    var newtonOk = true
    for (i in 0 until 8) {
        val err = cx(u) - t
        if (abs(err) < 1e-9) return cy(u)
        val d = dx(u)
        if (abs(d) < 1e-9) {
            newtonOk = false
            break
        }
        u -= err / d
        if (u < 0.0 || u > 1.0) {
            newtonOk = false
            break
        }
    }
    if (newtonOk) return cy(u)

    var lo = 0.0
    var hi = 1.0
    u = t
    for (i in 0 until 60) {
        val v = cx(u)
        if (abs(v - t) < 1e-12) break
        if (v < t) lo = u else hi = u
        u = (lo + hi) / 2.0
    }
    return cy(u)
}

/** One camera keyframe (spec §3). */
data class Keyframe(
    val time: Double,
    val x: Double,
    val y: Double,
    val scale: Double,
    val rotation: Double = 0.0,
    val easing: Easing = Easing.SMOOTHER,
    val curve: DoubleArray? = null,
) {
    // data class with an array needs explicit equals/hashCode
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Keyframe) return false
        return time == other.time && x == other.x && y == other.y &&
            scale == other.scale && rotation == other.rotation &&
            easing == other.easing && (curve?.contentEquals(other.curve) ?: (other.curve == null))
    }

    override fun hashCode(): Int {
        var result = time.hashCode()
        result = 31 * result + x.hashCode()
        result = 31 * result + y.hashCode()
        result = 31 * result + scale.hashCode()
        result = 31 * result + rotation.hashCode()
        result = 31 * result + easing.hashCode()
        result = 31 * result + (curve?.contentHashCode() ?: 0)
        return result
    }
}

/** Sorts and validates a keyframe list, mirroring the Dart parser. */
fun sortAndValidateKeyframes(input: List<Keyframe>): List<Keyframe> {
    require(input.size >= 2) { "a motion profile needs at least 2 keyframes" }
    val kfs = input.sortedBy { it.time }
    for (i in 1 until kfs.size) {
        require(kfs[i].time - kfs[i - 1].time >= 1e-3) {
            "keyframes must be at least 1ms apart"
        }
    }
    kfs.forEach { require(it.scale > 0.0) { "keyframe scale must be > 0" } }
    return kfs
}

/** Samples the camera at local time `t` (spec §3.1). */
fun sampleKeyframes(kfs: List<Keyframe>, t: Double): CameraState {
    require(kfs.isNotEmpty()) { "empty keyframe list" }
    if (kfs.size == 1 || t <= kfs.first().time) {
        val k = kfs.first()
        return CameraState(k.x, k.y, k.scale, k.rotation)
    }
    if (t >= kfs.last().time) {
        val k = kfs.last()
        return CameraState(k.x, k.y, k.scale, k.rotation)
    }
    var lo = 0
    var hi = kfs.size - 1
    while (lo + 1 < hi) {
        val mid = (lo + hi) / 2
        if (kfs[mid].time <= t) lo = mid else hi = mid
    }
    val a = kfs[lo]
    val b = kfs[hi]
    val dt = b.time - a.time
    if (dt <= 1e-9) return CameraState(b.x, b.y, b.scale, b.rotation)
    val u = (t - a.time) / dt
    val e = ease(a.easing, u, a.curve)
    return CameraState(
        x = lerp(a.x, b.x, e),
        y = lerp(a.y, b.y, e),
        scale = logLerp(a.scale, b.scale, e),
        rotation = a.rotation + shortestAngle(a.rotation, b.rotation) * e,
    )
}

/** Full sampling pipeline: sample then clamp inside the image. */
fun sampleClamped(
    kfs: List<Keyframe>,
    localTime: Double,
    fit: ImageFit,
    vp: Viewport,
): CameraState = clampCamera(sampleKeyframes(kfs, localTime), fit, vp)

/** `2 * PI` convenience for rotation sliders. */
val TWO_PI: Double = 2.0 * PI

/** Utility used by the encoder ETA display. */
fun framesFor(durationSeconds: Double, fps: Int): Int =
    Math.round(durationSeconds * fps).toInt().coerceAtLeast(1)

/** Pow helper kept for readability in tests. */
fun pow2(v: Double): Double = v.pow(2.0)
