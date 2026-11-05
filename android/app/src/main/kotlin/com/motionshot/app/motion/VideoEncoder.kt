package com.motionshot.app.motion

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.util.Log
import android.view.Surface
import java.nio.ByteBuffer

/**
 * H.264 / HEVC hardware encoder.
 *
 * Responsibilities:
 *  * pick the real encoder for the requested mime, preferring hardware
 *  * negotiate a *supported* width/height/fps/bitrate (never ask for something
 *    the device cannot do — the caller has usually pre-checked, but driver
 *    range objects are the authority)
 *  * configure a `Surface` input so the GPU renders straight into the encoder
 *  * drain output buffers into a callback with exact presentation timestamps
 *  * never leave a half-configured codec behind on failure
 *
 * The output callback receives `(ByteBufferView, info)` for every encoded
 * sample; the muxer writes them. This class knows nothing about MP4.
 */
class VideoEncoder(
    private val mime: String,
    private val requestedWidth: Int,
    private val requestedHeight: Int,
    private val fps: Int,
    private val requestedBitrate: Int,
    private val iframeIntervalSeconds: Int = 2,
) {
    class EncoderException(message: String, cause: Throwable? = null) : Exception(message, cause)

    /** A single encoded sample plus the flags the muxer needs. */
    class Sample(
        val bytes: ByteArray,
        val presentationTimeUs: Long,
        val flags: Int,
        val isConfig: Boolean,
    )

    private var codec: MediaCodec? = null
    private var inputSurface: Surface? = null
    private var started = false
    private var released = false

    var actualWidth: Int = 0
        private set
    var actualHeight: Int = 0
        private set
    var actualBitrate: Int = 0
        private set
    var actualFps: Int = 0
        private set
    var codecName: String = ""
        private set
    var colorFormat: Int = MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface
        private set
    var outputFormat: MediaFormat? = null
        private set

    /** Invoked once when MediaCodec publishes its real CSD-bearing output format. */
    var onOutputFormat: ((MediaFormat) -> Unit)? = null

    /** The surface the renderer must draw into. */
    val surface: Surface
        get() = inputSurface ?: throw EncoderException("encoder surface not created")

    fun configure(): Surface {
        val mediaCodecInfo: MediaCodecInfo = selectEncoder(mime)
            ?: throw EncoderException("no $mime encoder available on this device")

        val caps = try {
            mediaCodecInfo.getCapabilitiesForType(mime)
        } catch (e: Exception) {
            throw EncoderException("encoder ${mediaCodecInfo.name} refuses $mime", e)
        }
        val video = caps.videoCapabilities
            ?: throw EncoderException("encoder ${mediaCodecInfo.name} has no video caps")
        val (w, h) = align(video, requestedWidth, requestedHeight)
        val supportedFps = fps.coerceIn(1, video.supportedFrameRates.upper.toInt().coerceAtLeast(fps))
        val bitrate = requestedBitrate.coerceIn(
            caps.videoCapabilities.bitrateRange.lower,
            caps.videoCapabilities.bitrateRange.upper,
        )

        val format = MediaFormat.createVideoFormat(mime, w, h).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, supportedFps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, iframeIntervalSeconds)
            // Quality-first: constant bitrate would waste bits on static shots
            // and starve pans, which is exactly where banding shows up.
            setInteger(
                MediaFormat.KEY_BITRATE_MODE,
                MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR,
            )
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                setInteger(MediaFormat.KEY_PRIORITY, 0) // realtime
            }
            if (mime == MediaFormat.MIMETYPE_VIDEO_HEVC &&
                android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N
            ) {
                setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.HEVCProfileMain)
            }
            if (mime == MediaFormat.MIMETYPE_VIDEO_AVC) {
                setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.AVCProfileHigh)
                setInteger(MediaFormat.KEY_LEVEL, MediaCodecInfo.CodecProfileLevel.AVCLevel41)
            }
        }

        val c = try {
            MediaCodec.createByCodecName(mediaCodecInfo.name)
        } catch (e: Exception) {
            throw EncoderException("cannot open encoder ${mediaCodecInfo.name}", e)
        }

        try {
            c.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            val s = c.createInputSurface()
                ?: throw EncoderException("encoder did not provide an input surface")
            c.start()
            inputSurface = s
            codec = c
            started = true
            actualWidth = w
            actualHeight = h
            actualBitrate = bitrate
            actualFps = supportedFps
            codecName = mediaCodecInfo.name
            Log.i(
                TAG,
                "encoder ${mediaCodecInfo.name} $mime ${w}x$h @${supportedFps} " +
                    "${bitrate / 1000}kbps",
            )
            return s
        } catch (e: Exception) {
            try {
                c.stop()
            } catch (ignored: Exception) {
            }
            c.release()
            throw EncoderException("failed to configure encoder: ${e.message}", e)
        }
    }

    /**
     * Drains all currently available output. Blocking drain with a short timeout
     * keeps the muxer's sample order intact and applies back-pressure to the
     * renderer if the encoder falls behind.
     */
    fun drain(endOfStream: Boolean, consumer: (Sample) -> Unit) {
        val c = codec ?: return
        if (!started) return
        val info = MediaCodec.BufferInfo()
        val timeoutUs = if (endOfStream) 10_000L else 0L
        while (true) {
            val index = try {
                c.dequeueOutputBuffer(info, timeoutUs)
            } catch (e: IllegalStateException) {
                if (released) return
                throw EncoderException("encoder state error while draining", e)
            }
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                    if (isEndOfStreamSignalled) return
                    return
                }
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val fmt = c.outputFormat
                    outputFormat = fmt
                    Log.i(TAG, "encoder output format: $fmt")
                    onOutputFormat?.invoke(fmt)
                }
                index >= 0 -> {
                    val buffer: ByteBuffer = c.getOutputBuffer(index)
                        ?: continue
                    if (info.size > 0) {
                        val bytes = ByteArray(info.size)
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        buffer.get(bytes)
                        consumer(
                            Sample(
                                bytes = bytes,
                                presentationTimeUs = info.presentationTimeUs,
                                flags = info.flags,
                                isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0,
                            ),
                        )
                    }
                    c.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        isEndOfStreamSignalled = true
                        return
                    }
                }
            }
        }
    }

    private var isEndOfStreamSignalled = false

    /** Signals end of stream and drains everything remaining. */
    fun finish(consumer: (Sample) -> Unit) {
        val c = codec ?: return
        if (!started) return
        try {
            c.signalEndOfInputStream()
        } catch (e: Exception) {
            Log.w(TAG, "signalEndOfInputStream failed: ${e.message}")
        }
        val deadline = System.currentTimeMillis() + 10_000
        while (!isEndOfStreamSignalled && System.currentTimeMillis() < deadline) {
            drain(endOfStream = true, consumer = consumer)
        }
        if (!isEndOfStreamSignalled) {
            Log.w(TAG, "encoder did not report EOS before the deadline")
        }
    }

    /** Stops and frees the codec. Safe to call twice. */
    fun release() {
        if (released) return
        released = true
        started = false
        inputSurface?.release()
        inputSurface = null
        val c = codec
        codec = null
        if (c != null) {
            try {
                c.stop()
            } catch (e: Exception) {
                Log.d(TAG, "codec stop: ${e.message}")
            }
            try {
                c.release()
            } catch (e: Exception) {
                Log.d(TAG, "codec release: ${e.message}")
            }
        }
    }

    private fun align(
        video: MediaCodecInfo.VideoCapabilities,
        width: Int,
        height: Int,
    ): Pair<Int, Int> {
        val wa = video.widthAlignment.coerceAtLeast(2)
        val ha = video.heightAlignment.coerceAtLeast(2)
        var w = (width / wa) * wa
        var h = (height / ha) * ha
        // Step down one alignment at a time until the range accepts the size.
        var guard = 0
        while (!video.isSizeSupported(w, h) && guard < 64) {
            if (w > h) w -= wa else h -= ha
            if (w < 16 || h < 16) {
                throw EncoderException("cannot find a supported size near ${width}x$height")
            }
            guard++
        }
        if (!video.isSizeSupported(w, h)) {
            throw EncoderException(
                "encoder supports ${video.supportedWidths} x ${video.supportedHeights}, " +
                    "not ${width}x$height",
            )
        }
        return w to h
    }

    private fun selectEncoder(mime: String): MediaCodecInfo? {
        val list = MediaCodecListCompat.encoders()
        var softwareFallback: MediaCodecInfo? = null
        for (info in list) {
            if (!info.supportedTypes.any { it.equals(mime, ignoreCase = true) }) continue
            val isSoftware = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                info.isSoftwareOnly
            } else {
                info.name.startsWith("OMX.google") || info.name.contains(".sw.")
            }
            if (!isSoftware) return info
            softwareFallback = info
        }
        return softwareFallback
    }

    private object MediaCodecListCompat {
        fun encoders(): List<MediaCodecInfo> {
            val list = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            return list.codecInfos.filter { it.isEncoder }
        }
    }

    companion object {
        private const val TAG = "VideoEncoder"
    }
}
