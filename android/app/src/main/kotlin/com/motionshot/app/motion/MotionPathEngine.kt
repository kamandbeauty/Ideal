package com.motionshot.app.motion

import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Motion Path Engine — Kotlin port of docs/MOTION_SPEC.md §12.
 *
 * 1:1 port of `tools/validate/motionshot/motion_path.py` (operation order
 * included — the same double arithmetic in the same order, so the preview,
 * the exporter and the golden vectors agree). The Dart twin is
 * `lib/features/motion_path/motion_path_engine.dart`.
 */

const val LUT_SIZE = 4096 // arc-length lookup table resolution (all runtimes)
const val REFINE_STEPS = 16 // local sub-chord refinement inside one LUT cell

/** The ten path presets (spec §12.1). The ids are persisted; never rename. */
val PATH_PRESETS: List<String> = listOf(
    "linear", "circularCw", "circularCcw", "elliptical", "spiral",
    "sCurve", "figureEight", "arc", "cubicBezier", "custom",
)

/**
 * Generation pool for random curved motion (spec §12.7). `linear` and
 * `cubicBezier`/`custom` are excluded. Insertion order is part of the
 * weighted-draw contract.
 */
val PATH_PRESET_WEIGHTS: Map<String, Double> = linkedMapOf(
    "circularCw" to 1.2, "circularCcw" to 1.2, "elliptical" to 1.0,
    "sCurve" to 1.1, "spiral" to 0.8, "figureEight" to 0.7, "arc" to 1.0,
)

const val SPIRAL_RHO0_MIN = 0.15 // rho0 = 0.15 + 0.75 * (1 - curvature)
const val SPIRAL_RHO0_RANGE = 0.75

const val STROKE_DEDUPE_MIN_DIST = 0.004 // normalized units
const val STROKE_TARGET_POINTS = 24 // stored points after smoothing
const val CHAIKIN_ITERS = 2

private const val SCALE_PAD = 1.002 // same pad as the keyframe generators

/** A point in normalized camera space (spec §1.2). */
data class MotionPathPoint(val x: Double, val y: Double)

/**
 * One persisted camera path (spec §12.1).
 *
 * direction: `1` = counter-clockwise on screen, `-1` = clockwise.
 */
data class MotionPathSpec(
    val preset: String,
    val centerX: Double = 0.0,
    val centerY: Double = 0.0,
    val radiusX: Double = 0.25,
    val radiusY: Double = 0.25,
    val turns: Double = 1.0, // figure eight snaps to int 1..3
    val startAngle: Double = -Math.PI / 2.0, // radians, +x axis, y up
    val sweep: Double = 2.0 * Math.PI, // `arc` only (radians, <= 2*pi)
    val curvature: Double = 0.5, // 0..1
    val speed: Double = 1.0, // 0.25..3 (path progress per clip)
    val speedEase: Double = 0.0, // 0..1 (0 = constant speed)
    val startZoom: Double = 1.15,
    val endZoom: Double = 1.30,
    val startRotation: Double = 0.0, // radians
    val endRotation: Double = 0.0,
    val direction: Int = 1,
    val points: List<MotionPathPoint> = emptyList(),
    val isCustom: Boolean = false, // drawn with the finger
    val isUserEdited: Boolean = false, // protected from randomize
) {
    init {
        require(preset in PATH_PRESETS) { "unknown path preset '$preset'" }
        require(direction == -1 || direction == 1) { "direction must be ±1" }
    }

    val isProtected: Boolean get() = isCustom || isUserEdited

    fun copyWith(
        preset: String? = null,
        centerX: Double? = null,
        centerY: Double? = null,
        radiusX: Double? = null,
        radiusY: Double? = null,
        turns: Double? = null,
        startAngle: Double? = null,
        sweep: Double? = null,
        curvature: Double? = null,
        speed: Double? = null,
        speedEase: Double? = null,
        startZoom: Double? = null,
        endZoom: Double? = null,
        startRotation: Double? = null,
        endRotation: Double? = null,
        direction: Int? = null,
        points: List<MotionPathPoint>? = null,
        isCustom: Boolean? = null,
        isUserEdited: Boolean? = null,
    ): MotionPathSpec = MotionPathSpec(
        preset = preset ?: this.preset,
        centerX = centerX ?: this.centerX,
        centerY = centerY ?: this.centerY,
        radiusX = radiusX ?: this.radiusX,
        radiusY = radiusY ?: this.radiusY,
        turns = turns ?: this.turns,
        startAngle = startAngle ?: this.startAngle,
        sweep = sweep ?: this.sweep,
        curvature = curvature ?: this.curvature,
        speed = speed ?: this.speed,
        speedEase = speedEase ?: this.speedEase,
        startZoom = startZoom ?: this.startZoom,
        endZoom = endZoom ?: this.endZoom,
        startRotation = startRotation ?: this.startRotation,
        endRotation = endRotation ?: this.endRotation,
        direction = direction ?: this.direction,
        points = points ?: this.points,
        isCustom = isCustom ?: this.isCustom,
        isUserEdited = isUserEdited ?: this.isUserEdited,
    )

    fun toJson(): JSONObject {
        val o = JSONObject()
        o.put("preset", preset)
        o.put("centerX", centerX)
        o.put("centerY", centerY)
        o.put("radiusX", radiusX)
        o.put("radiusY", radiusY)
        o.put("turns", turns)
        o.put("startAngle", startAngle)
        o.put("sweep", sweep)
        o.put("curvature", curvature)
        o.put("speed", speed)
        o.put("speedEase", speedEase)
        o.put("startZoom", startZoom)
        o.put("endZoom", endZoom)
        o.put("startRotation", startRotation)
        o.put("endRotation", endRotation)
        o.put("direction", direction)
        val pts = JSONArray()
        for (p in points) {
            pts.put(JSONObject().put("x", p.x).put("y", p.y))
        }
        o.put("points", pts)
        o.put("isCustom", isCustom)
        o.put("isUserEdited", isUserEdited)
        return o
    }

    companion object {
        /**
         * Throws [IllegalArgumentException] for unknown/foreign preset data;
         * the loader then falls back to the baked keyframes (spec §12.1).
         */
        @JvmStatic
        @Throws(IllegalArgumentException::class)
        fun fromJson(o: JSONObject): MotionPathSpec {
            val preset = o.optString("preset", "circularCw")
            if (preset !in PATH_PRESETS) {
                throw IllegalArgumentException("unknown path preset '$preset'")
            }
            val pts = ArrayList<MotionPathPoint>()
            val arr = o.optJSONArray("points")
            if (arr != null) {
                for (i in 0 until arr.length()) {
                    val p = arr.getJSONObject(i)
                    pts += MotionPathPoint(p.getDouble("x"), p.getDouble("y"))
                }
            }
            return MotionPathSpec(
                preset = preset,
                centerX = o.optDouble("centerX", 0.0),
                centerY = o.optDouble("centerY", 0.0),
                radiusX = o.optDouble("radiusX", 0.25),
                radiusY = o.optDouble("radiusY", 0.25),
                turns = o.optDouble("turns", 1.0),
                startAngle = o.optDouble("startAngle", -Math.PI / 2.0),
                sweep = o.optDouble("sweep", 2.0 * Math.PI),
                curvature = o.optDouble("curvature", 0.5),
                speed = o.optDouble("speed", 1.0),
                speedEase = o.optDouble("speedEase", 0.0),
                startZoom = o.optDouble("startZoom", 1.15),
                endZoom = o.optDouble("endZoom", 1.30),
                startRotation = o.optDouble("startRotation", 0.0),
                endRotation = o.optDouble("endRotation", 0.0),
                direction = o.optInt("direction", 1),
                points = pts,
                isCustom = o.optBoolean("isCustom", false),
                isUserEdited = o.optBoolean("isUserEdited", false),
            )
        }
    }
}

// ---------------------------------------------------------------------------
// preset parameter resolution
// ---------------------------------------------------------------------------

private fun linearEndpoints(spec: MotionPathSpec): Pair<MotionPathPoint, MotionPathPoint> {
    if (spec.points.size >= 2) return spec.points[0] to spec.points[1]
    return (MotionPathPoint(spec.centerX - spec.radiusX, spec.centerY - spec.radiusY)) to
        (MotionPathPoint(spec.centerX + spec.radiusX, spec.centerY + spec.radiusY))
}

private fun sCurveWaypoints(spec: MotionPathSpec): List<MotionPathPoint> {
    if (spec.points.size >= 3) return spec.points.toList()
    val bend = (2.0 * spec.curvature - 1.0) * spec.radiusY
    return listOf(
        MotionPathPoint(spec.centerX - spec.radiusX, spec.centerY + bend),
        MotionPathPoint(spec.centerX, spec.centerY),
        MotionPathPoint(spec.centerX + spec.radiusX, spec.centerY - bend),
    )
}

private fun bezierPoints(spec: MotionPathSpec): List<MotionPathPoint> {
    if (spec.points.size >= 4) return spec.points.subList(0, 4).toList()
    val bend = (2.0 * spec.curvature - 1.0) * spec.radiusY
    return listOf(
        MotionPathPoint(spec.centerX - spec.radiusX, spec.centerY),
        MotionPathPoint(spec.centerX - spec.radiusX * 0.5, spec.centerY + bend),
        MotionPathPoint(spec.centerX + spec.radiusX * 0.5, spec.centerY - bend),
        MotionPathPoint(spec.centerX + spec.radiusX, spec.centerY),
    )
}

/** figure eight must close with a C1 seam: integer turns, 1..3. */
private fun snapTurns(spec: MotionPathSpec): Double {
    if (spec.preset == "figureEight") {
        return if (spec.turns >= 0.5) spec.turns.roundToInt().toDouble() else 1.0
    }
    return spec.turns
}

// ---------------------------------------------------------------------------
// centripetal Catmull-Rom (alpha = 0.5), spec §12.4
// ---------------------------------------------------------------------------

/**
 * One centripetal Catmull-Rom segment from p1 to p2, local parameter w in
 * [0,1] (spec §12.4).
 *
 * Barry-Goldman non-uniform formulation with centripetal knots
 * t_k = t_{k-1} + |p_k - p_{k-1}|^0.5, evaluated in the de Casteljau style
 * in the knot parameter ts = t1 + (t2-t1)*w:
 *
 *     a1 = (p0*(t1-ts) - p1*(t0-ts)) / (t1-t0)
 *     a2 = (p1*(t2-ts) - p2*(t1-ts)) / (t2-t1)
 *     a3 = (p2*(t3-ts) - p3*(t2-ts)) / (t3-t2)
 *     b1 = (a1*(t2-ts) - a2*(t0-ts)) / (t2-t0)
 *     b2 = (a2*(t3-ts) - a3*(t1-ts)) / (t3-t1)
 *     c  = (b1*(t2-ts) - b2*(t1-ts)) / (t2-t1)
 *
 * C1 at the waypoints, cusp-free for the centripetal exponent. The Dart and
 * Python ports reproduce every operation in this exact order.
 */
fun crSegment(
    p0: MotionPathPoint,
    p1: MotionPathPoint,
    p2: MotionPathPoint,
    p3: MotionPathPoint,
    w: Double,
): MotionPathPoint {
    val t0 = 0.0
    val t1 = t0 + sqrt(hypot(p1.x - p0.x, p1.y - p0.y))
    val t2 = t1 + sqrt(hypot(p2.x - p1.x, p2.y - p1.y))
    val t3 = t2 + sqrt(hypot(p3.x - p2.x, p3.y - p2.y))
    if (t2 - t1 < 1e-12) return p1 // degenerate segment: p1 == p2
    val ts = t1 + (t2 - t1) * w
    val t0s = t0 - ts
    val t1s = t1 - ts
    val t2s = t2 - ts
    val t3s = t3 - ts
    val a1x: Double
    val a1y: Double
    if (t1 - t0 < 1e-12) {
        a1x = p1.x
        a1y = p1.y
    } else {
        a1x = (p0.x * t1s - p1.x * t0s) / (t1 - t0)
        a1y = (p0.y * t1s - p1.y * t0s) / (t1 - t0)
    }
    val a2x = (p1.x * t2s - p2.x * t1s) / (t2 - t1)
    val a2y = (p1.y * t2s - p2.y * t1s) / (t2 - t1)
    val a3x: Double
    val a3y: Double
    if (t3 - t2 < 1e-12) {
        a3x = p2.x
        a3y = p2.y
    } else {
        a3x = (p2.x * t3s - p3.x * t2s) / (t3 - t2)
        a3y = (p2.y * t3s - p3.y * t2s) / (t3 - t2)
    }
    val b1x: Double
    val b1y: Double
    if (t2 - t0 < 1e-12) {
        b1x = a1x
        b1y = a1y
    } else {
        b1x = (a1x * t2s - a2x * t0s) / (t2 - t0)
        b1y = (a1y * t2s - a2y * t0s) / (t2 - t0)
    }
    val b2x: Double
    val b2y: Double
    if (t3 - t1 < 1e-12) {
        b2x = a2x
        b2y = a2y
    } else {
        b2x = (a2x * t3s - a3x * t1s) / (t3 - t1)
        b2y = (a2y * t3s - a3y * t1s) / (t3 - t1)
    }
    return MotionPathPoint(
        (b1x * t2s - b2x * t1s) / (t2 - t1),
        (b1y * t2s - b2y * t1s) / (t2 - t1),
    )
}

/**
 * Exact dc/dts at the segment start (atEnd=false, ts=t1) or end
 * (atEnd=true, ts=t2), by differentiating the [crSegment] scheme:
 *
 *     a1' = (p1-p0)/(t1-t0)          a2' = (p2-p1)/(t2-t1)
 *     a3' = (p3-p2)/(t3-t2)
 *     b1' = (a1'*(t2-ts) - a2'*(t0-ts) - a1 + a2) / (t2-t0)
 *     b2' = (a2'*(t3-ts) - a3'*(t1-ts) - a2 + a3) / (t3-t1)
 *     c'  = (b1'*(t2-ts) - b2'*(t1-ts) - b1 + b2) / (t2-t1)
 *
 * Used by the C1 continuity invariant only.
 */
fun crSegmentDerivative(
    p0: MotionPathPoint,
    p1: MotionPathPoint,
    p2: MotionPathPoint,
    p3: MotionPathPoint,
    atEnd: Boolean,
): MotionPathPoint {
    val t0 = 0.0
    val t1 = t0 + sqrt(hypot(p1.x - p0.x, p1.y - p0.y))
    val t2 = t1 + sqrt(hypot(p2.x - p1.x, p2.y - p1.y))
    val t3 = t2 + sqrt(hypot(p3.x - p2.x, p3.y - p2.y))
    if (t2 - t1 < 1e-12) return MotionPathPoint(0.0, 0.0)
    val ts = if (atEnd) t2 else t1
    val t0s = t0 - ts
    val t1s = t1 - ts
    val t2s = t2 - ts
    val t3s = t3 - ts
    val a1dx: Double
    val a1dy: Double
    if (t1 - t0 < 1e-12) {
        a1dx = 0.0
        a1dy = 0.0
    } else {
        a1dx = (p1.x - p0.x) / (t1 - t0)
        a1dy = (p1.y - p0.y) / (t1 - t0)
    }
    val a2dx = (p2.x - p1.x) / (t2 - t1)
    val a2dy = (p2.y - p1.y) / (t2 - t1)
    val a3dx: Double
    val a3dy: Double
    if (t3 - t2 < 1e-12) {
        a3dx = 0.0
        a3dy = 0.0
    } else {
        a3dx = (p3.x - p2.x) / (t3 - t2)
        a3dy = (p3.y - p2.y) / (t3 - t2)
    }
    val a1x: Double
    val a1y: Double
    if (t1 - t0 < 1e-12) {
        a1x = p1.x
        a1y = p1.y
    } else {
        a1x = (p0.x * t1s - p1.x * t0s) / (t1 - t0)
        a1y = (p0.y * t1s - p1.y * t0s) / (t1 - t0)
    }
    val a2x = (p1.x * t2s - p2.x * t1s) / (t2 - t1)
    val a2y = (p1.y * t2s - p2.y * t1s) / (t2 - t1)
    val a3x: Double
    val a3y: Double
    if (t3 - t2 < 1e-12) {
        a3x = p2.x
        a3y = p2.y
    } else {
        a3x = (p2.x * t3s - p3.x * t2s) / (t3 - t2)
        a3y = (p2.y * t3s - p3.y * t2s) / (t3 - t2)
    }
    val b1x: Double
    val b1y: Double
    if (t2 - t0 < 1e-12) {
        b1x = a1x
        b1y = a1y
    } else {
        b1x = (a1x * t2s - a2x * t0s) / (t2 - t0)
        b1y = (a1y * t2s - a2y * t0s) / (t2 - t0)
    }
    val b2x: Double
    val b2y: Double
    if (t3 - t1 < 1e-12) {
        b2x = a2x
        b2y = a2y
    } else {
        b2x = (a2x * t3s - a3x * t1s) / (t3 - t1)
        b2y = (a2y * t3s - a3y * t1s) / (t3 - t1)
    }
    val b1dx: Double
    val b1dy: Double
    if (t2 - t0 < 1e-12) {
        b1dx = 0.0
        b1dy = 0.0
    } else {
        b1dx = (a1dx * t2s - a2dx * t0s - a1x + a2x) / (t2 - t0)
        b1dy = (a1dy * t2s - a2dy * t0s - a1y + a2y) / (t2 - t0)
    }
    val b2dx: Double
    val b2dy: Double
    if (t3 - t1 < 1e-12) {
        b2dx = 0.0
        b2dy = 0.0
    } else {
        b2dx = (a2dx * t3s - a3dx * t1s - a2x + a3x) / (t3 - t1)
        b2dy = (a2dy * t3s - a3dy * t1s - a2y + a3y) / (t3 - t1)
    }
    return MotionPathPoint(
        (b1dx * t2s - b2dx * t1s - b1x + b2x) / (t2 - t1),
        (b1dy * t2s - b2dy * t1s - b1y + b2y) / (t2 - t1),
    )
}

/** CR spline through `pts`, global parameter u in [0,1]. */
private fun catmullRom(pts: List<MotionPathPoint>, u: Double): MotionPathPoint {
    val n = pts.size - 1 // number of segments
    if (n <= 0) return pts[0]
    val uu = if (u < 0.0) 0.0 else (if (u > 1.0) 1.0 else u)
    val g = uu * n
    var seg = g.toInt()
    if (seg >= n) seg = n - 1
    val w = g - seg
    val p0 = if (seg >= 1) pts[seg - 1] else pts[0]
    val p1 = pts[seg]
    val p2 = pts[seg + 1]
    val p3 = if (seg + 2 < pts.size) pts[seg + 2] else pts[pts.size - 1]
    return crSegment(p0, p1, p2, p3, w)
}

// ---------------------------------------------------------------------------
// raw parametric point, spec §12.3
// ---------------------------------------------------------------------------

/**
 * Camera position at path parameter u in [0,1] (BEFORE arc-length
 * re-parameterization, BEFORE the safety clamp).
 */
fun rawPoint(spec: MotionPathSpec, u: Double): MotionPathPoint {
    val uu = if (u < 0.0) 0.0 else (if (u > 1.0) 1.0 else u)
    val cx = spec.centerX
    val cy = spec.centerY
    val rx = spec.radiusX
    val ry = spec.radiusY
    val d = spec.direction

    when (spec.preset) {
        "linear" -> {
            val ab = linearEndpoints(spec)
            return MotionPathPoint(
                lerp(ab.first.x, ab.second.x, uu),
                lerp(ab.first.y, ab.second.y, uu),
            )
        }

        "circularCw", "circularCcw", "elliptical" -> {
            val theta = spec.startAngle + d * 2.0 * Math.PI * spec.turns * uu
            return MotionPathPoint(cx + rx * cos(theta), cy + ry * sin(theta))
        }

        "arc" -> {
            val theta = spec.startAngle + d * spec.sweep * uu
            return MotionPathPoint(cx + rx * cos(theta), cy + ry * sin(theta))
        }

        "spiral" -> {
            val rho0 = SPIRAL_RHO0_MIN + SPIRAL_RHO0_RANGE * (1.0 - spec.curvature)
            val rho = lerp(rho0, 1.0, uu)
            val theta = spec.startAngle + d * 2.0 * Math.PI * spec.turns * uu
            return MotionPathPoint(
                cx + rx * rho * cos(theta),
                cy + ry * rho * sin(theta),
            )
        }

        "figureEight" -> {
            val k = snapTurns(spec)
            val a = 2.0 * Math.PI * k * uu
            return MotionPathPoint(
                cx + rx * sin(a),
                cy + ry * sin(a) * cos(a),
            )
        }

        "sCurve" -> return catmullRom(sCurveWaypoints(spec), uu)

        "cubicBezier" -> {
            val bp = bezierPoints(spec)
            val iu = 1.0 - uu
            val a = iu * iu * iu
            val b = 3.0 * iu * iu * uu
            val c = 3.0 * iu * uu * uu
            val dd = uu * uu * uu
            return MotionPathPoint(
                a * bp[0].x + b * bp[1].x + c * bp[2].x + dd * bp[3].x,
                a * bp[0].y + b * bp[1].y + c * bp[2].y + dd * bp[3].y,
            )
        }

        "custom" -> {
            val pts = spec.points
            if (pts.size <= 1) {
                return if (pts.isEmpty()) MotionPathPoint(cx, cy) else pts[0]
            }
            return catmullRom(pts, uu)
        }
    }
    throw IllegalArgumentException("unknown path preset '${spec.preset}'")
}

/**
 * Normalized tangent at u.
 *
 * One-sided differences at the ends (so the u=0 and u=1 tangents of a closed
 * path are the true seam tangents), central difference otherwise.
 */
fun pathTangent(spec: MotionPathSpec, u: Double): MotionPathPoint {
    val e = 1e-3
    val a: MotionPathPoint
    val b: MotionPathPoint
    when {
        u <= e -> {
            a = rawPoint(spec, 0.0)
            b = rawPoint(spec, u + e)
        }
        u >= 1.0 - e -> {
            a = rawPoint(spec, u - e)
            b = rawPoint(spec, 1.0)
        }
        else -> {
            a = rawPoint(spec, u - e)
            b = rawPoint(spec, u + e)
        }
    }
    val dx = b.x - a.x
    val dy = b.y - a.y
    val m = hypot(dx, dy)
    if (m < 1e-12) return MotionPathPoint(0.0, 0.0)
    return MotionPathPoint(dx / m, dy / m)
}

// ---------------------------------------------------------------------------
// arc-length re-parameterization + evaluation, spec §12.2 / §12.6
// ---------------------------------------------------------------------------

/**
 * One evaluator per (path, render thread). Caches the arc-length table,
 * which depends only on the spec.
 */
class MotionPathEvaluator(val spec: MotionPathSpec) {
    private var lutCum: DoubleArray? = null
    private var lutTotal: Double = 0.0

    fun lut(): DoubleArray {
        val c = lutCum ?: buildLut()
        return c
    }

    fun total(): Double {
        if (lutCum == null) buildLut()
        return lutTotal
    }

    private fun buildLut(): DoubleArray {
        val cum = DoubleArray(LUT_SIZE + 1)
        val du = 1.0 / LUT_SIZE
        val p0 = rawPoint(spec, 0.0)
        var px = p0.x
        var py = p0.y
        for (i in 1..LUT_SIZE) {
            var s = 0.0
            for (k in 1..REFINE_STEPS) {
                val q = rawPoint(spec, (i - 1) * du + du * k / REFINE_STEPS)
                s = s + hypot(q.x - px, q.y - py)
                px = q.x
                py = q.y
            }
            cum[i] = cum[i - 1] + s
        }
        lutCum = cum
        lutTotal = cum[LUT_SIZE]
        return cum
    }

    /**
     * Inverse arc lookup: path parameter u for arc-length target.
     *
     * Two levels (identical in every runtime):
     *  1. coarse — binary search for the first i with cum[i] >= target;
     *  2. fine   — REFINE_STEPS sub-chords inside that single LUT cell,
     *              binary search + linear interpolation again.
     */
    fun paramAtArc(target: Double): Double {
        val cum = lut()
        val total = lutTotal
        if (target <= 0.0 || total <= 1e-9) return 0.0
        if (target >= total) return 1.0
        var lo = 0
        var hi = LUT_SIZE
        while (lo + 1 < hi) {
            val mid = (lo + hi) / 2
            if (cum[mid] >= target) hi = mid else lo = mid
        }
        val i0 = hi - 1
        val d = cum[hi] - cum[i0]
        if (d < 1e-12) return (i0 + 0.5) / LUT_SIZE
        // (Int * 1.0) promotes to Double without an extension call
        val u0 = i0 / (LUT_SIZE * 1.0)
        val du = 1.0 / LUT_SIZE
        val n = REFINE_STEPS
        val pp = rawPoint(spec, u0)
        var px = pp.x
        var py = pp.y
        val c = DoubleArray(n + 1)
        for (k in 1..n) {
            val q = rawPoint(spec, u0 + du * k / n)
            c[k] = c[k - 1] + hypot(q.x - px, q.y - py)
            px = q.x
            py = q.y
        }
        val cTotal = c[n]
        if (cTotal < 1e-12) return u0 + du * (target - cum[i0]) / d
        val local = (target - cum[i0]) * (cTotal / d)
        var lo2 = 0
        var hi2 = n
        while (lo2 + 1 < hi2) {
            val mid = (lo2 + hi2) / 2
            if (c[mid] >= local) hi2 = mid else lo2 = mid
        }
        val j0 = hi2 - 1
        val dd = c[hi2] - c[j0]
        if (dd < 1e-12) return u0 + du * (j0 + 0.5) / n
        return u0 + du * (j0 + (local - c[j0]) / dd) / n
    }

    /** Path progress p in [0,1] at local time t (spec §12.6). */
    fun progressAt(t: Double, duration: Double): Double {
        if (duration <= 1e-9) return 1.0
        var q = t / duration
        if (q < 0.0) q = 0.0
        if (q > 1.0) q = 1.0
        var p = q * spec.speed
        if (p > 1.0) p = 1.0
        if (spec.speedEase > 0.0) {
            val e = p * p * p * (p * (6.0 * p - 15.0) + 10.0)
            p = p + spec.speedEase * (e - p)
        }
        if (p < 0.0) p = 0.0
        return p
    }

    /** The unified camera evaluation used by preview AND export (spec §12.6). */
    fun evaluate(fit: ImageFit, vp: Viewport, t: Double, duration: Double): CameraState {
        val p = progressAt(t, duration)
        val u = paramAtArc(p * total())
        val pt = rawPoint(spec, u)
        val s = logLerp(spec.startZoom, spec.endZoom, p)
        val r = spec.startRotation +
            shortestAngle(spec.startRotation, spec.endRotation) * p
        return clampCamera(CameraState(pt.x, pt.y, s, r), fit, vp)
    }

    /**
     * High-resolution keyframes of the path (spec §12.8) — the export
     * fallback and the editor's read-only sample strip.
     */
    fun bake(fit: ImageFit, vp: Viewport, duration: Double, samples: Int = 128): List<Keyframe> {
        val kfs = ArrayList<Keyframe>(samples + 1)
        for (i in 0..samples) {
            val t = duration * i / samples
            val st = evaluate(fit, vp, t, duration)
            kfs += Keyframe(t, st.x, st.y, st.scale, st.rotation, Easing.LINEAR)
        }
        if (kfs.isNotEmpty()) {
            kfs[0] = kfs[0].copy(time = 0.0)
            kfs[kfs.lastIndex] = kfs[kfs.lastIndex].copy(time = duration)
        }
        return kfs
    }
}

/** Static evaluation helpers (no cache; tests and one-shot uses). */
fun evaluatePath(
    spec: MotionPathSpec,
    fit: ImageFit,
    vp: Viewport,
    t: Double,
    duration: Double,
): CameraState = MotionPathEvaluator(spec).evaluate(fit, vp, t, duration)

fun bakePath(
    spec: MotionPathSpec,
    fit: ImageFit,
    vp: Viewport,
    duration: Double,
    samples: Int = 128,
): List<Keyframe> = MotionPathEvaluator(spec).bake(fit, vp, duration, samples)

// ---------------------------------------------------------------------------
// safety / authoring guards, spec §12.6 + §12.9
// ---------------------------------------------------------------------------

/**
 * Clamp every authoring field so the whole path stays cover-safe even at
 * the maximum zoom / rotation the envelope reaches.
 */
fun sanitizePath(spec: MotionPathSpec, fit: ImageFit, vp: Viewport): MotionPathSpec {
    val rMax = maxOf(abs(spec.startRotation), abs(spec.endRotation))
    val sZoom = maxOf(spec.startZoom, spec.endZoom)
    val sMin = minScaleAtRotation(fit, vp, rMax) * SCALE_PAD
    val startZoom = if (spec.startZoom >= sMin) spec.startZoom else sMin
    val endZoom = if (spec.endZoom >= sMin) spec.endZoom else sMin
    val lim = maxPan(fit, vp, maxOf(startZoom, endZoom), rMax)
    val mx = lim.first
    val my = lim.second
    val pts = spec.points.map { p ->
        MotionPathPoint(clamp(p.x, -mx, mx), clamp(p.y, -my, my))
    }
    return MotionPathSpec(
        preset = spec.preset,
        centerX = clamp(spec.centerX, -mx, mx),
        centerY = clamp(spec.centerY, -my, my),
        radiusX = clamp(spec.radiusX, 0.0, mx),
        radiusY = clamp(spec.radiusY, 0.0, my),
        turns = clamp(spec.turns, 0.05, 4.0),
        startAngle = spec.startAngle,
        sweep = clamp(spec.sweep, 0.1, 2.0 * Math.PI),
        curvature = clamp(spec.curvature, 0.0, 1.0),
        speed = clamp(spec.speed, 0.25, 3.0),
        speedEase = clamp(spec.speedEase, 0.0, 1.0),
        startZoom = startZoom,
        endZoom = endZoom,
        startRotation = spec.startRotation,
        endRotation = spec.endRotation,
        direction = spec.direction,
        points = pts,
        isCustom = spec.isCustom,
        isUserEdited = spec.isUserEdited,
    )
}

// ---------------------------------------------------------------------------
// freehand stroke smoothing, spec §12.5
// ---------------------------------------------------------------------------

/** n points equally spaced by arc length along the polyline. */
private fun resampleUniform(pts: List<MotionPathPoint>, n: Int): List<MotionPathPoint> {
    if (pts.size <= 1) return pts.toList()
    val cum = ArrayList<Double>(pts.size)
    cum.add(0.0)
    for (i in 1 until pts.size) {
        cum.add(cum.last() + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y))
    }
    val total = cum.last()
    if (total < 1e-12) return List(n) { pts[0] }
    val out = ArrayList<MotionPathPoint>(n)
    var seg = 0
    for (j in 0 until n) {
        val target = total * j / (n - 1)
        while (seg < pts.size - 2 && cum[seg + 1] < target) seg++
        val d = cum[seg + 1] - cum[seg]
        val w = if (d < 1e-12) 0.0 else (target - cum[seg]) / d
        out += MotionPathPoint(
            lerp(pts[seg].x, pts[seg + 1].x, w),
            lerp(pts[seg].y, pts[seg + 1].y, w),
        )
    }
    return out
}

/** One Chaikin corner-cutting pass (open curve; endpoints kept). */
private fun chaikin(pts: List<MotionPathPoint>): List<MotionPathPoint> {
    if (pts.size <= 2) return pts.toList()
    val out = ArrayList<MotionPathPoint>(2 * pts.size)
    out += pts[0]
    for (i in 0 until pts.size - 1) {
        val x1 = pts[i].x
        val y1 = pts[i].y
        val x2 = pts[i + 1].x
        val y2 = pts[i + 1].y
        out += MotionPathPoint(0.75 * x1 + 0.25 * x2, 0.75 * y1 + 0.25 * y2)
        out += MotionPathPoint(0.25 * x1 + 0.75 * x2, 0.25 * y1 + 0.75 * y2)
    }
    out += pts[pts.size - 1]
    return out
}

/**
 * Raw finger points -> the stored `custom` path points.
 *
 * dedupe (min distance) -> arc-length resample to 24 -> Chaikin x2 ->
 * arc-length resample to 24. Deterministic; identical in Dart/Python.
 */
fun smoothStroke(raw: List<MotionPathPoint>): List<MotionPathPoint> {
    val pts = ArrayList<MotionPathPoint>()
    for (p in raw) {
        if (pts.isNotEmpty() &&
            hypot(p.x - pts.last().x, p.y - pts.last().y) < STROKE_DEDUPE_MIN_DIST
        ) {
            continue
        }
        pts += p
    }
    if (pts.size < 2) return pts
    var out = resampleUniform(pts, STROKE_TARGET_POINTS)
    repeat(CHAIKIN_ITERS) {
        out = chaikin(out)
    }
    return resampleUniform(out, STROKE_TARGET_POINTS)
}
