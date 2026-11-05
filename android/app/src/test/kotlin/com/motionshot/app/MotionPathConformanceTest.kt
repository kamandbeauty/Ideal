package com.motionshot.app

import com.motionshot.app.motion.ExportRequest
import com.motionshot.app.motion.ImageFit
import com.motionshot.app.motion.MotionGenerator
import com.motionshot.app.motion.MotionPathEvaluator
import com.motionshot.app.motion.MotionPathPoint
import com.motionshot.app.motion.MotionPathSpec
import com.motionshot.app.motion.PathMotionProfile
import com.motionshot.app.motion.RandomMotion
import com.motionshot.app.motion.Viewport
import com.motionshot.app.motion.Xorshift128Plus
import com.motionshot.app.motion.bakePath
import com.motionshot.app.motion.crSegmentDerivative
import com.motionshot.app.motion.evaluatePath
import com.motionshot.app.motion.halfExtent
import com.motionshot.app.motion.pathTangent
import com.motionshot.app.motion.rawPoint
import com.motionshot.app.motion.sanitizePath
import com.motionshot.app.motion.sampleKeyframes
import com.motionshot.app.motion.smoothStroke
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * Motion Path Engine conformance tests (spec §12).
 *
 * Replays `golden/motion_paths.json` (produced by `python3 -m
 * motionshot.verify`) so the Kotlin renderer, the Dart preview and the
 * Python reference cannot drift apart.
 */
class MotionPathConformanceTest {

    private fun golden(name: String): JSONObject {
        val stream = javaClass.classLoader!!.getResourceAsStream("$name.json")
        assertNotNull("missing golden/$name.json", stream)
        return JSONObject(stream!!.bufferedReader().readText())
    }

    private fun assertClose(expected: Double, actual: Double, tol: Double, what: String) {
        assertTrue(
            "$what: expected $expected, got $actual",
            abs(expected - actual) <= tol,
        )
    }

    private fun stringKeys(obj: JSONObject): List<String> {
        val out = ArrayList<String>()
        val it = obj.keys()
        while (it.hasNext()) out += it.next()
        return out
    }

    // The exact setup verify.py uses for the path goldens.
    private val vp = Viewport(16.0 / 9.0)
    private val fit = ImageFit.make(4032, 3024, vp)
    private val duration = 5.0

    /** Re-runs the 40-draw sequence from the golden (deterministic). */
    private fun runRandom(): List<Pair<String, PathMotionProfile>> {
        val rng = Xorshift128Plus(RandomMotion.photoSeed(2026L, "path-gen", 0))
        var prev: String? = null
        val out = ArrayList<Pair<String, PathMotionProfile>>(40)
        for (k in 0 until 40) {
            val preset = MotionGenerator.pickPathPreset(rng, prev)
            val prof = MotionGenerator.generatePathProfile(
                rng, 0.7, duration, fit, vp, 12345L,
                excludePreset = prev, preset = preset,
            )
            out += preset to prof
            prev = preset
        }
        return out
    }

    @Test
    fun lutSizeIsFixed() {
        val g = golden("motion_paths")
        assertEquals(4096, g.getInt("lutSize"))
    }

    @Test
    fun specSamplesMatchReference() {
        val g = golden("motion_paths")
        val specs = g.getJSONObject("specs")
        for (name in stringKeys(specs)) {
            val entry = specs.getJSONObject(name)
            val spec = MotionPathSpec.fromJson(entry.getJSONObject("spec"))
            // Sanitizing a sanitized spec is a no-op (idempotence).
            val resan = sanitizePath(spec, fit, vp)
            assertEquals("$name preset", spec.preset, resan.preset)
            assertClose(spec.radiusX, resan.radiusX, 1e-12, "$name radiusX")
            assertClose(spec.centerX, resan.centerX, 1e-12, "$name centerX")

            val ev = MotionPathEvaluator(spec)
            assertClose(entry.getDouble("total"), ev.total(), 1e-6, "$name total")

            val rows = entry.getJSONArray("samples")
            for (i in 0 until rows.length()) {
                val row = rows.getJSONArray(i)
                val t = row.getDouble(0)
                val st = ev.evaluate(fit, vp, t, duration)
                assertClose(row.getDouble(1), st.x, 1e-8, "$name x@${t}")
                assertClose(row.getDouble(2), st.y, 1e-8, "$name y@${t}")
                assertClose(row.getDouble(3), st.scale, 1e-8, "$name s@${t}")
                assertClose(row.getDouble(4), st.rotation, 1e-8, "$name r@${t}")
            }

            val ts = entry.getJSONArray("tangentStart")
            val te = entry.getJSONArray("tangentEnd")
            val start = pathTangent(spec, 0.0)
            val end = pathTangent(spec, 1.0)
            assertClose(ts.getDouble(0), start.x, 1e-8, "$name tangentStart.x")
            assertClose(ts.getDouble(1), start.y, 1e-8, "$name tangentStart.y")
            assertClose(te.getDouble(0), end.x, 1e-8, "$name tangentEnd.x")
            assertClose(te.getDouble(1), end.y, 1e-8, "$name tangentEnd.y")

            // Cover safety at every time (spec §12.6).
            for (i in 0..100) {
                val t = duration * i / 100.0
                val st = ev.evaluate(fit, vp, t, duration)
                val (bw, bh) = halfExtent(vp, st.scale, st.rotation)
                assertTrue(
                    "$name cover@$i (bw=$bw iw=${fit.iw} bh=$bh ih=${fit.ih})",
                    bw <= fit.iw + 1e-9 && bh <= fit.ih + 1e-9,
                )
            }
        }
    }

    @Test
    fun arcLengthUniformity() {
        val g = golden("motion_paths")
        val u = g.getJSONObject("uniformity")
        val specs = g.getJSONObject("specs")
        for (name in stringKeys(u)) {
            val spec = MotionPathSpec.fromJson(specs.getJSONObject(name).getJSONObject("spec"))
            val ev = MotionPathEvaluator(spec)
            val total = ev.total()
            val pts = (0..400).map { j -> rawPoint(spec, ev.paramAtArc(total * j / 400.0)) }
            var maxD = 0.0
            var minD = Double.MAX_VALUE
            for (j in 0 until 400) {
                val d = hypot(pts[j + 1].x - pts[j].x, pts[j + 1].y - pts[j].y)
                maxD = max(maxD, d)
                minD = min(minD, d)
            }
            val ratio = maxD / minD
            val golden = u.getJSONObject(name)
            assertClose(golden.getDouble("total"), total, 1e-6, "$name total")
            assertTrue("$name ratio $ratio", ratio < 1.03)
        }
    }

    @Test
    fun closedPathSeams() {
        val g = golden("motion_paths")
        val seams = g.getJSONObject("seams")
        val specs = g.getJSONObject("specs")
        val e = 1e-3
        for (name in stringKeys(seams)) {
            val spec = MotionPathSpec.fromJson(specs.getJSONObject(name).getJSONObject("spec"))
            val a = rawPoint(spec, 0.0)
            val b = rawPoint(spec, 1.0)
            val posJump = hypot(a.x - b.x, a.y - b.y)
            val ta = pathTangent(spec, 0.0)
            val tb = pathTangent(spec, 1.0)
            var ang = abs(atan2(ta.y, ta.x) - atan2(tb.y, tb.x))
            ang = min(ang, 2 * Math.PI - ang)
            val bound = 2 * Math.PI * e * spec.turns + 0.005
            val golden = seams.getJSONObject(name)
            assertClose(golden.getDouble("posJump"), posJump, 1e-9, "$name posJump")
            assertClose(golden.getDouble("angleJump"), ang, 1e-6, "$name angleJump")
            assertTrue("$name pos $posJump", posJump < 1e-9)
            assertTrue("$name angle $ang", ang < bound)
        }
    }

    @Test
    fun bakeFidelity() {
        val g = golden("motion_paths")
        val bake = g.getJSONObject("bake")
        val specs = g.getJSONObject("specs")
        for (name in stringKeys(bake)) {
            val spec = MotionPathSpec.fromJson(specs.getJSONObject(name).getJSONObject("spec"))
            val kfs = bakePath(spec, fit, vp, duration)
            var maxPos = 0.0
            var maxS = 0.0
            for (i in 0..25) {
                val t = duration * i / 25.0
                val st = evaluatePath(spec, fit, vp, t, duration)
                val bk = sampleKeyframes(kfs, t)
                maxPos = max(maxPos, abs(st.x - bk.x), abs(st.y - bk.y))
                maxS = max(maxS, abs(st.scale - bk.scale))
            }
            val golden = bake.getJSONObject(name)
            assertClose(golden.getDouble("maxPosErr"), maxPos, 1e-6, "$name maxPosErr")
            assertClose(golden.getDouble("maxScaleErr"), maxS, 1e-6, "$name maxScaleErr")
            assertTrue("$name pos $maxPos", maxPos < 5e-3)
            assertTrue("$name scale $maxS", maxS < 2e-3)
        }
    }

    @Test
    fun catmullRomIsC1AtWaypoints() {
        val g = golden("motion_paths")
        val c1 = g.getJSONObject("c1")
        val specs = g.getJSONObject("specs")
        for (name in stringKeys(c1)) {
            val spec = MotionPathSpec.fromJson(specs.getJSONObject(name).getJSONObject("spec"))
            val pts = spec.points
            val n = pts.size
            var worst = 0.0
            for (i in 1 until n - 1) {
                val pL0 = if (i - 2 >= 0) pts[i - 2] else pts[0]
                val pR2 = if (i + 1 < n) pts[i + 1] else pts[n - 1]
                val pR3 = if (i + 2 < n) pts[i + 2] else pts[n - 1]
                val left = crSegmentDerivative(pL0, pts[i - 1], pts[i], pR2, true)
                val right = crSegmentDerivative(pts[i - 1], pts[i], pR2, pR3, false)
                worst = max(worst, abs(left.x - right.x), abs(left.y - right.y))
            }
            assertClose(c1.getDouble(name), worst, 1e-9, "$name c1")
            assertTrue("$name c1 $worst", worst < 1e-9)
        }
    }

    @Test
    fun freehandSmoothing() {
        val g = golden("motion_paths")
        val stroke = g.getJSONObject("stroke")
        val inArr = stroke.getJSONArray("input")
        val raw = (0 until inArr.length()).map { i ->
            val p = inArr.getJSONArray(i)
            MotionPathPoint(p.getDouble(0), p.getDouble(1))
        }
        val out = smoothStroke(raw)
        assertEquals(24, out.size)
        assertEquals(out, smoothStroke(raw)) // deterministic
        val outArr = stroke.getJSONArray("output")
        for (i in out.indices) {
            val p = outArr.getJSONArray(i)
            assertClose(p.getDouble(0), out[i].x, 1e-9, "stroke x$i")
            assertClose(p.getDouble(1), out[i].y, 1e-9, "stroke y$i")
        }
        // Endpoints are (nearly) preserved by the pipeline.
        assertTrue(hypot(out[0].x - raw[0].x, out[0].y - raw[0].y) < 0.01)
        assertTrue(hypot(out.last().x - raw.last().x, out.last().y - raw.last().y) < 0.01)
    }

    @Test
    fun randomCurvedMotionMatchesReference() {
        val g = golden("motion_paths")
        val random = g.getJSONObject("random")
        val presetSeq = random.getJSONArray("presets")

        val run = runRandom()
        for (k in 0 until presetSeq.length()) {
            assertEquals("preset[$k]", presetSeq.getString(k), run[k].first)
        }

        // The stored profiles (first five distinct presets) must re-bake to
        // the golden keyframes and carry the same path.
        val profiles = random.getJSONObject("profiles")
        for (name in stringKeys(profiles)) {
            val t = run.first { it.first == name }.second
            val prof = profiles.getJSONObject(name)
            assertEquals(prof.getString("motionType"), t.motionType.id)
            assertClose(prof.getDouble("intensity"), t.intensity, 1e-12, "$name intensity")
            assertEquals(prof.getLong("seed"), t.seed)
            val gPath = prof.getJSONObject("path")
            val myPath = t.path.toJson()
            for (key in stringKeys(gPath)) {
                if (key == "points") continue
                when (val v = gPath.get(key)) {
                    is Double -> assertClose(v, myPath.getDouble(key), 1e-12, "$name path.$key")
                    is Int -> assertEquals("$name path.$key", v, myPath.getInt(key))
                    is Boolean -> assertEquals("$name path.$key", v, myPath.getBoolean(key))
                    is String -> assertEquals("$name path.$key", v, myPath.getString(key))
                }
            }
            assertEquals(
                gPath.getJSONArray("points").length(),
                myPath.getJSONArray("points").length(),
            )
            assertEquals(prof.getJSONArray("keyframes").length(), t.keyframes.size)
            for (i in t.keyframes.indices) {
                val k = prof.getJSONArray("keyframes").getJSONObject(i)
                val kf = t.keyframes[i]
                assertClose(k.getDouble("time"), kf.time, 1e-9, "$name kf$i.t")
                assertClose(k.getDouble("x"), kf.x, 1e-9, "$name kf$i.x")
                assertClose(k.getDouble("y"), kf.y, 1e-9, "$name kf$i.y")
                assertClose(k.getDouble("scale"), kf.scale, 1e-9, "$name kf$i.s")
                assertClose(k.getDouble("rotation"), kf.rotation, 1e-9, "$name kf$i.r")
            }
        }
    }

    @Test
    fun exportRequestCarriesMotionPath() {
        // A request with a valid path keeps it; with an unknown preset the
        // path is dropped (lenient load) but the keyframes remain.
        val path = MotionPathSpec(preset = "circularCw", radiusX = 0.2, radiusY = 0.2)
        val base = """
            {"width":1920,"height":1080,"fps":30,"outputPath":"/tmp/x.mp4",
             "totalDuration":5.0,"frameCount":150,"aspect":1.7777777777777777,
             "photos":[{"id":"p1","path":"/tmp/p.jpg","width":4032,"height":3024,
               "duration":5.0,"order":0,"motionType":"zoomIn","intensity":0.7,
               "keyframes":[{"time":0.0,"x":0,"y":0,"scale":1.1},
                            {"time":5.0,"x":0,"y":0,"scale":1.3}]}]}
        """.trimIndent()
        val withPathPhoto =
            JSONObject(base.getJSONArray("photos").getJSONObject(0).toString())
                .put("motionPath", path.toJson())
        val withPath = JSONObject(base).put(
            "photos",
            org.json.JSONArray().put(withPathPhoto),
        )
        val req = ExportRequest.fromJson(withPath.toString())
        val p = req.photos[0]
        assertNotNull("path should survive parsing", p.motionPath)
        assertEquals("circularCw", p.motionPath!!.preset)
        assertClose(0.2, p.motionPath!!.radiusX, 1e-12, "radiusX")

        val foreignPhoto =
            JSONObject(base.getJSONArray("photos").getJSONObject(0).toString())
                .put("motionPath", JSONObject().put("preset", "not-a-preset"))
        val foreign = JSONObject(base).put(
            "photos",
            org.json.JSONArray().put(foreignPhoto),
        )
        val req2 = ExportRequest.fromJson(foreign.toString())
        assertEquals("foreign path must be dropped", null, req2.photos[0].motionPath)
        assertEquals(2, req2.photos[0].keyframes.size)
    }
}
