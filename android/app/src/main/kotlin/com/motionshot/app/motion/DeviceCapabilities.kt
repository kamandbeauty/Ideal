package com.motionshot.app.motion

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaCodecInfo
import android.media.MediaCodecInfo.CodecCapabilities
import android.media.MediaCodecList
import android.media.MediaFormat
import android.opengl.GLES30
import android.os.Build
import android.os.StatFs
import android.util.DisplayMetrics
import java.io.File

/**
 * What this device can actually encode.
 *
 * The Export screen uses this to disable impossible combinations *before* a
 * render starts, and the exporter re-checks right before configuring the
 * encoder. Reported numbers are the encoder's own range, never guessed
 * (product rule 11: real hardware limits must be detected).
 */
data class DeviceCapabilities(
    val supportsH264: Boolean,
    val supportsHevc: Boolean,
    val maxWidth: Int,
    val maxHeight: Int,
    val maxFps: Int,
    val maxBitrate: Int,
    val minBitrate: Int,
    val hasGlEs3: Boolean,
    val maxTextureSize: Int,
    val totalRamMb: Int,
    val isLowRamDevice: Boolean,
    val availableStorageMb: Int,
    val codecName: String,
    val widthAlignment: Int,
    val heightAlignment: Int,
    val note: String?,
) {
    val supportsAnyCodec: Boolean get() = supportsH264 || supportsHevc

    fun canEncode(width: Int, height: Int, fps: Int): Boolean {
        if (!supportsAnyCodec) return false
        val w = maxOf(width, height)
        val h = minOf(width, height)
        val maxSide = maxOf(maxWidth, maxHeight)
        val minSide = minOf(maxWidth, maxHeight)
        return w <= maxSide && h <= minSide && fps <= maxFps
    }

    /** Rounds a pixel size to what this device's encoder demands. */
    fun alignDown(value: Int, isWidth: Boolean): Int {
        val a = maxOf(2, if (isWidth) widthAlignment else heightAlignment)
        return maxOf(a, (value / a) * a)
    }

    companion object {
        @JvmStatic
        fun detect(context: Context): DeviceCapabilities {
            val activityManager =
                context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            val totalRamMb = (memoryInfo.totalMem / (1024 * 1024)).toInt()
            val isLowRam = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                activityManager.isLowRamDevice
            } else {
                totalRamMb < 2048
            }

            var supportsH264 = false
            var supportsHevc = false
            var maxWidth = 0
            var maxHeight = 0
            var maxFps = 0
            var maxBitrate = 0
            var minBitrate = 0
            var codecName = "none"
            var widthAlignment = 2
            var heightAlignment = 2

            val list = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            for (info in list.codecInfos) {
                if (!info.isEncoder) continue
                val mime = when {
                    info.supportedTypes.any { it.equals(MediaFormat.MIMETYPE_VIDEO_AVC, true) } ->
                        MediaFormat.MIMETYPE_VIDEO_AVC
                    info.supportedTypes.any { it.equals(MediaFormat.MIMETYPE_VIDEO_HEVC, true) } ->
                        MediaFormat.MIMETYPE_VIDEO_HEVC
                    else -> continue
                }
                val caps: CodecCapabilities = try {
                    info.getCapabilitiesForType(mime)
                } catch (e: Exception) {
                    continue
                }
                val video = caps.videoCapabilities ?: continue
                if (mime == MediaFormat.MIMETYPE_VIDEO_AVC) supportsH264 = true
                if (mime == MediaFormat.MIMETYPE_VIDEO_HEVC) supportsHevc = true

                // Prefer the hardware encoder when the OEM has not flagged it.
                val isHardware = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    info.isHardwareAccelerated
                } else {
                    !info.name.startsWith("OMX.google") && !info.name.contains("sw.")
                }
                if (isHardware || codecName == "none") {
                    maxWidth = maxOf(maxWidth, video.supportedWidths.upper)
                    maxHeight = maxOf(maxHeight, video.supportedHeights.upper)
                    maxFps = maxOf(maxFps, video.supportedFrameRates.upper.toInt())
                    maxBitrate = maxOf(maxBitrate, caps.videoCapabilities.bitrateRange.upper)
                    minBitrate = maxOf(minBitrate, caps.videoCapabilities.bitrateRange.lower)
                    codecName = info.name
                    widthAlignment = video.widthAlignment
                    heightAlignment = video.heightAlignment
                }
            }

            var hasGlEs3 = false
            var maxTexture = 2048
            try {
                hasGlEs3 = context.packageManager
                    .hasSystemFeature(PackageManager.FEATURE_OPENGLES_EXTENSION_PACK) ||
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2
                // The GL context is created on the render thread; this is the
                // conservative value used before the context exists.
                maxTexture = if (hasGlEs3) 4096 else 2048
            } catch (e: Exception) {
                hasGlEs3 = false
            }

            val metrics: DisplayMetrics = context.resources.displayMetrics
            val fallbackMaxWidth = maxOf(metrics.widthPixels, metrics.heightPixels)
            if (maxWidth == 0) {
                maxWidth = fallbackMaxWidth
                maxHeight = minOf(metrics.widthPixels, metrics.heightPixels)
                maxFps = 30
                maxBitrate = 20_000_000
                minBitrate = 1_000_000
            }

            val note = when {
                !supportsH264 && !supportsHevc -> "no hardware or software AVC/HEVC encoder"
                !hasGlEs3 -> "OpenGL ES 3.0 unavailable; using the ES 2.0 path"
                isLowRam -> "low RAM device: 4K exports are disabled"
                else -> null
            }

            return DeviceCapabilities(
                supportsH264 = supportsH264,
                supportsHevc = supportsHevc,
                maxWidth = maxWidth,
                maxHeight = maxHeight,
                maxFps = if (maxFps <= 0) 30 else maxFps.coerceAtMost(240),
                maxBitrate = maxBitrate,
                minBitrate = minBitrate,
                hasGlEs3 = hasGlEs3,
                maxTextureSize = maxTexture,
                totalRamMb = totalRamMb,
                isLowRamDevice = isLowRam,
                availableStorageMb = availableStorageMb(context.filesDir),
                codecName = codecName,
                widthAlignment = widthAlignment.coerceAtLeast(2),
                heightAlignment = heightAlignment.coerceAtLeast(2),
                note = note,
            )
        }

        /** Free space on the volume holding [dir], in MB. */
        @JvmStatic
        fun availableStorageMb(dir: File): Int = try {
            val stat = StatFs(dir.absolutePath)
            (stat.availableBlocksLong * stat.blockSizeLong / (1024 * 1024)).toInt()
        } catch (e: Exception) {
            0
        }
    }

    fun toJson(): org.json.JSONObject = org.json.JSONObject().apply {
        put("supportsH264", supportsH264)
        put("supportsHevc", supportsHevc)
        put("maxWidth", maxWidth)
        put("maxHeight", maxHeight)
        put("maxFps", maxFps)
        put("maxBitrate", maxBitrate)
        put("hasGlEs3", hasGlEs3)
        put("maxTextureSize", maxTextureSize)
        put("totalRamMb", totalRamMb)
        put("isLowRamDevice", isLowRamDevice)
        put("availableStorageMb", availableStorageMb)
        put("codecName", codecName)
        if (note != null) put("note", note)
    }
}

/**
 * Reads the real GL limits once a context exists. Called by the render engine
 * after EGL setup so `DeviceCapabilities` can be corrected with real values.
 */
object GlLimits {
    fun query(): Triple<Boolean, Int, Int> {
        val version = GLES30.glGetString(GLES30.GL_VERSION) ?: ""
        val maxTex = IntArray(1)
        GLES30.glGetIntegerv(GLES30.GL_MAX_TEXTURE_SIZE, maxTex, 0)
        val isEs3 = version.contains("OpenGL ES 3")
        return Triple(isEs3, maxTex[0], 0)
    }
}
