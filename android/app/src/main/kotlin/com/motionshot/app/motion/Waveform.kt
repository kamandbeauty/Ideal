package com.motionshot.app.motion

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import kotlin.math.abs
import kotlin.math.max

/**
 * Decodes an audio file into an amplitude envelope for the music timeline.
 *
 * One decode pass; per decoded buffer only the max |sample| is kept (not the
 * full PCM), so a 10 minute track costs a few hundred floats. The result is
 * [buckets] values in 0..1, normalized by the global peak, plus the source
 * duration in seconds (used to tile the pattern for looped music).
 */
object Waveform {
    private const val TAG = "Waveform"

    class WaveformException(message: String, cause: Throwable? = null) :
        Exception(message, cause)

    /** @return (sourceDurationSeconds, peaks) with peaks.size == buckets. */
    fun extract(path: String, buckets: Int): Pair<Double, List<Double>> {
        val b = buckets.coerceIn(50, 2000)
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
        } catch (e: Exception) {
            throw WaveformException("cannot open audio: $path", e)
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
                throw WaveformException("no audio track in $path")
            }
            extractor.selectTrack(trackIndex)

            val mime = format.getString(MediaFormat.KEY_MIME)!!
            val codec = MediaCodec.createDecoderByType(mime)
            val amps = ArrayList<Float>(512)
            val ptsList = ArrayList<Long>(512)
            try {
                codec.configure(format, null, null, 0)
                codec.start()
                val info = MediaCodec.BufferInfo()
                val isFloat = format.containsKey("pcm-encoding") &&
                    format.getInteger("pcm-encoding") == 4
                val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    .coerceAtLeast(1)
                val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    .coerceAtLeast(1)
                var durationUs = 0L
                var sawInputEos = false
                var sawOutputEos = false

                while (!sawOutputEos) {
                    if (!sawInputEos) {
                        val inIdx = codec.dequeueInputBuffer(10_000)
                        if (inIdx >= 0) {
                            val buffer = codec.getInputBuffer(inIdx)
                                ?: throw WaveformException("input buffer unavailable")
                            val n = extractor.readSampleData(buffer, 0)
                            val pts = extractor.sampleTime
                            if (n < 0) {
                                codec.queueInputBuffer(
                                    inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                sawInputEos = true
                            } else {
                                codec.queueInputBuffer(inIdx, 0, n, pts, 0)
                                extractor.advance()
                            }
                        }
                    }
                    val outIdx = codec.dequeueOutputBuffer(info, 10_000)
                    when {
                        outIdx == MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                        outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit
                        outIdx >= 0 -> {
                            if (info.size > 0) {
                                val outBuf = codec.getOutputBuffer(outIdx)
                                if (outBuf != null) {
                                    outBuf.position(info.offset)
                                    outBuf.limit(info.offset + info.size)
                                    var amp = 0f
                                    if (isFloat) {
                                        val fb = outBuf.asFloatBuffer()
                                        while (fb.hasRemaining()) {
                                            val v = abs(fb.get())
                                            if (v > amp) amp = v
                                        }
                                    } else {
                                        val sb = outBuf.asShortBuffer()
                                        while (sb.hasRemaining()) {
                                            val v = abs(sb.get().toFloat()) / 32768f
                                            if (v > amp) amp = v
                                        }
                                    }
                                    amps.add(amp)
                                    ptsList.add(info.presentationTimeUs)
                                    val frames = info.size /
                                        ((if (isFloat) 4 else 2) * channels)
                                    durationUs = max(
                                        durationUs,
                                        info.presentationTimeUs +
                                            frames * 1_000_000L / sampleRate,
                                    )
                                }
                            }
                            codec.releaseOutputBuffer(outIdx, false)
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                sawOutputEos = true
                            }
                        }
                    }
                }

                val durationSec = durationUs / 1_000_000.0
                if (amps.isEmpty() || durationSec <= 0.0) {
                    return 0.0 to List(b) { 0.0 }
                }
                val out = FloatArray(b)
                for (i in amps.indices) {
                    val t = (ptsList[i].toDouble() / durationUs).coerceIn(0.0, 1.0 - 1e-9)
                    val idx = (t * b).toInt()
                    if (amps[i] > out[idx]) out[idx] = amps[i]
                }
                var peak = 0f
                for (v in out) if (v > peak) peak = v
                val scaled = if (peak > 1e-6f) {
                    List(b) { (out[it] / peak).toDouble() }
                } else {
                    List(b) { 0.0 }
                }
                return durationSec to scaled
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
        } finally {
            try {
                extractor.release()
            } catch (ignored: Exception) {
            }
        }
    }
}
