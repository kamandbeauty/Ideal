package com.motionshot.app.motion

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Detects the quiet moments of an audio file.
 *
 * Decodes the first audio track with the same MediaExtractor + MediaCodec
 * flow as [AudioProcessor], but instead of collecting the PCM it computes a
 * short-window RMS envelope while decoding, then reports the midpoint (in
 * seconds) of every silence span. The Dart layer uses those points to align
 * photo-switch boundaries to the quiet parts of the music/voice.
 *
 * Must run off the main thread: a long track takes a few seconds.
 */
object SilenceAnalyzer {
    /** One window every 20 ms (50 windows per second). */
    private const val WINDOW_MS = 20L

    /**
     * Silence spans shorter than this are ignored. Sub-200 ms gaps are the
     * micro-pauses between words; sentence/phrase pauses are longer, so cuts
     * should land in spans of at least ~0.26 s.
     */
    private const val MIN_SILENCE_WINDOWS = 13 // 0.26 s

    /**
     * RMS below `speechLevel * factor` counts as quiet (about -9 dB under
     * the typical voice level). Relative to the 85th percentile (not the
     * single loudest window) so one loud peak cannot lift the threshold and
     * a quiet music bed cannot hide the real pauses.
     */
    private const val SILENCE_FACTOR = 0.35

    /** Absolute floor (float PCM scale) so near-silent files still work. */
    private const val ABSOLUTE_THRESHOLD = 0.004

    /** Cap on reported points; a long track yields dozens at most. */
    private const val MAX_POINTS = 400

    class SilenceException(message: String, cause: Throwable? = null) :
        Exception(message, cause)

    /** One 20 ms window of the RMS envelope, fed frame by frame. */
    private class WindowAccumulator(private val framesPerWindow: Long) {
        private var sumSq = 0.0
        private var count = 0L
        val envelope = ArrayList<Double>()

        fun feedFrame(peakAbs: Float) {
            val v = peakAbs.toDouble()
            sumSq += v * v
            count++
            if (count >= framesPerWindow) {
                envelope.add(sqrt(sumSq / count.toDouble()))
                sumSq = 0.0
                count = 0
            }
        }

        /** Emits a (partial) trailing window if one is pending. */
        fun flush() {
            if (count > 0) {
                envelope.add(sqrt(sumSq / count.toDouble()))
                count = 0
                sumSq = 0.0
            }
        }
    }

    /**
     * Returns the midpoints (in seconds) of every sentence-length silence
     * span in [path].
     *
     * The threshold is derived from the file's own 85th-percentile RMS
     * (its typical voice/music level), so the detected gaps are the pauses
     * between phrases — including the quiet stretches between spoken
     * sentences when a music bed keeps the floor above absolute silence.
     */
    fun analyze(path: String): List<Double> {
        val file = File(path)
        if (!file.exists() || file.length() == 0L) {
            throw SilenceException("audio file not found: $path")
        }

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
        } catch (e: Exception) {
            throw SilenceException("cannot open audio: $path", e)
        }

        var sampleRate = 48_000
        var channels = 2
        var isFloat = false
        var accumulator: WindowAccumulator? = null

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
                throw SilenceException("no audio track in $path")
            }
            extractor.selectTrack(trackIndex)

            val mime = format.getString(MediaFormat.KEY_MIME)!!
            val codec = MediaCodec.createDecoderByType(mime)
            try {
                codec.configure(format, null, null, 0)
                codec.start()
                val info = MediaCodec.BufferInfo()
                var sawInputEos = false
                var sawOutputEos = false

                while (!sawOutputEos) {
                    if (!sawInputEos) {
                        val inIdx = codec.dequeueInputBuffer(10_000)
                        if (inIdx >= 0) {
                            val buffer = codec.getInputBuffer(inIdx)!!
                            val sampleSize = extractor.readSampleData(buffer, 0)
                            val pts = extractor.sampleTime
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(
                                    inIdx, 0, 0, 0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                sawInputEos = true
                            } else {
                                codec.queueInputBuffer(inIdx, 0, sampleSize, pts, 0)
                                extractor.advance()
                            }
                        }
                    }
                    val outIdx = codec.dequeueOutputBuffer(info, 10_000)
                    when {
                        outIdx == MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                        outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val of = codec.outputFormat
                            sampleRate =
                                of.getInteger(MediaFormat.KEY_SAMPLE_RATE).coerceAtLeast(1)
                            channels =
                                of.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
                            // Some WAV paths decode to float PCM (ENCODING_PCM_FLOAT).
                            isFloat = if (of.containsKey("pcm-encoding")) {
                                of.getInteger("pcm-encoding") == 4
                            } else {
                                false
                            }
                            // Frames per 20 ms window, at the real rate.
                            val framesPerWindow =
                                ((sampleRate / 1000) * WINDOW_MS).coerceAtLeast(1L)
                            accumulator = WindowAccumulator(framesPerWindow)
                        }
                        outIdx >= 0 -> {
                            val outBuf = codec.getOutputBuffer(outIdx)
                            val acc = accumulator
                            if (outBuf != null && info.size > 0 && acc != null) {
                                outBuf.position(info.offset)
                                outBuf.limit(info.offset + info.size)
                                outBuf.order(ByteOrder.nativeOrder())
                                if (isFloat) {
                                    val fb = outBuf.asFloatBuffer()
                                    while (fb.remaining() >= channels) {
                                        var peak = 0f
                                        for (c in 0 until channels) {
                                            var v: Float = fb.get()
                                            if (v < 0f) v = -v
                                            if (v > peak) peak = v
                                        }
                                        acc.feedFrame(peak)
                                    }
                                } else {
                                    val sb = outBuf.asShortBuffer()
                                    while (sb.remaining() >= channels) {
                                        var peak = 0
                                        for (c in 0 until channels) {
                                            // .toInt() keeps this compiling whether K2
                                            // maps the platform ShortBuffer.get() to
                                            // Int (Java) or Short.
                                            val sample: Int = sb.get().toInt()
                                            val absSample =
                                                if (sample < 0) -sample else sample
                                            if (absSample > peak) peak = absSample
                                        }
                                        acc.feedFrame(peak / 32768f)
                                    }
                                }
                            }
                            codec.releaseOutputBuffer(outIdx, false)
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                sawOutputEos = true
                            }
                        }
                    }
                }
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

        val acc = accumulator ?: return emptyList()
        acc.flush()
        val envelope = acc.envelope
        if (envelope.isEmpty()) return emptyList()

        // Typical loud level = 85th percentile of the envelope (robust to
        // single peaks; the quiet bed between sentences sits below it).
        val ordered = envelope.sorted()
        val speechLevel = ordered[max(0, (ordered.size * 85) / 100 - 1)]
        val threshold = max(ABSOLUTE_THRESHOLD, speechLevel * SILENCE_FACTOR)
        val windowSeconds = (WINDOW_MS / 1000.0)

        val points = ArrayList<Double>()
        var i = 0
        while (i < envelope.size) {
            if (envelope[i] < threshold) {
                var j = i
                while (j < envelope.size && envelope[j] < threshold) j++
                if (j - i >= MIN_SILENCE_WINDOWS && points.size < MAX_POINTS) {
                    // Span [i, j) covers [i*w, j*w) seconds; report its middle.
                    points.add(((i + j) / 2.0) * windowSeconds)
                }
                i = j
            } else {
                i++
            }
        }
        return points
    }
}
