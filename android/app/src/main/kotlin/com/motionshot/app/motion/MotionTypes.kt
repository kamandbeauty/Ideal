package com.motionshot.app.motion

/**
 * The fifteen motion types and the deterministic auto-motion engine.
 *
 * Port of docs/MOTION_SPEC.md §10 and `tools/validate/motionshot/profile.py`.
 * Ids are part of the JSON contract; never rename them.
 */
enum class MotionType(val id: String) {
    ZOOM_IN("zoomIn"),
    ZOOM_OUT("zoomOut"),
    PAN_LEFT("panLeft"),
    PAN_RIGHT("panRight"),
    PAN_UP("panUp"),
    PAN_DOWN("panDown"),
    DIAGONAL_LEFT("diagonalLeft"),
    DIAGONAL_RIGHT("diagonalRight"),
    SLOW_PUSH("slowPush"),
    PULL_BACK("pullBack"),
    ZOOM_PAN("zoomPan"),
    SUBTLE_ROTATION("subtleRotation"),
    DRIFT("drift"),
    CENTER_TO_CORNER("centerToCorner"),
    COMBINED("combined");

    companion object {
        @JvmStatic
        fun parse(id: String?): MotionType =
            values().firstOrNull { it.id == id } ?: ZOOM_IN
    }
}

/** A motion profile as stored in the project document. */
data class MotionProfileData(
    val motionType: MotionType,
    val intensity: Double,
    val keyframes: List<Keyframe>,
    val seed: Long = 0L,
) {
    fun durationSeconds(): Double = keyframes.lastOrNull()?.time ?: 0.0
}

/** A generated curved-path motion (spec §12.7). */
data class PathMotionProfile(
    val motionType: MotionType,
    val intensity: Double,
    val keyframes: List<Keyframe>,
    val seed: Long,
    val path: MotionPathSpec,
) {
    fun durationSeconds(): Double = keyframes.lastOrNull()?.time ?: 0.0
}

/**
 * Deterministic helpers. The renderer does not normally generate motion (the
 * app does), but it needs the same seed derivation for verification and for the
 * instrumentation tests that replay a golden project.
 */
object RandomMotion {
    private const val FNV_OFFSET = -3750763034362895579L // 0xCBF29CE484222325
    private const val FNV_PRIME = 1099511628211L

    /** FNV-1a 64-bit over UTF-8 bytes. */
    @JvmStatic
    fun fnv1a64(text: String): Long {
        var h = FNV_OFFSET
        val bytes = text.toByteArray(Charsets.UTF_8)
        for (b in bytes) {
            h = h xor (b.toLong() and 0xFF)
            h *= FNV_PRIME
        }
        return h
    }

    /** SplitMix64 (state, value). */
    @JvmStatic
    fun splitMix64(stateIn: Long): Pair<Long, Long> {
        var state = stateIn + -7046029254386353131L // 0x9E3779B97F4A7C15
        var z = state
        z = (z xor (z ushr 30)) * -4658895280553007687L // 0xBF58476D1CE4E5B9
        z = (z xor (z ushr 27)) * -7723592293110705685L // 0x94D049BB133111EB
        return state to (z xor (z ushr 31))
    }

    /** Per-photo seed derivation. */
    @JvmStatic
    fun photoSeed(projectSeed: Long, photoId: String, index: Int): Long =
        projectSeed xor fnv1a64(photoId) xor ((index + 1).toLong() * -7046029254386353131L)
}

/** xorshift128+, bit-identical to the Dart and Python implementations. */
class Xorshift128Plus(seed: Long) {
    private var s0: Long
    private var s1: Long

    init {
        var state = seed
        val r1 = RandomMotion.splitMix64(state)
        state = r1.first
        var v0 = r1.second
        val r2 = RandomMotion.splitMix64(state)
        var v1 = r2.second
        if (v0 == 0L && v1 == 0L) v0 = -7046029254386353131L
        s0 = v0
        s1 = v1
    }

    /**
     * Raw 64-bit draw — xorshift128+ as in the reference (`mathx.next_u64`).
     *
     * `s0` becomes the old `s1`; the new state is the xorshift of the old
     * `s0`. Getting this order wrong still produces plausible-looking random
     * numbers, but then no cross-language golden vector would match.
     */
    fun nextU64(): Long {
        val old0 = s0
        val old1 = s1
        s0 = old1
        var x = old0
        x = x xor (x shl 23)
        x = x xor (x ushr 17)
        x = x xor old1
        x = x xor (old1 ushr 26)
        s1 = x
        return s0 + s1
    }

    /** Uniform double in [0,1) from the top 53 bits. */
    fun nextDouble(): Double = (nextU64() ushr 11) * (1.0 / 9007199254740992.0)

    fun range(lo: Double, hi: Double): Double = lo + (hi - lo) * nextDouble()

    /**
     * Uniform int in [lo, hi] inclusive. The draw is an *unsigned* 64-bit
     * modulo (the raw state is unsigned); `remainderUnsigned` matches the
     * Dart (`BigInt.toUnsigned(64) % n`) and Python ports bit for bit.
     */
    fun irange(lo: Int, hiInclusive: Int): Int {
        val n = (hiInclusive - lo + 1).toLong()
        // unsigned remainder as a stdlib extension (not a companion method)
        return lo + nextU64().remainderUnsigned(n).toInt()
    }

    fun bool(pTrue: Double = 0.5): Boolean = nextDouble() < pTrue

    fun sign(): Int = if (nextU64() and 1L == 1L) 1 else -1
}

/**
 * Rebuilds a profile for a photo from the same inputs the Flutter side uses.
 *
 * Used by `ExportVerifier` and the instrumentation tests: given a project the
 * renderer can prove that regenerating motion would produce the stored
 * keyframes, i.e. that a project is reproducible from its seed.
 */
object MotionGenerator {

    @JvmStatic
    fun pickMotionType(rng: Xorshift128Plus, previous: MotionType?): MotionType {
        var pool = MotionType.values().toMutableList()
        if (previous != null && pool.size > 1) {
            pool = pool.filter { it != previous }.toMutableList()
        }
        val weights = pool.map { weightOf(it) }
        val total = weights.sum()
        val r = rng.nextDouble() * total
        var acc = 0.0
        for (i in pool.indices) {
            acc += weights[i]
            if (r <= acc) return pool[i]
        }
        return pool.last()
    }

    private fun weightOf(t: MotionType): Double = when (t) {
        MotionType.ZOOM_IN -> 1.4
        MotionType.ZOOM_OUT -> 1.2
        MotionType.PAN_LEFT, MotionType.PAN_RIGHT -> 1.0
        MotionType.PAN_UP, MotionType.PAN_DOWN -> 0.9
        MotionType.DIAGONAL_LEFT, MotionType.DIAGONAL_RIGHT -> 0.8
        MotionType.SLOW_PUSH -> 1.1
        MotionType.PULL_BACK -> 1.0
        MotionType.ZOOM_PAN -> 1.2
        MotionType.SUBTLE_ROTATION -> 0.45
        MotionType.DRIFT -> 0.5
        MotionType.CENTER_TO_CORNER -> 0.8
        MotionType.COMBINED -> 1.0
    }

    private const val SCALE_PAD = 1.002

    private fun clip(state: CameraState, fit: ImageFit, vp: Viewport): CameraState {
        val sMin = minScaleAtRotation(fit, vp, state.rotation) * SCALE_PAD
        val scale = maxOf(state.scale, sMin)
        return clampCamera(state.copy(scale = scale), fit, vp)
    }

    private fun kf(t: Double, st: CameraState, e: Easing = Easing.SMOOTHER) =
        Keyframe(time = t, x = st.x, y = st.y, scale = st.scale, rotation = st.rotation, easing = e)

    /**
     * Generates a legal cinematic motion. Mirror of `generate_profile` in the
     * Python reference; the two are compared by the conformance tests.
     */
    @JvmStatic
    fun generate(
        type: MotionType,
        intensityIn: Double,
        duration: Double,
        fit: ImageFit,
        vp: Viewport,
        rng: Xorshift128Plus,
        seed: Long,
    ): MotionProfileData {
        require(duration > 0.0) { "duration must be positive" }
        val i = intensityIn.coerceIn(0.0, 1.0)
        val base = 1.04 + 0.10 * i
        val kfs = ArrayList<Keyframe>(3)
        val rad = Math.PI / 180.0

        when (type) {
            MotionType.ZOOM_IN -> {
                val s0 = base
                val s1 = base * (1.16 + 0.26 * i)
                val dx = rng.range(-0.05, 0.05) * 0.2
                val dy = rng.range(-0.05, 0.05) * 0.2
                kfs += kf(0.0, clip(CameraState(dx, dy, s0), fit, vp))
                kfs += kf(duration, clip(CameraState(dx, dy, s1), fit, vp))
            }
            MotionType.ZOOM_OUT -> {
                val s1 = base
                val s0 = base * (1.16 + 0.26 * i)
                val dx = rng.range(-0.1, 0.1) * 0.2
                val dy = rng.range(-0.1, 0.1) * 0.2
                kfs += kf(0.0, clip(CameraState(dx, dy, s0), fit, vp))
                kfs += kf(duration, clip(CameraState(dx, dy, s1), fit, vp))
            }
            MotionType.PAN_LEFT, MotionType.PAN_RIGHT, MotionType.PAN_UP, MotionType.PAN_DOWN -> {
                val s = base * (1.18 + 0.20 * i)
                val (mx, my) = maxPan(fit, vp, s, 0.0)
                val travel = 0.75 + 0.20 * i
                // Draw order matters: it must match the reference exactly.
                val jitter = rng.range(-0.15, 0.15)
                val endZoom = rng.range(1.0, 1.05)
                val a: CameraState
                val b: CameraState
                when (type) {
                    MotionType.PAN_LEFT -> {
                        a = CameraState(mx * travel, jitter * my, s)
                        b = CameraState(-mx * travel, a.y, s * endZoom)
                    }
                    MotionType.PAN_RIGHT -> {
                        a = CameraState(-mx * travel, jitter * my, s)
                        b = CameraState(mx * travel, a.y, s * endZoom)
                    }
                    MotionType.PAN_UP -> {
                        a = CameraState(jitter * mx, my * travel, s)
                        b = CameraState(a.x, -my * travel, s * endZoom)
                    }
                    else -> {
                        a = CameraState(jitter * mx, -my * travel, s)
                        b = CameraState(a.x, my * travel, s * endZoom)
                    }
                }
                kfs += kf(0.0, clip(a, fit, vp))
                kfs += kf(duration, clip(b, fit, vp))
            }
            MotionType.DIAGONAL_LEFT, MotionType.DIAGONAL_RIGHT -> {
                val s = base * (1.22 + 0.22 * i)
                val (mx, my) = maxPan(fit, vp, s, 0.0)
                val travel = 0.75 + 0.20 * i
                val sx = if (type == MotionType.DIAGONAL_RIGHT) 1 else -1
                val sy = rng.sign()
                val a = CameraState(-sx * mx * travel, -sy * my * travel * 0.8, s)
                val b = CameraState(sx * mx * travel, sy * my * travel * 0.8, s * 1.06)
                kfs += kf(0.0, clip(a, fit, vp))
                kfs += kf(duration, clip(b, fit, vp))
            }
            MotionType.SLOW_PUSH, MotionType.PULL_BACK -> {
                val sLo = 1.02 + 0.03 * i
                val sHi = sLo * (1.10 + 0.10 * i)
                val s0 = if (type == MotionType.SLOW_PUSH) sLo else sHi
                val s1 = if (type == MotionType.SLOW_PUSH) sHi else sLo
                val dx = rng.range(-0.12, 0.12)
                val dy = rng.range(-0.12, 0.12)
                kfs += kf(0.0, clip(CameraState(dx, dy, s0), fit, vp))
                kfs += kf(duration, clip(CameraState(-dx * 0.5, -dy * 0.5, s1), fit, vp))
            }
            MotionType.ZOOM_PAN -> {
                val s0 = base * 1.02
                val s1 = base * (1.22 + 0.24 * i)
                val sMid = maxOf(s0, s1)
                val (mx, my) = maxPan(fit, vp, sMid, 0.0)
                val sx = rng.sign()
                val sy = rng.sign()
                val a = CameraState(-sx * mx * 0.6, -sy * my * 0.6, s0)
                val b = CameraState(sx * mx * 0.6, sy * my * 0.6, s1)
                kfs += kf(0.0, clip(a, fit, vp))
                kfs += kf(duration, clip(b, fit, vp))
            }
            MotionType.SUBTLE_ROTATION -> {
                val deg = (0.8 + 1.4 * i) * rng.sign()
                val r1 = deg * rad
                val s = maxOf(1.10 + 0.08 * i, minScaleAtRotation(fit, vp, kotlin.math.abs(r1)) * 1.02)
                val (mx, my) = maxPan(fit, vp, s, r1)
                val a = CameraState(-mx * 0.15, -my * 0.15, s, 0.0)
                val b = CameraState(mx * 0.15, my * 0.15, s * 1.03, r1)
                kfs += kf(0.0, clip(a, fit, vp))
                kfs += kf(duration, clip(b, fit, vp))
            }
            MotionType.DRIFT -> {
                val s = 1.06 + 0.10 * i
                val (mx, my) = maxPan(fit, vp, s, 0.0)
                val ang = rng.range(0.0, 2 * Math.PI)
                val rEnd = (0.4 + 0.9 * i) * rng.sign() * rad
                val amp = 0.45 + 0.3 * i
                val midAng = ang + Math.PI / 2 * rng.sign()
                val a = CameraState(-kotlin.math.cos(ang) * mx * amp, -kotlin.math.sin(ang) * my * amp, s)
                val mid = CameraState(
                    kotlin.math.cos(midAng) * mx * amp * 0.35,
                    kotlin.math.sin(midAng) * my * amp * 0.35,
                    s * 1.04,
                    rEnd * 0.5,
                )
                val b = CameraState(
                    kotlin.math.cos(ang) * mx * amp,
                    kotlin.math.sin(ang) * my * amp,
                    s * 1.07,
                    rEnd,
                )
                kfs += kf(0.0, clip(a, fit, vp))
                kfs += kf(duration * 0.5, clip(mid, fit, vp))
                kfs += kf(duration, clip(b, fit, vp))
            }
            MotionType.CENTER_TO_CORNER -> {
                val s0 = 1.02 + 0.05 * i
                val s1 = s0 * (1.12 + 0.18 * i)
                val (mx, my) = maxPan(fit, vp, s1, 0.0)
                val csx = rng.sign()
                val csy = rng.sign()
                kfs += kf(0.0, clip(CameraState(0.0, 0.0, s0), fit, vp))
                kfs += kf(
                    duration,
                    clip(CameraState(csx * mx * (0.7 + 0.25 * i), csy * my * (0.7 + 0.25 * i), s1), fit, vp),
                )
            }
            MotionType.COMBINED -> {
                val s0 = 1.03 + 0.04 * i
                val s1 = s0 * (1.14 + 0.22 * i)
                val sMid = maxOf(s0, s1)
                val (mx, my) = maxPan(fit, vp, sMid, 1.2 * rad)
                val rEnd = (0.6 + 1.0 * i) * rng.sign() * rad
                val ang = rng.range(0.0, 2 * Math.PI)
                val amp = 0.55 + 0.25 * i
                val a = CameraState(-kotlin.math.cos(ang) * mx * amp, -kotlin.math.sin(ang) * my * amp, s0)
                val mid = CameraState(0.0, 0.0, (s0 + s1) / 2, rEnd * 0.5)
                val b = CameraState(
                    kotlin.math.cos(ang) * mx * amp,
                    kotlin.math.sin(ang) * my * amp,
                    s1,
                    rEnd,
                )
                kfs += kf(0.0, clip(a, fit, vp))
                kfs += kf(duration * 0.5, clip(mid, fit, vp))
                kfs += kf(duration, clip(b, fit, vp))
            }
        }

        // first exactly 0, last exactly duration
        kfs[0] = kfs[0].copy(time = 0.0)
        kfs[kfs.size - 1] = kfs[kfs.size - 1].copy(time = duration)
        return MotionProfileData(type, i, kfs.toList(), seed)
    }

    /**
     * Weighted draw from the curved-motion pool; the previous photo's path
     * preset is removed outright, so adjacent photos never share a path
     * style (same hard guarantee as [pickMotionType], spec §10 rule 1).
     *
     * Mirror of `pick_path_preset` in the Python reference.
     */
    @JvmStatic
    fun pickPathPreset(rng: Xorshift128Plus, previous: String? = null): String {
        val weightsMap = PATH_PRESET_WEIGHTS
        var pool = weightsMap.keys.toList()
        if (previous != null && pool.size > 1) {
            val filtered = pool.filter { it != previous }
            if (filtered.isNotEmpty()) pool = filtered
        }
        val weights = pool.map { weightsMap.getValue(it) }
        val total = weights.sum()
        val r = rng.nextDouble() * total
        var acc = 0.0
        for (i in pool.indices) {
            acc += weights[i]
            if (r <= acc) return pool[i]
        }
        return pool.last()
    }

    /**
     * One deterministic curved-path motion (spec §12.7).
     *
     * The draw order below is part of the contract: the Dart and Python
     * ports perform exactly these draws, in exactly this order.
     */
    @JvmStatic
    fun generatePathProfile(
        rng: Xorshift128Plus,
        intensity: Double,
        duration: Double,
        fit: ImageFit,
        vp: Viewport,
        seed: Long,
        excludePreset: String? = null,
        preset: String? = null,
    ): PathMotionProfile {
        require(duration > 0.0) { "duration must be positive" }
        val i = clamp(intensity, 0.0, 1.0)
        val chosen = preset ?: pickPathPreset(rng, excludePreset)
        val direction = rng.sign()                         // 1
        val startAngle = rng.range(0.0, 2.0 * Math.PI)     // 2
        val curvature = rng.range(0.15, 0.85)              // 3
        val speed = rng.range(0.8, 1.4)                    // 4
        val speedEase = rng.range(0.0, 0.5)                // 5
        var turns = 1.0
        var sweep = 2.0 * Math.PI
        if (chosen == "circularCw" || chosen == "circularCcw" || chosen == "spiral") {
            if (rng.bool(0.25)) turns = 2.0                // 6
        }
        if (chosen == "figureEight") {
            turns = rng.irange(1, 2).toDouble()            // 7
        }
        if (chosen == "arc") {
            sweep = rng.range(0.6 * Math.PI, 1.8 * Math.PI) // 8
        }
        val pattern = rng.irange(0, 4)                     // 9
        val base = 1.04 + 0.10 * i
        val s0: Double
        val s1: Double
        when (pattern) {
            0 -> { // circle + zoom in
                s0 = base
                s1 = base * (1.18 + 0.24 * i)
            }
            1 -> { // curved + zoom out
                s0 = base * (1.18 + 0.24 * i)
                s1 = base
            }
            2 -> { // gentle drift, near-constant zoom
                s0 = base * (1.05 + 0.08 * i)
                s1 = s0 * rng.range(1.0, 1.06)             // 10
            }
            3 -> { // slow push while curving
                s0 = 1.03 + 0.04 * i
                s1 = s0 * (1.12 + 0.18 * i)
            }
            else -> { // pull back while curving
                s1 = 1.03 + 0.04 * i
                s0 = s1 * (1.12 + 0.18 * i)
            }
        }
        val r0 = 0.0
        val r1: Double
        if (rng.bool(0.5)) {                               // 11
            r1 = rng.range(0.4, 1.5) * rng.sign() * Math.PI / 180.0 // 12
        } else {
            r1 = 0.0
        }
        val sMax = maxOf(s0, s1)
        val lim = maxPan(fit, vp, sMax, kotlin.math.abs(r1 - r0))
        var margin = minOf(lim.first, lim.second)
        if (margin < 0.02) margin = 0.02
        var r = margin * (0.35 + 0.45 * i)
        if (r < 0.03) r = 0.03
        val radiusX = r
        val radiusY: Double
        if (chosen == "elliptical" || chosen == "sCurve" || chosen == "figureEight") {
            radiusY = r * rng.range(0.7, 1.0)              // 13
        } else {
            radiusY = r
        }
        val cX: Double
        val cY: Double
        if (rng.bool(0.3)) {                               // 14
            cX = rng.range(-0.1, 0.1)
            cY = rng.range(-0.1, 0.1)                      // 15
        } else {
            cX = 0.0
            cY = 0.0
        }
        val spec = sanitizePath(
            MotionPathSpec(
                preset = chosen,
                centerX = cX,
                centerY = cY,
                radiusX = radiusX,
                radiusY = radiusY,
                turns = turns,
                startAngle = startAngle,
                sweep = sweep,
                curvature = curvature,
                speed = speed,
                speedEase = speedEase,
                startZoom = s0,
                endZoom = s1,
                startRotation = r0,
                endRotation = r1,
                direction = direction,
            ),
            fit,
            vp,
        )
        val kfs = bakePath(spec, fit, vp, duration)
        val mtype = if (s1 >= s0) {
            MotionType.ZOOM_IN
        } else if (s0 > s1) {
            MotionType.ZOOM_OUT
        } else {
            MotionType.DRIFT
        }
        return PathMotionProfile(mtype, i, kfs, seed, spec)
    }
}
