package com.motionshot.app.motion

/**
 * Per-photo motion sampling used by the renderer.
 *
 * A thin, allocation-aware wrapper over [sampleKeyframes] that caches the last
 * segment, because rendering walks time forward one frame at a time: almost
 * every query hits the same segment as the previous frame.
 *
 * Not thread safe by design — one instance per render thread.
 */
class MotionInterpolator(
    keyframes: List<Keyframe>,
    private val fit: ImageFit,
    private val vp: Viewport,
    path: MotionPathSpec? = null,
) {
    private val kfs: List<Keyframe> = keyframes

    /**
     * The high-resolution camera path (spec §12.6). When non-null the camera
     * travels the path directly; the keyframes remain as the fallback for
     * renderers/tests that ignore paths. Preview and export both evaluate
     * the path, so they agree by construction.
     */
    private val pathEvaluator: MotionPathEvaluator? =
        path?.let { MotionPathEvaluator(it) }

    init {
        require(kfs.size >= 2) { "a motion needs at least 2 keyframes" }
    }

    val startTime: Double = kfs.first().time
    val endTime: Double = kfs.last().time
    val hasPath: Boolean get() = pathEvaluator != null

    private var cachedIndex: Int = -1

    /** Samples and clamps the camera for this photo at `localTime`. */
    fun sample(localTime: Double): CameraState {
        val pe = pathEvaluator
        if (pe != null) {
            // evaluate() already applies the §3.2 clamp.
            return pe.evaluate(fit, vp, localTime, endTime - startTime)
        }
        val raw = sampleRaw(localTime)
        return clampCamera(raw, fit, vp)
    }

    /** Samples without the safety clamp (only used by tests/diagnostics). */
    fun sampleRaw(localTime: Double): CameraState {
        val pe = pathEvaluator
        if (pe != null) {
            val p = pe.progressAt(localTime, endTime - startTime)
            val u = pe.paramAtArc(p * pe.total())
            val pt = rawPoint(pe.spec(), u)
            val s = logLerp(
                pe.spec().startZoom,
                pe.spec().endZoom,
                p,
            )
            val r = pe.spec().startRotation +
                shortestAngle(pe.spec().startRotation, pe.spec().endRotation) * p
            return CameraState(pt.x, pt.y, s, r)
        }
        val t = localTime.coerceIn(startTime, endTime)

        if (t <= kfs.first().time) {
            val k = kfs.first()
            return CameraState(k.x, k.y, k.scale, k.rotation)
        }
        if (t >= kfs.last().time) {
            val k = kfs.last()
            return CameraState(k.x, k.y, k.scale, k.rotation)
        }

        var idx = cachedIndex
        if (idx < 0 || idx >= kfs.size - 1 ||
            t < kfs[idx].time || t >= kfs[idx + 1].time
        ) {
            idx = findSegment(t)
            cachedIndex = idx
        }
        val a = kfs[idx]
        val b = kfs[idx + 1]
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

    private fun findSegment(t: Double): Int {
        var lo = 0
        var hi = kfs.size - 1
        while (lo + 1 < hi) {
            val mid = (lo + hi) / 2
            if (kfs[mid].time <= t) lo = mid else hi = mid
        }
        return lo
    }

    /** Pre-samples the whole shot, used by the motion-path overlay in tests. */
    fun sampleAll(steps: Int): List<CameraState> =
        (0..steps).map { sample(startTime + (endTime - startTime) * it / steps) }
}
