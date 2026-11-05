package com.motionshot.app.motion

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.util.Log
import org.json.JSONObject
import java.io.File

/** A real, measured description of a produced MP4. */
data class ProbeResult(
    val path: String,
    val width: Int,
    val height: Int,
    val fps: Int,
    val durationMs: Long,
    val frameCount: Int,
    val bitrate: Int,
    val codec: String,
    val sizeBytes: Long,
    val hasAudio: Boolean,
    val audioCodec: String?,
    val rotation: Int,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("path", path)
        put("width", width)
        put("height", height)
        put("fps", fps)
        put("durationMs", durationMs)
        put("frameCount", frameCount)
        put("bitrate", bitrate)
        put("codec", codec)
        put("sizeBytes", sizeBytes)
        put("hasAudio", hasAudio)
        if (audioCodec != null) put("audioCodec", audioCodec)
        put("rotation", rotation)
    }
}

/**
 * Verifies an exported file by reading it back with the platform demuxer.
 *
 * This is what makes "the export succeeded" a measured fact rather than a
 * hopeful one: the frame count is counted by walking the actual sample table,
 * and the duration comes from the container. A file that fails these checks is
 * never presented to the user as a finished video.
 */
object MediaProbe {

    @JvmStatic
    fun probe(context: Context, path: String): ProbeResult? {
        val file = File(path)
        if (!file.exists() || file.length() < 4096) return null

        var width = 0
        var height = 0
        var rotation = 0
        var durationMs = 0L
        var bitrate = 0
        var hasAudio = false
        var audioCodec: String? = null
        var codec = "unknown"

        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: 0
            height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: 0
            rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            bitrate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
                ?.toIntOrNull() ?: 0
        } catch (e: Exception) {
            Log.e(TAG, "retriever failed: ${e.message}")
            return null
        } finally {
            try {
                retriever.release()
            } catch (ignored: Exception) {
            }
        }

        var fps = 0
        var frameCount = 0
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            var videoTrack = -1
            for (i in 0 until extractor.trackCount) {
                val fmt = extractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/")) {
                    videoTrack = i
                    codec = when {
                        mime.contains("avc") -> "h264"
                        mime.contains("hevc") -> "hevc"
                        else -> mime
                    }
                    if (fmt.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                        fps = try {
                            fmt.getInteger(MediaFormat.KEY_FRAME_RATE)
                        } catch (e: Exception) {
                            fmt.getFloat(MediaFormat.KEY_FRAME_RATE).toInt()
                        }
                    }
                    if (width == 0) {
                        width = fmt.getInteger(MediaFormat.KEY_WIDTH)
                        height = fmt.getInteger(MediaFormat.KEY_HEIGHT)
                    }
                } else if (mime.startsWith("audio/")) {
                    hasAudio = true
                    audioCodec = mime
                }
            }
            if (videoTrack < 0) {
                Log.e(TAG, "no video track in $path")
                return null
            }
            extractor.selectTrack(videoTrack)
            // Count real samples: the only trustworthy frame count.
            while (true) {
                val size = extractor.readSampleData(java.nio.ByteBuffer.allocate(1), 0)
                if (size < 0) break
                frameCount++
                if (!extractor.advance()) break
            }
        } catch (e: Exception) {
            Log.e(TAG, "extractor failed: ${e.message}")
            return null
        } finally {
            try {
                extractor.release()
            } catch (ignored: Exception) {
            }
        }

        if (fps <= 0 && durationMs > 0 && frameCount > 0) {
            fps = Math.round(frameCount * 1000.0 / durationMs).toInt()
        }

        return ProbeResult(
            path = path,
            width = width,
            height = height,
            fps = fps,
            durationMs = durationMs,
            frameCount = frameCount,
            bitrate = bitrate,
            codec = codec,
            sizeBytes = file.length(),
            hasAudio = hasAudio,
            audioCodec = audioCodec,
            rotation = rotation,
        )
    }
}

private const val TAG = "MediaProbe"
