package com.motionshot.app.motion

/**
 * Timeline composition and transition maths — Kotlin port of
 * docs/MOTION_SPEC.md §6 and §7.2.
 *
 * Must stay identical to `lib/features/transitions/timeline_engine.dart` so that
 * scrubbing in the preview and the rendered file agree frame for frame.
 */
enum class TransitionType(val id: String) {
    CROSS_DISSOLVE("crossDissolve"),
    FADE("fade"),
    FADE_TO_BLACK("fadeToBlack"),
    SLIDE_LEFT("slideLeft"),
    SLIDE_RIGHT("slideRight"),
    ZOOM_TRANSITION("zoomTransition"),
    BLUR_TRANSITION("blurTransition"),
    SMOOTH_ZOOM("smoothZoom"),
    NONE("none");

    companion object {
        @JvmStatic
        fun parse(id: String?): TransitionType =
            values().firstOrNull { it.id == id } ?: CROSS_DISSOLVE
    }
}

data class TransitionSpec(val type: TransitionType = TransitionType.CROSS_DISSOLVE, val duration: Double = 0.6)

/** One photo's slot on the timeline. */
data class Segment(
    val index: Int,
    val start: Double,
    val duration: Double,
    val transition: TransitionSpec,
) {
    val end: Double get() = start + duration
}

enum class LayerRole { SINGLE, OUT, IN }

/** A photo visible at a point in time. */
data class TimelineLayer(
    val photoIndex: Int,
    val localTime: Double,
    val role: LayerRole,
    val progress: Double,
    val transitionType: TransitionType = TransitionType.NONE,
)

/** Concrete draw parameters after the transition is applied. */
data class DrawLayer(
    val photoIndex: Int,
    val localTime: Double,
    val alpha: Double = 1.0,
    val offsetX: Double = 0.0,
    val offsetY: Double = 0.0,
    val zoomMultiplier: Double = 1.0,
    val blurRadius: Double = 0.0,
    val freezeMotion: Boolean = false,
)

const val BLUR_MAX_RADIUS: Double = 12.0

class Timeline(private val durations: List<Double>, private val transitions: List<TransitionSpec>) {

    init {
        require(durations.isNotEmpty()) { "empty timeline" }
        durations.forEach { require(it > 0.0) { "photo duration must be > 0" } }
    }

    private val starts: DoubleArray = DoubleArray(durations.size).also { arr ->
        var acc = 0.0
        for (i in durations.indices) {
            arr[i] = acc
            acc += durations[i]
        }
    }

    val totalDuration: Double = durations.sum()

    /** §6.2: a transition can never consume more than either neighbour. */
    fun clampedTransition(index: Int): Double {
        if (index < 0 || index >= durations.size - 1) return 0.0
        val tr = transitions.getOrElse(index) { TransitionSpec() }
        if (tr.type == TransitionType.NONE) return 0.0
        return maxOf(0.0, minOf(tr.duration, durations[index], durations[index + 1]))
    }

    /** §6.4: which photo(s) are visible at `t`. */
    fun layersAt(tRaw: Double): List<TimelineLayer> {
        val t = tRaw.coerceIn(0.0, totalDuration)
        val n = durations.size
        if (t >= totalDuration) {
            return listOf(
                TimelineLayer(n - 1, durations[n - 1], LayerRole.SINGLE, 1.0),
            )
        }

        for (i in 0 until n - 1) {
            val d = clampedTransition(i)
            if (d <= 0.0) continue
            val boundary = starts[i] + durations[i]
            val half = d / 2.0
            if (kotlin.math.abs(t - boundary) < half) {
                val p = (t - (boundary - half)) / d
                val outLocal = minOf(durations[i], maxOf(0.0, t - starts[i]))
                val inLocal = minOf(durations[i + 1], maxOf(0.0, t - starts[i + 1]))
                val type = transitions.getOrElse(i) { TransitionSpec() }.type
                return listOf(
                    TimelineLayer(i, outLocal, LayerRole.OUT, p.coerceIn(0.0, 1.0), type),
                    TimelineLayer(i + 1, inLocal, LayerRole.IN, p.coerceIn(0.0, 1.0), type),
                )
            }
        }

        var lo = 0
        var hi = n - 1
        while (lo < hi) {
            val mid = (lo + hi + 1) / 2
            if (starts[mid] <= t) lo = mid else hi = mid - 1
        }
        val local = minOf(durations[lo], maxOf(0.0, t - starts[lo]))
        return listOf(TimelineLayer(lo, local, LayerRole.SINGLE, 0.0))
    }

    /** §7.2: concrete alphas / offsets / zooms / blur for the visible layers. */
    fun drawLayersAt(t: Double): List<DrawLayer> = transitionDrawLayers(layersAt(t))

    /** Frame index of a timestamp, using exact rational timestamps (§8.4). */
    fun frameTimeSeconds(frameIndex: Int, fps: Int): Double = frameIndex.toDouble() / fps

    /** Timestamp in microseconds for a frame index, without drift. */
    fun presentationTimeUs(frameIndex: Int, fps: Int): Long =
        Math.round(frameIndex.toDouble() * 1_000_000.0 / fps)
}

/**
 * Pure transition draw-parameter mapping (spec §7.2), identical to
 * `transitionDrawLayers` in Dart and `transition_draw_layers` in Python.
 */
fun transitionDrawLayers(layers: List<TimelineLayer>): List<DrawLayer> {
    if (layers.size == 1) {
        val l = layers[0]
        return listOf(DrawLayer(l.photoIndex, l.localTime))
    }
    val o = layers[0]
    val i = layers[1]
    val p = o.progress.coerceIn(0.0, 1.0)
    var outA = 1.0
    var inA = 0.0
    var outOffX = 0.0
    var inOffX = 0.0
    var outZoom = 1.0
    var inZoom = 1.0
    var outBlur = 0.0
    var inBlur = 0.0
    var freeze = false

    when (o.transitionType) {
        TransitionType.CROSS_DISSOLVE, TransitionType.NONE -> {
            outA = 1.0 - p
            inA = p
        }
        TransitionType.FADE -> {
            outA = 1.0 - p
            inA = p
            freeze = true
        }
        TransitionType.FADE_TO_BLACK -> {
            if (p <= 0.5) {
                outA = maxOf(0.0, 1.0 - 2.0 * p)
                inA = 0.0
            } else {
                outA = 0.0
                inA = minOf(1.0, 2.0 * p - 1.0)
            }
        }
        TransitionType.SLIDE_LEFT -> {
            outA = 1.0
            inA = 1.0
            outOffX = -p
            inOffX = 1.0 - p
        }
        TransitionType.SLIDE_RIGHT -> {
            outA = 1.0
            inA = 1.0
            outOffX = p
            inOffX = p - 1.0
        }
        TransitionType.ZOOM_TRANSITION -> {
            outA = 1.0 - p
            inA = p
            outZoom = 1.0 + 0.25 * p
            inZoom = 0.80 + 0.20 * p
        }
        TransitionType.SMOOTH_ZOOM -> {
            outA = 1.0 - p
            inA = p
            outZoom = 1.0 + 0.12 * p
            inZoom = 0.94 + 0.06 * p
        }
        TransitionType.BLUR_TRANSITION -> {
            outA = 1.0 - p
            inA = p
            outBlur = BLUR_MAX_RADIUS * p
            inBlur = BLUR_MAX_RADIUS * (1.0 - p)
        }
    }

    return listOf(
        DrawLayer(
            photoIndex = o.photoIndex,
            localTime = o.localTime,
            alpha = outA,
            offsetX = outOffX,
            zoomMultiplier = outZoom,
            blurRadius = outBlur,
            freezeMotion = freeze,
        ),
        DrawLayer(
            photoIndex = i.photoIndex,
            localTime = i.localTime,
            alpha = inA,
            offsetX = inOffX,
            zoomMultiplier = inZoom,
            blurRadius = inBlur,
        ),
    )
}
