package com.motionshot.app.motion

import org.json.JSONArray
import org.json.JSONObject

/**
 * The Flutter -> Kotlin render contract.
 *
 * Mirrors `lib/features/export/export_request_builder.dart` field for field. A
 * missing or wrong field is a hard error with an actionable message, never a
 * silent default: rendering a video from a half-understood request is exactly
 * how "the export does not match the preview" bugs happen.
 */
class ExportRequestException(message: String) : Exception(message)

data class PhotoRenderSpec(
    val id: String,
    val path: String,
    val width: Int,
    val height: Int,
    val duration: Double,
    val order: Int,
    val rotationDegrees: Int,
    val motionType: MotionType,
    val intensity: Double,
    val keyframes: List<Keyframe>,
    val transition: TransitionSpec?,
    val expectedFitIw: Double?,
    val expectedFitIh: Double?,
    /**
     * The high-resolution camera path (spec §12). When present the renderer
     * evaluates it directly; [keyframes] (its baked samples) stay as a
     * fallback for requests produced by older app versions.
     */
    val motionPath: MotionPathSpec? = null,
    /** User zoom on top of the camera scale (1.0 = as generated). */
    val zoomFactor: Double = 1.0,
    /** 0.2..1.0 layer opacity (1.0 = fully opaque). */
    val opacity: Double = 1.0,
)

/**
 * Text watermark shown between [start] and [end] (contract: lib
 * `watermark.dart` — keep the two in sync).
 *
 * [fontScale] is the text height as a fraction of the OUTPUT height;
 * [position] is a 3×3 grid, row-major (0 = top-left … 8 = bottom-right).
 * The text is white over a soft dark chip, at [opacity].
 */
data class WatermarkSpec(
    val text: String,
    val fontScale: Double,
    val opacity: Double,
    val position: Int,
    val start: Double,
    val end: Double,
) {
    val visibleAt: (Double) -> Boolean get() = { t ->
        text.isNotBlank() && t >= start && t <= end
    }

    val row: Int get() = (position / 3).coerceIn(0, 2)
    val col: Int get() = (position % 3).coerceIn(0, 2)
}

data class AudioRenderSpec(
    val path: String,
    val volume: Double,
    val fadeIn: Double,
    val fadeOut: Double,
    val trimStart: Double,
    val trimEnd: Double?,
    val startOffset: Double,
    val loop: Boolean,
    val bitrate: Int,
)

data class ExportRequest(
    val projectId: String,
    val projectSeed: Long,
    val outputPath: String,
    val width: Int,
    val height: Int,
    val fps: Int,
    val codec: String,
    val bitrate: Int,
    val aspect: Double,
    val totalDuration: Double,
    val frameCount: Int,
    val photos: List<PhotoRenderSpec>,
    val audio: AudioRenderSpec?,
    val watermark: WatermarkSpec? = null,
) {
    val viewport: Viewport get() = Viewport(aspect)

    companion object {
        /** Parses and validates the JSON produced by Dart. */
        @JvmStatic
        @Throws(ExportRequestException::class)
        fun fromJson(raw: String): ExportRequest {
            val json = try {
                JSONObject(raw)
            } catch (e: Exception) {
                throw ExportRequestException("malformed request JSON: ${e.message}")
            }

            fun requiredString(key: String): String =
                json.optString(key).takeIf { it.isNotEmpty() }
                    ?: throw ExportRequestException("missing field '$key'")

            fun requiredInt(key: String): Int =
                if (json.has(key)) json.getInt(key)
                else throw ExportRequestException("missing field '$key'")

            val width = requiredInt("width")
            val height = requiredInt("height")
            val fps = requiredInt("fps")
            if (width <= 0 || height <= 0) {
                throw ExportRequestException("invalid output size ${width}x$height")
            }
            if (width % 2 != 0 || height % 2 != 0) {
                throw ExportRequestException(
                    "output size must be even for 4:2:0 chroma (${width}x$height)",
                )
            }
            if (fps !in 1..240) throw ExportRequestException("invalid fps $fps")

            val photosJson = json.optJSONArray("photos")
                ?: throw ExportRequestException("missing field 'photos'")
            if (photosJson.length() == 0) {
                throw ExportRequestException("request has no photos")
            }
            val photos = ArrayList<PhotoRenderSpec>(photosJson.length())
            for (i in 0 until photosJson.length()) {
                photos += parsePhoto(photosJson.getJSONObject(i), i)
            }

            val audioJson = json.optJSONObject("audio")
            val audio = if (audioJson == null || audioJson.isNull("path")) {
                null
            } else {
                AudioRenderSpec(
                    path = audioJson.getString("path"),
                    volume = audioJson.optDouble("volume", 1.0),
                    fadeIn = audioJson.optDouble("fadeIn", 0.5),
                    fadeOut = audioJson.optDouble("fadeOut", 1.0),
                    trimStart = audioJson.optDouble("trimStart", 0.0),
                    startOffset = audioJson.optDouble("startOffset", 0.0),
                    trimEnd = if (audioJson.has("trimEnd") && !audioJson.isNull("trimEnd")) {
                        audioJson.getDouble("trimEnd")
                    } else {
                        null
                    },
                    loop = audioJson.optBoolean("loop", true),
                    bitrate = audioJson.optInt("bitrate", 192000),
                )
            }

            val watermarkJson = json.optJSONObject("watermark")
            val watermark = if (watermarkJson == null ||
                watermarkJson.optString("text").isNullOrBlank()
            ) {
                null
            } else {
                WatermarkSpec(
                    text = watermarkJson.getString("text"),
                    fontScale = watermarkJson.optDouble("fontScale", 0.055)
                        .coerceIn(0.01, 0.25),
                    opacity = watermarkJson.optDouble("opacity", 0.85)
                        .coerceIn(0.0, 1.0),
                    position = watermarkJson.optInt("position", 8).coerceIn(0, 8),
                    start = watermarkJson.optDouble("start", 0.0).coerceAtLeast(0.0),
                    end = watermarkJson.optDouble("end", 0.0),
                )
            }

            return ExportRequest(
                projectId = json.optString("projectId", "unknown"),
                projectSeed = json.optLong("projectSeed", 0L),
                outputPath = requiredString("outputPath"),
                width = width,
                height = height,
                fps = fps,
                codec = json.optString("codec", "h264"),
                bitrate = json.optInt("bitrate", 8_000_000),
                aspect = json.optDouble("aspect", width.toDouble() / height),
                totalDuration = json.optDouble("totalDuration", 0.0),
                frameCount = json.optInt("frameCount", 0),
                photos = photos,
                audio = audio,
                watermark = watermark,
            )
        }

        private fun parsePhoto(obj: JSONObject, index: Int): PhotoRenderSpec {
            val id = obj.optString("id").takeIf { it.isNotEmpty() }
                ?: throw ExportRequestException("photo[$index] has no id")
            val path = obj.optString("path").takeIf { it.isNotEmpty() }
                ?: throw ExportRequestException("photo[$index] ('$id') has no path")
            val duration = obj.optDouble("duration", 0.0)
            if (duration <= 0.0) {
                throw ExportRequestException(
                    "photo '$id' has invalid duration $duration",
                )
            }
            val kfArray: JSONArray = obj.optJSONArray("keyframes")
                ?: throw ExportRequestException("photo '$id' has no keyframes")
            if (kfArray.length() < 2) {
                throw ExportRequestException(
                    "photo '$id' needs at least 2 keyframes, got ${kfArray.length()}",
                )
            }
            val kfs = ArrayList<Keyframe>(kfArray.length())
            for (k in 0 until kfArray.length()) {
                kfs += parseKeyframe(kfArray.getJSONObject(k), id)
            }
            val sorted = try {
                sortAndValidateKeyframes(kfs)
            } catch (e: IllegalArgumentException) {
                throw ExportRequestException("photo '$id': ${e.message}")
            }

            val trJson = obj.optJSONObject("transition")
            val transition = if (trJson == null) {
                null
            } else {
                TransitionSpec(
                    type = TransitionType.parse(trJson.optString("type")),
                    duration = trJson.optDouble("duration", 0.6),
                )
            }

            // Unknown/foreign path data: drop the path, keep the baked
            // keyframes (lenient load, spec §12.1).
            val pathJson = obj.optJSONObject("motionPath")
            val motionPath = if (pathJson == null) {
                null
            } else {
                try {
                    MotionPathSpec.fromJson(pathJson)
                } catch (e: Exception) {
                    // Lenient load (spec §12.1): unknown presets AND
                    // malformed point data both fall back to keyframes —
                    // a bad path must never fail the whole request.
                    null
                }
            }

            return PhotoRenderSpec(
                id = id,
                path = path,
                width = obj.optInt("width", 0),
                height = obj.optInt("height", 0),
                duration = duration,
                order = obj.optInt("order", index),
                rotationDegrees = obj.optInt("rotationDegrees", 0),
                motionType = MotionType.parse(obj.optString("motionType")),
                intensity = obj.optDouble("intensity", 0.6),
                keyframes = sorted,
                transition = transition,
                expectedFitIw = if (obj.has("expectedFitIw")) obj.getDouble("expectedFitIw") else null,
                expectedFitIh = if (obj.has("expectedFitIh")) obj.getDouble("expectedFitIh") else null,
                motionPath = motionPath,
                zoomFactor = obj.optDouble("zoomFactor", 1.0).coerceIn(0.5, 3.0),
                opacity = obj.optDouble("opacity", 1.0).coerceIn(0.2, 1.0),
            )
        }

        private fun parseKeyframe(obj: JSONObject, photoId: String): Keyframe {
            if (!obj.has("time") || !obj.has("scale")) {
                throw ExportRequestException("photo '$photoId' has a malformed keyframe")
            }
            val curve = obj.optJSONArray("curve")?.let { arr ->
                DoubleArray(arr.length()) { arr.getDouble(it) }
            }
            return Keyframe(
                time = obj.getDouble("time"),
                x = obj.optDouble("x", 0.0),
                y = obj.optDouble("y", 0.0),
                scale = obj.getDouble("scale"),
                rotation = obj.optDouble("rotation", 0.0),
                easing = Easing.parse(obj.optString("easing")),
                curve = curve,
            )
        }
    }

    /**
     * Checks the derived values Dart published. A mismatch means the two
     * runtimes computed different fits, which would put the preview and the
     * export out of sync — fail loudly instead.
     */
    @Throws(ExportRequestException::class)
    fun assertFitsMatch(tolerance: Double = 1e-6) {
        val vp = viewport
        photos.forEach { p ->
            if (p.width <= 0 || p.height <= 0) return@forEach
            val fit = ImageFit.make(p.width, p.height, vp)
            p.expectedFitIw?.let {
                if (kotlin.math.abs(it - fit.iw) > tolerance) {
                    throw ExportRequestException(
                        "photo '${p.id}' fit mismatch: request iw=$it, " +
                            "renderer iw=${fit.iw} (aspect ${vp.aspect})",
                    )
                }
            }
            p.expectedFitIh?.let {
                if (kotlin.math.abs(it - fit.ih) > tolerance) {
                    throw ExportRequestException(
                        "photo '${p.id}' fit mismatch: request ih=$it, " +
                            "renderer ih=${fit.ih} (aspect ${vp.aspect})",
                    )
                }
            }
        }
    }

    /** Sanity checks that do not depend on file contents. */
    @Throws(ExportRequestException::class)
    fun validate() {
        val expectedTotal = photos.sumOf { it.duration }
        if (kotlin.math.abs(expectedTotal - totalDuration) > 0.01) {
            throw ExportRequestException(
                "duration mismatch: photos sum to $expectedTotal, request says $totalDuration",
            )
        }
        val expectedFrames = Math.round(totalDuration * fps).toInt()
        if (frameCount > 0 && kotlin.math.abs(expectedFrames - frameCount) > 1) {
            throw ExportRequestException(
                "frame count mismatch: request $frameCount, computed $expectedFrames",
            )
        }
        val timeline = Timeline(photos.map { it.duration }, photos.mapIndexed { i, p ->
            p.transition ?: TransitionSpec(TransitionType.NONE, 0.0)
        }.let { list -> list.dropLast(1) })
        if (kotlin.math.abs(timeline.totalDuration - totalDuration) > 0.01) {
            throw ExportRequestException("timeline mismatch")
        }
    }
}
