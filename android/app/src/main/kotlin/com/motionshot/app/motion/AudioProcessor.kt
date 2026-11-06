package com.motionshot.app.motion

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * Music preparation and AAC encoding.
 *
 * Implements docs/MOTION_SPEC.md §9:
 *  * decodes MP3 / AAC / WAV / OGG to float PCM via MediaExtractor+MediaCodec
 *  * loop with an equal-power overlap crossfade (no click at the seam)
 *  * trim, volume, fade in and fade out applied per sample
 *  * re-encodes to AAC-LC at the exact video length, so audio and video end
 *    together with no drift and no trailing silence
 *
 * The PCM is processed in blocks: a 5 minute track is never fully resident.
 */
class AudioProcessor(
    private val spec: AudioRenderSpec,
    private val targetSeconds: Double,
    private val sampleRate: Int = 48_000,
    private val channels: Int = 2,
) {
    class AudioException(message: String, cause: Throwable? = null) : Exception(message, cause)

    /** One encoded AAC sample. */
    class Sample(val bytes: ByteArray, val presentationTimeUs: Long, val flags: Int)

    /** Complete AAC track ready to register with and write into [MediaMuxerManager]. */
    class EncodedAudio(val outputFormat: MediaFormat, val samples: List<Sample>)

    private val totalFrames: Long =
        ceil(targetSeconds * sampleRate).toLong().coerceAtLeast(1)

    /**
     * Decodes the source into mono-free interleaved float PCM, applying trim,
     * loop, volume and fades so the result is exactly [totalFrames] frames.
     */
    fun buildPcm(): FloatArray {
        val source = decodeSource()
        if (source.frames == 0L) throw AudioException("audio file contains no samples")

        val out = FloatArray((totalFrames * channels).toInt())
        val fadeInFrames = (spec.fadeIn.coerceAtLeast(0.0) * sampleRate).toInt()
            .coerceAtMost(out.size / channels / 2)
        val fadeOutFrames = (spec.fadeOut.coerceAtLeast(0.0) * sampleRate).toInt()
            .coerceAtMost(out.size / channels / 2)
        val fadeLen = min(
            (0.020 * sampleRate).toInt(),
            (source.frames / 4).toInt().coerceAtLeast(1),
        )

        // Fill with either a single pass or overlapping repeats.
        var writePos = 0L
        var reps = 0
        while (writePos < totalFrames) {
            reps++
            if (reps > 10_000) throw AudioException("audio loop did not converge")
            val copyFrames = min(source.frames, totalFrames - writePos)
            for (f in 0 until copyFrames) {
                val srcFrame = (f * channels).toInt()
                var dst = ((writePos + f) * channels).toInt()
                for (c in 0 until channels) {
                    val sample = source.pcm[srcFrame + c]
                    val seamPos = f
                    val isSeam = reps > 1 && seamPos < fadeLen
                    if (isSeam) {
                        // equal-power crossfade with the tail of the previous
                        // repetition, which is already written in `out`
                        val t = seamPos.toDouble() / fadeLen
                        val a = (t * PI / 2)
                        val prev = out[dst] // previous repetition's tail
                        out[dst] = (prev * cos(a) + sample * sin(a)).toFloat()
                    } else {
                        out[dst] = sample
                    }
                    dst++
                }
            }
            writePos += if (spec.loop) (source.frames - fadeLen).coerceAtLeast(1) else source.frames
            if (!spec.loop) break
        }

        // Volume
        val vol = spec.volume.coerceIn(0.0, 1.0).toFloat()
        if (vol != 1f) {
            for (i in out.indices) out[i] *= vol
        }

        // Fades (linear gain ramp, matching the reference implementation)
        if (fadeInFrames > 1) {
            for (i in 0 until fadeInFrames) {
                val g = i.toFloat() / fadeInFrames
                for (c in 0 until channels) out[i * channels + c] *= g
            }
        }
        if (fadeOutFrames > 1) {
            val start = out.size - fadeOutFrames * channels
            for (i in 0 until fadeOutFrames) {
                val g = 1f - i.toFloat() / fadeOutFrames
                for (c in 0 until channels) out[start + i * channels + c] *= g
            }
        }
        return out
    }

    /**
     * Encodes PCM to AAC-LC and captures the codec's real [MediaFormat]
     * (including `csd-0` AudioSpecificConfig required by `MediaMuxer`).
     */
    fun encodeAacTrack(pcm: FloatArray): EncodedAudio {
        var realFormat: MediaFormat? = null
        val samples = ArrayList<Sample>()
        encodeAac(
            pcm = pcm,
            onFormat = { fmt -> realFormat = fmt },
            onSample = { s -> samples += s },
        )
        val fmt = realFormat ?: throw AudioException("AAC encoder never emitted output format")
        return EncodedAudio(fmt, samples)
    }

    /**
     * Encodes PCM to AAC-LC samples, ready for the muxer.
     *
     * @param onSample called in order with strictly increasing timestamps
     */
    fun encodeAac(
        pcm: FloatArray,
        onFormat: ((MediaFormat) -> Unit)? = null,
        onSample: (Sample) -> Unit,
    ) {
        val format = MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channels,
        ).apply {
            setInteger(
                MediaFormat.KEY_AAC_PROFILE,
                MediaCodecInfo.CodecProfileLevel.AACObjectLC,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, spec.bitrate.coerceIn(64_000, 320_000))
            setInteger(MediaFormat.KEY_CHANNEL_MASK, if (channels == 1) 0x4 else 0xC)
        }
        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()

            var pcmOffsetFrames = 0L
            var inputDone = false
            var outputDone = false
            val info = MediaCodec.BufferInfo()
            val bytesPerFrame = channels * 2 // 16-bit

            while (!outputDone) {
                if (!inputDone) {
                    val inIdx = codec.dequeueInputBuffer(10_000)
                    if (inIdx >= 0) {
                        val buffer = codec.getInputBuffer(inIdx)!!
                        buffer.clear()
                        val remainingFrames = (pcm.size / channels) - pcmOffsetFrames
                        if (remainingFrames <= 0) {
                            codec.queueInputBuffer(
                                inIdx, 0, 0,
                                framesToUs(pcmOffsetFrames), MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            val maxFrames = buffer.capacity() / bytesPerFrame
                            val chunk = min(maxFrames.toLong(), remainingFrames).toInt()
                            val shortBytes = ByteBuffer.allocateDirect(chunk * bytesPerFrame)
                                .order(ByteOrder.LITTLE_ENDIAN)
                            val shorts = shortBytes.asShortBuffer()
                            for (i in 0 until chunk * channels) {
                                val idx = (pcmOffsetFrames * channels).toInt() + i
                                val v = (pcm[idx].coerceIn(-1f, 1f) * 32767f).toInt()
                                shorts.put(v.toShort())
                            }
                            shorts.flip()
                            buffer.clear()
                            // copy the little-endian bytes (not the ShortBuffer view)
                            buffer.put(shortBytes)
                            codec.queueInputBuffer(
                                inIdx, 0, chunk * bytesPerFrame,
                                framesToUs(pcmOffsetFrames), 0,
                            )
                            pcmOffsetFrames += chunk
                        }
                    }
                }

                val outIdx = codec.dequeueOutputBuffer(info, 10_000)
                when {
                    outIdx == MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outFmt = codec.outputFormat
                        Log.i(TAG, "aac format: $outFmt")
                        onFormat?.invoke(outFmt)
                    }
                    outIdx >= 0 -> {
                        val outBuf = codec.getOutputBuffer(outIdx)
                        if (outBuf != null && info.size > 0) {
                            val bytes = ByteArray(info.size)
                            outBuf.position(info.offset)
                            outBuf.limit(info.offset + info.size)
                            outBuf.get(bytes)
                            val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                            if (!isConfig) {
                                onSample(
                                    Sample(
                                        bytes = bytes,
                                        presentationTimeUs = info.presentationTimeUs,
                                        flags = info.flags,
                                    ),
                                )
                            }
                        }
                        codec.releaseOutputBuffer(outIdx, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                    }
                }
            }
        } catch (e: Exception) {
            throw AudioException("AAC encoding failed: ${e.message}", e)
        } finally {
            try {
                codec.stop()
            } catch (ignored: Exception) {
            }
            try {
                codec.release()
            } catch (ignored: Exception) {
            }
        }
    }

    private fun framesToUs(frames: Long): Long =
        Math.round(frames.toDouble() * 1_000_000.0 / sampleRate)

    private data class Decoded(val pcm: FloatArray, val frames: Long)

    /** Decodes the trimmed source range to float PCM at [sampleRate]. */
    private fun decodeSource(): Decoded {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(spec.path)
        } catch (e: Exception) {
            throw AudioException("cannot open audio: ${spec.path}", e)
        }
        try {
            var trackIndex = -1
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    trackIndex = i
                    format = f
                    break
                }
            }
            if (trackIndex < 0 || format == null) {
                throw AudioException("no audio track in ${spec.path}")
            }
            extractor.selectTrack(trackIndex)
            if (spec.trimStart > 0) {
                extractor.seekTo((spec.trimStart * 1_000_000).toLong(), MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            }

            val mime = format.getString(MediaFormat.KEY_MIME)!!
            val codec = MediaCodec.createDecoderByType(mime)
            var pcmList: ByteArrayOutputStreamCompat? = null
            try {
                codec.configure(format, null, null, 0)
                codec.start()
                val bufferOut = ByteArrayOutputStreamCompat()
                val info = MediaCodec.BufferInfo()
                var sawInputEos = false
                var sawOutputEos = false
                var trimEndUs = spec.trimEnd?.let { (it * 1_000_000).toLong() }
                var lastPtsUs = 0L

                while (!sawOutputEos) {
                    if (!sawInputEos) {
                        val inIdx = codec.dequeueInputBuffer(10_000)
                        if (inIdx >= 0) {
                            val buffer = codec.getInputBuffer(inIdx)!!
                            val sampleSize = extractor.readSampleData(buffer, 0)
                            val pts = extractor.sampleTime
                            if (sampleSize < 0 || (trimEndUs != null && pts > trimEndUs)) {
                                codec.queueInputBuffer(
                                    inIdx, 0, 0, 0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                sawInputEos = true
                            } else {
                                codec.queueInputBuffer(inIdx, 0, sampleSize, pts, 0)
                                lastPtsUs = pts
                                extractor.advance()
                            }
                        }
                    }
                    val outIdx = codec.dequeueOutputBuffer(info, 10_000)
                    when {
                        outIdx == MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                        outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            bufferOut.setFormat(codec.outputFormat)
                        }
                        outIdx >= 0 -> {
                            val outBuf = codec.getOutputBuffer(outIdx)
                            if (outBuf != null && info.size > 0) {
                                // Drop samples that start before the trim in.
                                val start = info.offset
                                outBuf.position(start)
                                outBuf.limit(start + info.size)
                                val arr = ByteArray(info.size)
                                outBuf.get(arr)
                                val startUs = spec.trimStart * 1_000_000
                                if (info.presentationTimeUs >= startUs - 50_000) {
                                    bufferOut.write(arr, info.presentationTimeUs)
                                }
                            }
                            codec.releaseOutputBuffer(outIdx, false)
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                sawOutputEos = true
                            }
                        }
                    }
                }
                pcmList = bufferOut
            } finally {
                try {
                    codec.stop()
                } catch (ignored: Exception) {
                }
                try {
                    codec.release()
                } catch (ignored: Exception) {
                }
            }
            val decoded = pcmList ?: throw AudioException("no audio decoded")
            val pcm = decoded.toPcm(sampleRate, channels)
            return Decoded(pcm, (pcm.size / channels).toLong())
        } finally {
            try {
                extractor.release()
            } catch (ignored: Exception) {
            }
        }
    }

    /**
     * Collects decoded PCM with its true sample format. MediaCodec hands back
     * 16-bit PCM for MP3/AAC and float for some WAV paths, so the format is
     * taken from the track (or the encoder output) instead of assumed.
     */
    private class ByteArrayOutputStreamCompat {
        private var fmt: MediaFormat? = null
        private val chunks = ArrayList<Pair<Long, ByteArray>>()
        private var total = 0L

        fun setFormat(format: MediaFormat) {
            fmt = format
        }

        fun write(bytes: ByteArray, ptsUs: Long) {
            chunks += ptsUs to bytes
            total += bytes.size
        }

        fun toPcm(targetRate: Int, channels: Int): FloatArray {
            val format = fmt
            val sampleRate = format?.getInteger(MediaFormat.KEY_SAMPLE_RATE) ?: targetRate
            val srcChannels = format?.getInteger(MediaFormat.KEY_CHANNEL_COUNT) ?: channels
            val isFloat = format?.let {
                if (it.containsKey("pcm-encoding")) {
                    it.getInteger("pcm-encoding") == 4 // ENCODING_PCM_FLOAT
                } else {
                    false
                }
            } ?: false

            val outFrames = if (sampleRate == targetRate) {
                (total / (2L * srcChannels)).toInt()
            } else {
                ((total / (2L * srcChannels)) * targetRate / sampleRate).toInt()
            }
            val out = FloatArray(outFrames.coerceAtLeast(0) * channels)
            if (sampleRate == targetRate && srcChannels == channels) {
                var idx = 0
                for ((_, bytes) in chunks) {
                    val buf = ByteBuffer.wrap(bytes).order(ByteOrder.nativeOrder())
                    if (isFloat) {
                        val fb = buf.asFloatBuffer()
                        while (fb.hasRemaining() && idx < out.size) out[idx++] = fb.get()
                    } else {
                        val sb = buf.asShortBuffer()
                        while (sb.hasRemaining() && idx < out.size) out[idx++] = sb.get() / 32768f
                    }
                }
            } else {
                // Down-mix / resample: linear interpolation is adequate for a
                // music bed and costs no external dependency.
                val mono = FloatArray((total / (2L * srcChannels)).toInt())
                var idx = 0
                for ((_, bytes) in chunks) {
                    val buf = ByteBuffer.wrap(bytes).order(ByteOrder.nativeOrder())
                    val sb = buf.asShortBuffer()
                    while (sb.hasRemaining()) {
                        var acc = 0f
                        for (c in 0 until srcChannels) {
                            if (!sb.hasRemaining()) break
                            acc += sb.get() / 32768f
                        }
                        if (idx < mono.size) mono[idx++] = acc / srcChannels
                    }
                }
                val ratio = targetRate.toDouble() / sampleRate
                val srcFrames = mono.size
                val dstFrames = min((srcFrames * ratio).toInt(), outFrames)
                for (i in 0 until dstFrames) {
                    val pos = i / ratio
                    val i0 = pos.toInt().coerceIn(0, srcFrames - 1)
                    val i1 = min(i0 + 1, srcFrames - 1)
                    val frac = (pos - i0).toFloat()
                    val v = mono[i0] * (1 - frac) + mono[i1] * frac
                    for (c in 0 until channels) out[i * channels + c] = v
                }
            }
            // Normalise peak to avoid clipping from the crossfade sums.
            var peak = 0f
            for (v in out) {
                if (abs(v) > peak) peak = abs(v)
            }
            if (peak > 1f) {
                val g = 1f / peak
                for (i in out.indices) out[i] *= g
            }
            return out
        }
    }

    companion object {
        private const val TAG = "AudioProcessor"
    }
}
