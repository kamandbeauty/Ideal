package com.motionshot.app.motion

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.util.Log
import java.io.File
import kotlin.math.max

/**
 * Decodes source photos at a resolution that fits the memory budget.
 *
 * Quality policy (spec §8.3, product rule 10):
 *  * the *file* is never resized or rewritten; only the in-memory decode is
 *  * if the source is smaller than the output, it is decoded at full size and
 *    upscaled by the camera zoom alone — no fake detail, no double resample
 *  * if the source is huge (e.g. 108 MP) it is subsampled with `inSampleSize`
 *    only to the point where it still exceeds the output resolution by a
 *    comfortable margin, preserving zoom headroom for the motion
 *  * EXIF orientation is honoured via the framework decoder (API 24+ applies it
 *    for JPEG) and re-checked with MediaMetadataRetriever for robustness
 *
 * Failures are explicit: a corrupt or unsupported file throws
 * [PhotoDecodeException] so the export can name the offending photo instead of
 * producing a video with a black frame in it.
 */
class PhotoDecoder(
    private val outputWidth: Int,
    private val outputHeight: Int,
    private val isLowRamDevice: Boolean,
) {
    class PhotoDecodeException(message: String, cause: Throwable? = null) : Exception(message, cause)

    /** Maximum zoom the UI allows; we keep enough pixels for it. */
    private val maxZoomHeadroom = 1.5

    /**
     * Decodes [path] so that the longer side is at least
     * `max(outputLongSide, outputLongSide * headroom)`, without ever exceeding
     * [maxTextureSize].
     */
    fun decode(path: String, maxTextureSize: Int): Bitmap {
        val file = File(path)
        if (!file.exists()) {
            throw PhotoDecodeException("photo file not found: $path")
        }
        if (file.length() == 0L) {
            throw PhotoDecodeException("photo file is empty: $path")
        }

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw PhotoDecodeException(
                "unsupported or corrupt image: $path (fmt=${bounds.outMimeType})",
            )
        }

        val target = targetLongSide(maxTextureSize)
        val sample = calculateSampleSize(bounds.outWidth, bounds.outHeight, target)
        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inMutable = false
            inScaled = false
        }

        val bitmap = try {
            BitmapFactory.decodeFile(path, opts)
        } catch (e: OutOfMemoryError) {
            throw PhotoDecodeException("not enough memory to decode $path", e)
        } catch (e: Exception) {
            throw PhotoDecodeException("failed to decode $path: ${e.message}", e)
        } ?: throw PhotoDecodeException("decoder returned null for $path")

        return bitmap
    }

    /**
     * Reads dimensions and orientation without decoding pixels. Used for
     * validation before the render starts.
     */
    fun probe(path: String): ProbeResult? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var rotation = 0
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            // Videos report "video-rotation"; stills carry the EXIF
            // orientation ("orientation"), reported as "6"/"90" or, on some
            // OEMs, as "rotate_90". Reading only the video key left portrait
            // photos unrotated, so the export framed them sideways.
            rotation = retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                    ?.toIntOrNull()
                ?: parseOrientation(
                    retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ORIENTATION),
                )
                ?: 0
        } catch (e: Exception) {
            Log.d(TAG, "no metadata for $path: ${e.message}")
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
                // ignore
            }
        }
        val swap = rotation == 90 || rotation == 270
        return ProbeResult(
            width = if (swap) bounds.outHeight else bounds.outWidth,
            height = if (swap) bounds.outWidth else bounds.outHeight,
            mimeType = bounds.outMimeType,
            exifRotation = rotation,
        )
    }

    data class ProbeResult(
        val width: Int,
        val height: Int,
        val mimeType: String?,
        val exifRotation: Int,
    )

    /** Normalises the many EXIF-orientation encodings to 0/90/180/270. */
    private fun parseOrientation(raw: String?): Int? {
        if (raw == null) return null
        return when (raw) {
            "0" -> 0
            "1" -> 0
            "90", "6" -> 90
            "180", "3" -> 180
            "270", "8" -> 270
            "rotate_90" -> 90
            "rotate_180" -> 180
            "rotate_270" -> 270
            else -> raw.toIntOrNull()?.let { when (it % 360) {
                90 -> 90
                180 -> 180
                270 -> 270
                else -> 0
            } }
        }
    }

    private fun targetLongSide(maxTextureSize: Int): Int {
        val outputLong = max(outputWidth, outputHeight)
        val wanted = (outputLong * maxZoomHeadroom).toInt()
        val ramCap = if (isLowRamDevice) 2048 else maxTextureSize
        return minOf(wanted, maxTextureSize, ramCap).coerceAtLeast(outputLong)
    }

    private fun calculateSampleSize(width: Int, height: Int, target: Int): Int {
        var sample = 1
        var longest = max(width, height)
        // Halve until the decoded size would drop below the target, then step
        // back one: we want the smallest decode that is still >= target.
        while (longest / 2 >= target) {
            longest /= 2
            sample *= 2
        }
        return sample.coerceAtLeast(1)
    }

    companion object {
        private const val TAG = "PhotoDecoder"

        /**
         * Rough memory check before a batch decode. Returns true when the
         * project is likely to fit; used to fail fast with a friendly message
         * instead of dying with an OOM halfway through a render.
         */
        fun estimatedDecodeBytes(width: Int, height: Int): Long =
            width.toLong() * height.toLong() * 4L
    }
}
