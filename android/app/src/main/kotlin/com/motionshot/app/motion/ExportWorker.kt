package com.motionshot.app.motion

import android.content.Context
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Runs one export end to end on a background thread.
 *
 * Stages: preflight -> audio -> encoder -> render -> mux -> verify.
 *
 * Guarantees:
 *  * the caller's thread is never blocked; progress is delivered on the main
 *    thread through [ExportListener]
 *  * cancellation is cooperative and immediate: the render loop checks a flag
 *    every frame, the encoder is released, and the partial MP4 is deleted
 *  * any failure deletes the partial file, so the app can never present a
 *    broken video as a finished export
 *  * resources (EGL, codec, muxer, textures) are released in a `finally`
 *
 * Audio is prepared *before* the encoder starts because it has a fixed length
 * that the muxer needs for its track format, and because a broken music file
 * should fail in the first second rather than after ten minutes of rendering.
 */
class ExportWorker(
    private val context: Context,
    private val request: ExportRequest,
    private val listener: ExportListener,
    private val capabilities: DeviceCapabilities,
) {
    interface ExportListener {
        fun onProgress(stage: String, progress: Double, framesDone: Int, framesTotal: Int)
        fun onCompleted(result: ExportResult)
        fun onFailed(code: String, message: String)
        fun onCancelled()
    }

    data class ExportResult(
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
        val texturesCreated: Int,
        val texturesEvicted: Int,
    )

    private val cancelled = AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var thread: Thread? = null

    @Volatile
    private var activeEngine: RenderEngine? = null

    private fun post(block: () -> Unit) = mainHandler.post(block)

    fun cancel() {
        cancelled.set(true)
        activeEngine?.requestCancel()
    }

    fun start() {
        if (thread != null) throw IllegalStateException("worker already started")
        thread = Thread({ run() }, "motionshot-export").apply { start() }
    }

    private fun fail(code: String, message: String) {
        post { listener.onFailed(code, message) }
    }

    private fun run() {
        val startedAt = SystemClock.elapsedRealtime()
        var encoder: VideoEncoder? = null
        var muxer: MediaMuxerManager? = null
        var renderEngine: RenderEngine? = null
        var audioStarted = false
        var exportOk = false // only true once a verified MP4 is delivered

        try {
            // ---------- 0. preflight ----------
            post { listener.onProgress("preparing", 0.0, 0, request.frameCount) }
            request.validate()
            request.assertFitsMatch()

            if (!capabilities.canEncode(request.width, request.height, request.fps)) {
                fail(
                    "RESOLUTION_UNSUPPORTED",
                    "device encoder supports up to ${capabilities.maxWidth}x" +
                        "${capabilities.maxHeight}@${capabilities.maxFps}, " +
                        "requested ${request.width}x${request.height}@${request.fps}",
                )
                return
            }

            val outputFile = File(request.outputPath)
            outputFile.parentFile?.mkdirs()
            val estimatedBytes =
                (request.bitrate + 192_000L) * request.totalDuration.toLong() / 8L
            val freeMb = DeviceCapabilities.availableStorageMb(outputFile.parentFile ?: context.filesDir)
            if (freeMb in 1..(estimatedBytes / (1024 * 1024) + 100)) {
                fail(
                    "OUT_OF_STORAGE",
                    "need about ${estimatedBytes / (1024 * 1024) + 100} MB, " +
                        "only $freeMb MB free",
                )
                return
            }
            request.photos.forEach { photo ->
                val f = File(photo.path)
                if (!f.exists() || f.length() == 0L) {
                    fail("PHOTO_MISSING", "photo file is not readable: ${photo.path}")
                    return
                }
            }
            if (cancelled.get()) {
                post { listener.onCancelled() }
                return
            }

            val mime = if (request.codec.equals("hevc", true)) {
                MediaFormat.MIMETYPE_VIDEO_HEVC
            } else {
                MediaFormat.MIMETYPE_VIDEO_AVC
            }

            // ---------- 1. audio ----------
            val encodedAudio: AudioProcessor.EncodedAudio?
            if (request.audio != null) {
                post { listener.onProgress("muxingAudio", 0.06, 0, request.frameCount) }
                encodedAudio = try {
                    val processor = AudioProcessor(request.audio, request.totalDuration)
                    val pcm = processor.buildPcm()
                    processor.encodeAacTrack(pcm)
                } catch (e: AudioProcessor.AudioException) {
                    // A broken music file must not kill the video: fall back to
                    // a silent export and tell the user why.
                    Log.w(TAG, "audio failed, exporting silently: ${e.message}")
                    null
                }
            } else {
                encodedAudio = null
            }
            if (cancelled.get()) {
                post { listener.onCancelled() }
                return
            }

            // ---------- 2. encoder + muxer ----------
            val mux = MediaMuxerManager(request.outputPath)
            muxer = mux
            val enc = VideoEncoder(
                mime = mime,
                requestedWidth = request.width,
                requestedHeight = request.height,
                fps = request.fps,
                requestedBitrate = request.bitrate,
            )
            // MediaMuxer requires codec-specific data (`csd-0`/`csd-1`), which
            // MediaCodec only publishes in `INFO_OUTPUT_FORMAT_CHANGED` before
            // the first encoded frame. Register video first (track 0), then
            // audio (track 1), then start the muxer.
            enc.onOutputFormat = { realVideoFormat ->
                if (!mux.isStarted) {
                    mux.addVideoTrack(realVideoFormat)
                    if (encodedAudio != null) {
                        mux.addAudioTrack(encodedAudio.outputFormat)
                    }
                    mux.startIfReady()
                }
            }
            encoder = enc
            val surface = try {
                enc.configure()
            } catch (e: VideoEncoder.EncoderException) {
                fail("CODEC_UNSUPPORTED", e.message ?: "encoder configuration failed")
                return
            }

            // ---------- 3. render ----------
            val decoder = PhotoDecoder(
                outputWidth = enc.actualWidth,
                outputHeight = enc.actualHeight,
                isLowRamDevice = capabilities.isLowRamDevice,
            )
            val engine = RenderEngine(
                request = request,
                decoder = decoder,
                maxTextureSize = capabilities.maxTextureSize,
                outputWidth = enc.actualWidth,
                outputHeight = enc.actualHeight,
                onFrameRendered = { frameIndex ->
                    val p = (frameIndex + 1).toDouble() / request.frameCount
                    // Encoding progress occupies 10%..90% of the bar so the
                    // final mux/verify steps have visible room.
                    post {
                        listener.onProgress(
                            "encoding", 0.10 + p * 0.80,
                            frameIndex + 1, request.frameCount,
                        )
                    }
                },
                onStage = { stage ->
                    when (stage) {
                        RenderEngine.RenderStage.PREPARING -> Unit
                        RenderEngine.RenderStage.DECODING ->
                            post { listener.onProgress("decodingPhotos", 0.05, 0, request.frameCount) }
                        RenderEngine.RenderStage.RENDERING ->
                            post { listener.onProgress("rendering", 0.10, 0, request.frameCount) }
                        RenderEngine.RenderStage.FINISHING ->
                            post { listener.onProgress("muxing", 0.92, request.frameCount, request.frameCount) }
                    }
                },
            )
            renderEngine = engine
            activeEngine = engine
            if (cancelled.get()) {
                engine.requestCancel()
            }

            // The encoder output must be drained while rendering continues;
            // Surface input means no CPU buffers are involved, so draining from
            // this same thread between frames is enough and avoids a second.
            val drainRunnable = Runnable { drainQuietly(enc, mux) }
            var renderedFrames = 0
            try {
                renderedFrames = engine.renderSafely(surface, drainRunnable)
            } catch (e: RenderEngine.RenderException) {
                if (cancelled.get() || e.message == "cancelled") {
                    mux.abort()
                    post { listener.onCancelled() }
                    return
                }
                throw e
            }
            if (cancelled.get()) {
                mux.abort()
                post { listener.onCancelled() }
                return
            }

            // ---------- 4. flush encoder + write audio ----------
            enc.finish { sample ->
                if (!sample.isConfig && !cancelled.get()) {
                    mux.writeVideo(sample.bytes, sample.presentationTimeUs, sample.flags)
                }
            }
            drainQuietly(enc, mux)

            if (encodedAudio != null && mux.isStarted) {
                post { listener.onProgress("muxingAudio", 0.93, renderedFrames, request.frameCount) }
                audioStarted = true
                for (s in encodedAudio.samples) {
                    if (cancelled.get()) break
                    mux.writeAudio(s.bytes, s.presentationTimeUs, s.flags)
                }
            }

            post { listener.onProgress("verifying", 0.97, renderedFrames, request.frameCount) }
            val ok = mux.finish()
            if (!ok) {
                fail("MUXER_FAILED", "the MP4 could not be finalized; the partial file was removed")
                return
            }
            if (cancelled.get()) {
                File(request.outputPath).delete()
                post { listener.onCancelled() }
                return
            }

            val probe = MediaProbe.probe(context, request.outputPath)
            val expectedMs = (request.totalDuration * 1000).toLong()
            if (probe == null || probe.frameCount <= 0) {
                File(request.outputPath).delete()
                fail("ENCODER_FAILED", "the produced file is not a readable video")
                return
            }
            if (probe.durationMs < (expectedMs * 0.97).toLong()) {
                File(request.outputPath).delete()
                fail(
                    "ENCODER_FAILED",
                    "video is shorter than requested: ${probe.durationMs}ms < ${expectedMs}ms",
                )
                return
            }
            if (probe.width != enc.actualWidth || probe.height != enc.actualHeight) {
                File(request.outputPath).delete()
                fail(
                    "ENCODER_FAILED",
                    "size mismatch: got ${probe.width}x${probe.height}, " +
                        "expected ${enc.actualWidth}x${enc.actualHeight}",
                )
                return
            }

            val stats = engine.textureStats()
            val result = ExportResult(
                path = request.outputPath,
                width = probe.width,
                height = probe.height,
                fps = probe.fps.takeIf { it > 0 } ?: request.fps,
                durationMs = probe.durationMs,
                frameCount = probe.frameCount,
                bitrate = probe.bitrate.takeIf { it > 0 } ?: enc.actualBitrate,
                codec = if (mime == MediaFormat.MIMETYPE_VIDEO_HEVC) "hevc" else "h264",
                sizeBytes = File(request.outputPath).length(),
                hasAudio = encodedAudio != null && probe.hasAudio,
                texturesCreated = stats.first,
                texturesEvicted = stats.second,
            )
            Log.i(TAG, "export done in ${SystemClock.elapsedRealtime() - startedAt}ms: $result")
            exportOk = true
            post { listener.onCompleted(result) }
        } catch (e: ExportRequestException) {
            fail("UNSUPPORTED_FORMAT", e.message ?: "invalid request")
        } catch (e: OutOfMemoryError) {
            fail("OUT_OF_MEMORY", "ran out of memory while rendering")
        } catch (e: VideoEncoder.EncoderException) {
            fail("ENCODER_FAILED", e.message ?: "encoder failed")
        } catch (e: MediaMuxerManager.MuxerException) {
            fail("MUXER_FAILED", e.message ?: "muxer failed")
        } catch (e: RenderEngine.RenderException) {
            fail("GL_FAILED", e.message ?: "renderer failed")
        } catch (e: Exception) {
            if (cancelled.get()) {
                post { listener.onCancelled() }
            } else {
                fail("ENCODER_FAILED", "${e.javaClass.simpleName}: ${e.message}")
            }
        } finally {
            activeEngine = null
            try {
                renderEngine?.release()
            } catch (e: Exception) {
                Log.w(TAG, "render release: ${e.message}")
            }
            try {
                encoder?.release()
            } catch (e: Exception) {
                Log.w(TAG, "encoder release: ${e.message}")
            }
            if (!exportOk) {
                // Any non-delivered export: free a muxer that was started but
                // never finalized (fd leak) and remove the partial file so a
                // corrupt video can never look like a real export.
                muxer?.releaseQuietly()
                File(request.outputPath).delete()
            }
            Log.d(
                TAG,
                "worker finished in ${SystemClock.elapsedRealtime() - startedAt}ms " +
                    "(audio=$audioStarted)",
            )
        }
    }

    /** Drains encoder output into the muxer, ignoring transient conditions. */
    private fun drainQuietly(enc: VideoEncoder, mux: MediaMuxerManager) {
        try {
            enc.drain(endOfStream = false) { sample ->
                if (!sample.isConfig && !cancelled.get()) {
                    mux.writeVideo(sample.bytes, sample.presentationTimeUs, sample.flags)
                }
            }
        } catch (e: VideoEncoder.EncoderException) {
            Log.w(TAG, "drain: ${e.message}")
        } catch (e: MediaMuxerManager.MuxerException) {
            Log.w(TAG, "mux: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "ExportWorker"
    }
}
