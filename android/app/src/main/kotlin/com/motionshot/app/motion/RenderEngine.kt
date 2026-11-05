package com.motionshot.app.motion

import android.opengl.GLES20
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * The render engine: turns an [ExportRequest] into frames on the encoder's
 * input surface.
 *
 * Pipeline (docs/MOTION_SPEC.md §7, product brief §11):
 *  1. the encoder's input `Surface` becomes the EGL window surface
 *  2. for each frame index i: t = i / fps  (exact rational timestamps, §8.4)
 *  3. resolve the timeline layers at t, and their alphas/offsets
 *  4. for each layer: sample the camera, build the matrix, draw the texture
 *  5. `eglPresentationTimeANDROID` + `eglSwapBuffers` hands the frame to
 *     MediaCodec with zero copies
 *
 * Everything below is single-threaded on the render thread on purpose: GL
 * contexts are not shareable across arbitrary threads and the encoder surface
 * must be used from the thread that owns the EGL context.
 *
 * Cancellation and cleanup are explicit ([requestCancel], [release]) so a
 * foreground-service stop cannot leak an EGL context, a codec or 200 MB of
 * textures.
 */
class RenderEngine(
    private val request: ExportRequest,
    private val decoder: PhotoDecoder,
    private val maxTextureSize: Int,
    private val outputWidth: Int = request.width,
    private val outputHeight: Int = request.height,
    private val onFrameRendered: (frameIndex: Int) -> Unit,
    private val onStage: (RenderStage) -> Unit,
) {
    enum class RenderStage { PREPARING, DECODING, RENDERING, FINISHING }

    class RenderException(message: String, cause: Throwable? = null) : Exception(message, cause)

    private val vp = request.viewport
    private val timeline = Timeline(
        request.photos.map { it.duration },
        request.photos.dropLast(1).map { it.transition ?: TransitionSpec(TransitionType.NONE, 0.0) },
    )

    private var egl: EGLCore? = null
    private var renderer: OpenGLRenderer? = null
    private var textures: TextureManager? = null
    private var interpolators: Array<MotionInterpolator?> = arrayOfNulls(request.photos.size)
    private var fits: Array<ImageFit?> = arrayOfNulls(request.photos.size)
    private var currentPhoto = -1
    private var disposed = false

    @Volatile
    private var cancelRequested = false

    fun requestCancel() {
        cancelRequested = true
    }

    /**
     * Renders every frame into [encoderSurface].
     *
     * @return the number of frames written.
     * @throws RenderException when the device cannot render, or the frame count
     *         does not match the request.
     */
    /**
     * Renders all frames, invoking [drainBetweenFrames] after each swap so the
     * encoder can be drained from the same thread (Surface input never blocks,
     * but the encoder's output queue must be emptied to keep latency low).
     */
    fun renderSafely(
        encoderSurface: android.view.Surface,
        drainBetweenFrames: Runnable,
    ): Int = render(encoderSurface, drainBetweenFrames)

    fun render(
        encoderSurface: android.view.Surface,
        drainBetweenFrames: Runnable? = null,
    ): Int {
        check(!disposed) { "RenderEngine already released" }
        onStage(RenderStage.PREPARING)

        val eglCore = EGLCore()
        egl = eglCore
        if (!eglCore.init(encoderSurface, outputWidth, outputHeight)) {
            throw RenderException("could not create an EGL context")
        }

        val gl = OpenGLRenderer(useEs3 = eglCore.isEs3)
        renderer = gl
        if (!gl.init()) {
            throw RenderException("could not compile the render shaders")
        }
        GLES20.glViewport(0, 0, outputWidth, outputHeight)

        textures = TextureManager(
            maxTextures = if (eglCore.isEs3) 4 else 3,
            maxTextureSize = maxTextureSize,
        )

        // Pre-flight: make sure every photo can be decoded *before* encoding
        // starts, so a broken file cannot waste minutes of render time.
        onStage(RenderStage.DECODING)
        request.photos.forEachIndexed { index, photo ->
            if (cancelRequested) throw RenderException("cancelled")
            val probe = decoder.probe(photo.path)
                ?: throw RenderException("photo '${photo.id}' cannot be decoded")
            if (photo.width > 0 && photo.height > 0) {
                val swapped = probe.width != photo.width || probe.height != photo.height
                if (swapped) {
                    Log.w(
                        TAG,
                        "photo '${photo.id}' decoded as ${probe.width}x${probe.height}, " +
                            "request says ${photo.width}x${photo.height}; using decoded size",
                    )
                }
            }
            val w = if (probe.width > 0) probe.width else photo.width
            val h = if (probe.height > 0) probe.height else photo.height
            val fit = ImageFit.make(w, h, vp)
            fits[index] = fit
            interpolators[index] = MotionInterpolator(
                photo.keyframes,
                fit,
                vp,
                path = photo.motionPath,
            )
            // §4 guarantee: a stored keyframe may be illegal after an aspect
            // change on an older project; clamping keeps the frame filled.
            validateKeyframeLegality(photo, fit)
        }

        // Preload the first photo so the first frame is not blank.
        ensureTexture(0, 0L)

        onStage(RenderStage.RENDERING)
        val totalFrames = request.frameCount
        var written = 0
        var lastFrameMs = System.currentTimeMillis()

        for (frameIndex in 0 until totalFrames) {
            if (cancelRequested) throw RenderException("cancelled")
            val t = frameIndex.toDouble() / request.fps
            val drawLayers = timeline.drawLayersAt(t)

            GLES20.glViewport(0, 0, outputWidth, outputHeight)
            gl.clear()

            for (layer in drawLayers) {
                if (layer.alpha <= 0.001) continue
                val photo = request.photos[layer.photoIndex]
                val fit = fits[layer.photoIndex]
                    ?: throw RenderException("missing fit for '${photo.id}'")
                val interp = interpolators[layer.photoIndex]
                    ?: throw RenderException("missing interpolator for '${photo.id}'")

                val texId = ensureTexture(layer.photoIndex, frameIndex.toLong())
                if (texId <= 0) {
                    throw RenderException("could not upload texture for '${photo.id}'")
                }

                val localTime = if (layer.freezeMotion) photo.duration else layer.localTime
                val cam = interp.sample(localTime)

                // Slide transitions are translation-only; the camera matrix is
                // composed with the zoom multiplier here.
                val matrix = buildLayerMatrix(
                    cam = cam,
                    fit = fit,
                    zoomMultiplier = layer.zoomMultiplier,
                    offsetX = layer.offsetX,
                    offsetY = layer.offsetY,
                )
                if (layer.blurRadius > 0.05) {
                    gl.drawLayerBlurred(
                        matrix = matrix,
                        textureId = texId,
                        alpha = layer.alpha.toFloat(),
                        blurRadius = layer.blurRadius.toFloat(),
                        viewportWidth = outputWidth,
                        viewportHeight = outputHeight,
                    )
                } else {
                    gl.drawLayer(matrix, texId, layer.alpha.toFloat())
                }
            }

            // Hand the finished frame to the encoder with an exact PTS.
            val ptsUs = timeline.presentationTimeUs(frameIndex, request.fps)
            eglCore.setPresentationTimeUs(ptsUs)
            if (!eglCore.swapBuffers()) {
                throw RenderException("eglSwapBuffers failed at frame $frameIndex")
            }
            written++
            drainBetweenFrames?.run()
            onFrameRendered(frameIndex)

            // Keep the photos the *next* frames can need: the layers drawn now
            // plus both sides of any transition inside the next second.
            val horizon = t + 1.0
            val upcoming = timeline.drawLayersAt(horizon).map { it.photoIndex }
            val keep = HashSet<String>()
            drawLayers.forEach { keep.add(request.photos[it.photoIndex].id) }
            upcoming.forEach { keep.add(request.photos[it].id) }
            textures?.trim(frameIndex.toLong(), keep)

            val now = System.currentTimeMillis()
            if (now - lastFrameMs > 2_000) {
                lastFrameMs = now
                Log.d(TAG, "frame $frameIndex/$totalFrames (keeping ${keep.size} textures)")
            }
        }

        onStage(RenderStage.FINISHING)
        if (written != totalFrames) {
            throw RenderException("rendered $written of $totalFrames frames")
        }
        return written
    }

    /**
     * Builds the clip-space matrix for one layer.
     *
     * A slide transition offsets the layer by a fraction of the viewport; that
     * is a 2D translation in clip space added to the camera matrix, which keeps
     * the maths in one place (spec §7.2).
     */
    private fun buildLayerMatrix(
        cam: CameraState,
        fit: ImageFit,
        zoomMultiplier: Double,
        offsetX: Double,
        offsetY: Double,
    ): FloatArray {
        val scaled = cam.copy(scale = cam.scale * zoomMultiplier)
        val base = cameraMatrix(scaled, fit, vp)
        if (offsetX == 0.0 && offsetY == 0.0) return base
        // Clip-space translation: a full viewport width is 2 units in NDC.
        base[12] = (base[12] + (offsetX * 2.0)).toFloat()
        base[13] = (base[13] - (offsetY * 2.0)).toFloat()
        return base
    }

    private fun validateKeyframeLegality(photo: PhotoRenderSpec, fit: ImageFit) {
        photo.keyframes.forEach { k ->
            val sMin = minScaleAtRotation(fit, vp, k.rotation) * 1.002
            if (k.scale < sMin - 1e-6) {
                Log.w(
                    TAG,
                    "photo '${photo.id}' keyframe at ${k.time}s has scale ${k.scale} " +
                        "below the minimum $sMin; it will be clamped while rendering",
                )
            }
        }
    }

    private fun ensureTexture(photoIndex: Int, frameIndex: Long): Int {
        val tm = textures ?: return -1
        val photo = request.photos[photoIndex]
        // Touch the LRU stamp of a resident texture without re-uploading.
        tm.touch(photo.id, frameIndex)?.let { return it }
        currentPhoto = photoIndex
        return tm.textureFor(photo.id, {
            try {
                decoder.decode(photo.path, maxTextureSize)
            } catch (e: PhotoDecoder.PhotoDecodeException) {
                Log.e(TAG, "decode failed for '${photo.id}': ${e.message}")
                null
            } catch (e: OutOfMemoryError) {
                Log.e(TAG, "out of memory decoding '${photo.id}'")
                null
            }
        }, frameIndex)
    }

    /** Frees GL, EGL and texture resources. Idempotent. */
    fun release() {
        if (disposed) return
        disposed = true
        try {
            textures?.release()
        } catch (e: Exception) {
            Log.w(TAG, "texture release: ${e.message}")
        }
        textures = null
        try {
            renderer?.release()
        } catch (e: Exception) {
            Log.w(TAG, "renderer release: ${e.message}")
        }
        renderer = null
        try {
            egl?.release()
        } catch (e: Exception) {
            Log.w(TAG, "egl release: ${e.message}")
        }
        egl = null
        interpolators = arrayOfNulls(0)
        fits = arrayOfNulls(0)
    }

    /** Diagnostics for the export summary: peak texture count is here. */
    fun textureStats(): Triple<Int, Int, Int> {
        val tm = textures ?: return Triple(0, 0, 0)
        return Triple(tm.createdCount, tm.evictedCount, tm.residentCount)
    }

    companion object {
        private const val TAG = "RenderEngine"

        /**
         * Reads back the current framebuffer. Only used by tests and by the
         * pbuffer fallback path; the normal path never touches the CPU.
         */
        fun readPixels(width: Int, height: Int): ByteBuffer {
            val buffer = ByteBuffer.allocateDirect(width * height * 4)
                .order(ByteOrder.nativeOrder())
            GLES20.glReadPixels(
                0, 0, width, height,
                GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buffer,
            )
            return buffer
        }
    }
}
