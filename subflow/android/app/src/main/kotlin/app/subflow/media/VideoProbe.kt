package app.subflow.media

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log

/**
 * Reads the real technical properties of a video file.
 *
 * MediaMetadataRetriever gives duration/rotation/bitrate, MediaExtractor adds
 * frame rate and colour transfer (needed to tell the user the truth about HDR),
 * and the content resolver supplies the display name and size. Nothing is
 * guessed: unknown values are reported as 0 and the UI shows "نامشخص".
 */
object VideoProbe {
    private const val TAG = "SubFlowProbe"

    /**
     * Colour transfer values from MediaFormat. ST2084 (PQ) and HLG are the two
     * HDR transfer functions Android exposes.
     */
    private const val TRANSFER_ST2084 = 6
    private const val TRANSFER_HLG = 7

    fun probe(context: Context, uri: Uri): Map<String, Any?> {
        val result = HashMap<String, Any?>()
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(context, uri)

            val rawWidth = retriever.intValue(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val rawHeight = retriever.intValue(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val rotation = normalizeRotation(
                retriever.intValue(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            )
            val durationMs = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L

            // Apply rotation so width/height are *display* geometry.
            val rotated = rotation == 90 || rotation == 270
            result["width"] = if (rotated) rawHeight else rawWidth
            result["height"] = if (rotated) rawWidth else rawHeight
            result["rotationDegrees"] = if (rotated) rotation else 0
            result["durationUs"] = durationMs * 1000L
            result["bitrateBps"] = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
                ?.toLongOrNull() ?: 0L
            result["videoCodec"] = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
                ?.let { shortMime(it) }
        } catch (error: Exception) {
            Log.e(TAG, "MediaMetadataRetriever failed for $uri", error)
            throw IllegalStateException("این فایل با کدک‌های پشتیبانی‌شده خوانده نشد", error)
        } finally {
            runCatching { retriever.release() }
        }

        var fpsMilli = 0
        var hdr = false
        var colorTransfer: String? = null
        var audioCodec: String? = null
        var audioSampleRate = 0
        var audioChannels = 0
        var audioBitrate = 0L

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(context, uri, null)
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                when {
                    mime.startsWith("video/") -> {
                        if (fpsMilli == 0) fpsMilli = readFrameRateMilli(format)
                        val transfer = format.intOrNull(MediaFormat.KEY_COLOR_TRANSFER)
                        if (transfer != null) {
                            colorTransfer = transferName(transfer)
                            if (transfer == TRANSFER_ST2084 || transfer == TRANSFER_HLG) hdr = true
                        }
                        if (result["videoCodec"] == null) result["videoCodec"] = shortMime(mime)
                    }
                    mime.startsWith("audio/") && audioCodec == null -> {
                        audioCodec = shortMime(mime)
                        audioSampleRate = format.intOrNull(MediaFormat.KEY_SAMPLE_RATE) ?: 0
                        audioChannels = format.intOrNull(MediaFormat.KEY_CHANNEL_COUNT) ?: 0
                        audioBitrate = format.intOrNull(MediaFormat.KEY_BIT_RATE)?.toLong() ?: 0L
                    }
                }
            }
        } catch (error: Exception) {
            Log.w(TAG, "MediaExtractor could not read track formats for $uri", error)
        } finally {
            runCatching { extractor.release() }
        }

        result["fpsMilli"] = fpsMilli
        result["hdr"] = hdr
        result["colorTransfer"] = colorTransfer
        result["audioCodec"] = audioCodec
        result["audioSampleRate"] = audioSampleRate
        result["audioChannels"] = audioChannels
        result["audioBitrateBps"] = audioBitrate
        result["uri"] = uri.toString()

        val meta = queryFileMeta(context, uri)
        result["displayName"] = meta.first
        result["sizeBytes"] = meta.second
        result["rawJson"] = buildString {
            append("{\"rotation\":").append(result["rotationDegrees"])
            append(",\"colorTransfer\":\"").append(colorTransfer ?: "").append('"')
            append(",\"fpsMilli\":").append(fpsMilli)
            append('}')
        }
        return result
    }

    fun exists(context: Context, uri: String): Boolean {
        return try {
            val parsed = Uri.parse(uri)
            context.contentResolver.openAssetFileDescriptor(parsed, "r")?.use { true } ?: false
        } catch (error: Exception) {
            Log.w(TAG, "fileExists failed for $uri", error)
            false
        }
    }

    private fun queryFileMeta(context: Context, uri: Uri): Pair<String, Long> {
        var name = uri.lastPathSegment ?: "video"
        var size = 0L
        try {
            context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) name = cursor.getString(nameIndex) ?: name
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
                }
            }
        } catch (error: Exception) {
            Log.w(TAG, "queryFileMeta failed for $uri", error)
        }
        return name to size
    }

    /** KEY_FRAME_RATE is a float on most devices, an int on some vendors. */
    private fun readFrameRateMilli(format: MediaFormat): Int {
        format.intOrNull(MediaFormat.KEY_FRAME_RATE)?.let { return (it * 1000) }
        return try {
            if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                (format.getFloat(MediaFormat.KEY_FRAME_RATE) * 1000).toInt()
            } else {
                0
            }
        } catch (error: Exception) {
            Log.w(TAG, "frame rate unreadable", error)
            0
        }
    }

    private fun MediaFormat.intOrNull(key: String): Int? =
        if (containsKey(key)) {
            try {
                getInteger(key)
            } catch (error: Exception) {
                try {
                    getFloat(key).toInt()
                } catch (ignored: Exception) {
                    null
                }
            }
        } else {
            null
        }

    private fun MediaMetadataRetriever.intValue(key: Int): Int =
        extractMetadata(key)?.toIntOrNull() ?: 0

    private fun normalizeRotation(value: Int): Int = ((value % 360) + 360) % 360

    private fun shortMime(mime: String): String = when {
        mime.contains("avc") || mime.contains("avc1") -> "H.264"
        mime.contains("hevc") || mime.contains("h265") -> "H.265/HEVC"
        mime.contains("av01") -> "AV1"
        mime.contains("vp9") -> "VP9"
        mime.contains("mp4a") -> "AAC"
        mime.contains("opus") -> "Opus"
        mime.contains("vorbis") -> "Vorbis"
        else -> mime.substringAfter('/')
    }

    private fun transferName(transfer: Int): String = when (transfer) {
        1 -> "SDR_BT709"
        6 -> "HDR_ST2084"
        7 -> "HDR_HLG"
        8 -> "SDR_SRGB"
        else -> "TRANSFER_$transfer"
    }
}
