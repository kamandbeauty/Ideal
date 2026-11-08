package app.subflow.asr

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Decodes the audio track of a video into mono 16 kHz float PCM - exactly what
 * whisper.cpp consumes.
 *
 * Every decoder difference that would otherwise become "the app crashed on this
 * file" is handled here: the codec may hand back 16-bit or float PCM, it may
 * report a new output format mid-stream, and the source rate is anything from
 * 8 kHz to 48 kHz. No ffmpeg: Media3/MediaCodec is the platform decoder and the
 * resampling is a few lines of linear interpolation.
 */
object WhisperAudio {
    private const val TAG = "SubFlowAsrAudio"

    const val TARGET_RATE = 16000

    /** Growable float array: a transcript can be millions of samples long. */
    private class FloatSink(initial: Int = 1 shl 16) {
        var data = FloatArray(initial)
            private set
        var size = 0
            private set

        fun add(value: Float) {
            if (size == data.size) data = data.copyOf(data.size * 2)
            data[size] = value
            size += 1
        }

        fun toArray(): FloatArray = data.copyOf(size)
    }

    /**
     * Returns mono 16 kHz samples in [-1, 1]. Throws [IllegalStateException] with
     * a user-facing Persian message when the input has no usable audio, and
     * returns an empty array when [isCancelled] turns true mid-decode.
     */
    fun decode(
        context: Context,
        uri: Uri,
        durationUs: Long,
        onProgress: (Int) -> Unit,
        isCancelled: () -> Boolean,
        maxSeconds: Double? = null,
    ): FloatArray {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(context, uri, null)
            var trackIndex = -1
            var format: MediaFormat? = null
            for (index in 0 until extractor.trackCount) {
                val candidate = extractor.getTrackFormat(index)
                val mime = candidate.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    trackIndex = index
                    format = candidate
                    break
                }
            }
            if (trackIndex < 0 || format == null) {
                throw IllegalStateException("این ویدئو صدایی ندارد که بتوان زیرنویس کرد.")
            }
            extractor.selectTrack(trackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalStateException("نوع صدای این فایل خوانده نشد.")

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
            var pcmEncoding = if (format.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                format.getInteger(MediaFormat.KEY_PCM_ENCODING)
            } else {
                AudioFormat.ENCODING_PCM_16BIT
            }

            val source = FloatSink()
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false

            val sampleLimit = maxSeconds?.let { (it * sampleRate).toInt() } ?: Int.MAX_VALUE
            while (!outputDone) {
                if (isCancelled()) return FloatArray(0)
                if (source.size >= sampleLimit) break

                if (!inputDone) {
                    val inputIndex = codec.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val buffer = codec.getInputBuffer(inputIndex)
                        val size = if (buffer == null) -1 else extractor.readSampleData(buffer, 0)
                        if (size <= 0) {
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(inputIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outputIndex = codec.dequeueOutputBuffer(info, 10_000)
                when {
                    outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val updated = codec.outputFormat
                        sampleRate = updated.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = updated.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
                        if (updated.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                            pcmEncoding = updated.getInteger(MediaFormat.KEY_PCM_ENCODING)
                        }
                    }

                    outputIndex >= 0 -> {
                        val buffer = codec.getOutputBuffer(outputIndex)
                        if (buffer != null && info.size > 0) {
                            buffer.position(info.offset)
                            buffer.limit(info.offset + info.size)
                            appendMono(buffer, channels, pcmEncoding, source)
                        }
                        codec.releaseOutputBuffer(outputIndex, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                        if (durationUs > 0) {
                            val done = (info.presentationTimeUs.toDouble() / durationUs) * 30.0
                            onProgress(done.toInt().coerceIn(0, 30))
                        }
                    }
                }
            }

            if (source.size == 0) {
                throw IllegalStateException("صدایی از این فایل خوانده نشد.")
            }
            onProgress(30)
            return resample(source, sampleRate)
        } finally {
            try {
                codec?.stop()
            } catch (error: IllegalStateException) {
                Log.w(TAG, "codec stop failed", error)
            }
            codec?.release()
            extractor.release()
        }
    }

    private fun appendMono(
        buffer: ByteBuffer,
        channels: Int,
        pcmEncoding: Int,
        sink: FloatSink,
    ) {
        buffer.order(ByteOrder.nativeOrder())
        val isFloat = pcmEncoding == AudioFormat.ENCODING_PCM_FLOAT
        val bytesPerSample = if (isFloat) 4 else 2
        val frameBytes = bytesPerSample * channels
        if (frameBytes <= 0) return
        val frames = buffer.remaining() / frameBytes
        for (frame in 0 until frames) {
            var sum = 0f
            for (channel in 0 until channels) {
                sum += if (isFloat) {
                    buffer.getFloat()
                } else {
                    buffer.short.toFloat() / 32768f
                }
            }
            sink.add(sum / channels)
        }
    }

    /** Loudest sample in the decoded audio; 0 means the track is silent. */
    fun peak(pcm: FloatArray): Float {
        var peak = 0f
        for (sample in pcm) {
            val value = kotlin.math.abs(sample)
            if (value > peak) peak = value
        }
        return peak
    }

    /**
     * Peak amplitude per bucket, scaled to 0..1000, for the timeline strip.
     * Peak (not RMS) keeps quiet speech visible at phone size.
     */
    fun buckets(pcm: FloatArray, count: Int): List<Int> {
        if (pcm.isEmpty() || count <= 0) return emptyList()
        val size = (pcm.size + count - 1) / count
        val out = ArrayList<Int>(count)
        var index = 0
        while (index < pcm.size) {
            var peak = 0f
            val end = minOf(pcm.size, index + size)
            for (i in index until end) {
                val value = kotlin.math.abs(pcm[i])
                if (value > peak) peak = value
            }
            out.add((peak.coerceIn(0f, 1f) * 1000).toInt())
            index = end
        }
        return out
    }

    private fun resample(source: FloatSink, sampleRate: Int): FloatArray {
        if (sampleRate <= 0 || sampleRate == TARGET_RATE) return source.toArray()
        val ratio = sampleRate.toDouble() / TARGET_RATE
        val outCount = (source.size / ratio).toInt()
        if (outCount <= 0) return FloatArray(0)
        val input = source.data
        val output = FloatArray(outCount)
        for (i in 0 until outCount) {
            val position = i * ratio
            val base = position.toInt().coerceAtMost(source.size - 1)
            val next = (base + 1).coerceAtMost(source.size - 1)
            val fraction = position - base
            val sample = input[base] + (input[next] - input[base]) * fraction.toFloat()
            output[i] = sample.coerceIn(-1f, 1f)
        }
        return output
    }
}
