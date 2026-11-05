package com.motionshot.app.motion

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.util.Log
import android.view.Surface

/**
 * EGL context management for offscreen rendering.
 *
 * Two modes:
 *  * **pbuffer** — for devices where the encoder surface cannot be used
 *    directly (some OEM drivers); frames are rendered then read back and
 *    written to the encoder input.
 *  * **surface** — the preferred mode: the encoder's input `Surface` *is* the
 *    EGL window surface, so a frame goes straight from the GPU to MediaCodec
 *    with no CPU copy and no extra allocation per frame. That is what keeps a
 *    4K 60 fps export inside a mid-range phone's memory budget.
 */
class EGLCore {

    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var context: EGLContext = EGL14.EGL_NO_CONTEXT
    private var surface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var config: EGLConfig? = null
    private var isWindowSurface = false

    var isEs3: Boolean = false
        private set

    val isReady: Boolean
        get() = display != EGL14.EGL_NO_DISPLAY && context != EGL14.EGL_NO_CONTEXT

    /**
     * Sets up EGL. Prefers ES 3.0 and falls back to ES 2.0 automatically, so a
     * device that advertises ES3 but has a broken driver still exports.
     */
    fun init(windowSurface: Surface? = null, width: Int = 0, height: Int = 0): Boolean {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display == EGL14.EGL_NO_DISPLAY) {
            Log.e(TAG, "no EGL display")
            return false
        }
        val version = IntArray(2)
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) {
            Log.e(TAG, "eglInitialize failed")
            return false
        }

        val attempts = if (windowSurface != null) {
            listOf(true, false)
        } else {
            listOf(false)
        }
        for (es3 in attempts) {
            if (tryCreate(es3, windowSurface, width, height)) {
                isEs3 = es3
                Log.i(TAG, "EGL ready (ES ${if (es3) "3" else "2"}, " +
                    "surface=${if (windowSurface != null) "window" else "pbuffer"})")
                return true
            }
        }
        Log.e(TAG, "could not create an EGL context on this device")
        return false
    }

    private fun tryCreate(es3: Boolean, windowSurface: Surface?, width: Int, height: Int): Boolean {
        // EGL_OPENGL_ES3_BIT_KHR is not exposed by EGL14; 0x40 is the value
        // defined by KHR_create_context and is what every driver expects.
        val renderableType = if (es3) EGL_OPENGL_ES3_BIT else EGL14.EGL_OPENGL_ES2_BIT
        val attribs = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, renderableType,
            EGL14.EGL_SURFACE_TYPE,
            if (windowSurface != null) EGL14.EGL_WINDOW_BIT else EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        if (!EGL14.eglChooseConfig(
                display, attribs, 0, configs, 0, 1, numConfigs, 0,
            ) || numConfigs[0] == 0
        ) {
            return false
        }
        val cfg = configs[0] ?: return false

        val ctxAttribs = intArrayOf(
            EGL14.EGL_CONTEXT_CLIENT_VERSION, if (es3) 3 else 2,
            EGL14.EGL_NONE,
        )
        val ctx = EGL14.eglCreateContext(
            display, cfg, EGL14.EGL_NO_CONTEXT, ctxAttribs, 0,
        )
        if (ctx == null || ctx == EGL14.EGL_NO_CONTEXT) return false

        val surf: EGLSurface = if (windowSurface != null) {
            val surfAttribs = intArrayOf(EGL14.EGL_NONE)
            val s = EGL14.eglCreateWindowSurface(display, cfg, windowSurface, surfAttribs, 0)
            if (s == null || s == EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroyContext(display, ctx)
                return false
            }
            isWindowSurface = true
            s
        } else {
            val surfAttribs = intArrayOf(
                EGL14.EGL_WIDTH, width.coerceAtLeast(2),
                EGL14.EGL_HEIGHT, height.coerceAtLeast(2),
                EGL14.EGL_NONE,
            )
            val s = EGL14.eglCreatePbufferSurface(display, cfg, surfAttribs, 0)
            if (s == null || s == EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroyContext(display, ctx)
                return false
            }
            isWindowSurface = false
            s
        }

        if (!EGL14.eglMakeCurrent(display, surf, surf, ctx)) {
            EGL14.eglDestroySurface(display, surf)
            EGL14.eglDestroyContext(display, ctx)
            return false
        }
        context = ctx
        surface = surf
        config = cfg
        return true
    }

    /** Swaps buffers (window surfaces only). */
    fun swapBuffers(): Boolean {
        if (!isReady || !isWindowSurface) return false
        return EGL14.eglSwapBuffers(display, surface)
    }

    /**
     * Sets the presentation time on the window surface so MediaCodec timestamps
     * this frame correctly. Uses `EGLExt.eglPresentationTimeANDROID` when the
     * API level provides it (17+); otherwise the encoder infers PTS from our
     * explicit `queueInputBuffer` timestamps on the byte-buffer path.
     */
    fun setPresentationTimeUs(timeUs: Long) {
        if (!isReady || !isWindowSurface) return
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.JELLY_BEAN_MR2) {
            try {
                android.opengl.EGLExt.eglPresentationTimeANDROID(
                    display, surface, timeUs * 1000L,
                )
            } catch (e: Exception) {
                Log.w(TAG, "presentation time unsupported: ${e.message}")
            }
        }
    }

    /** Releases every EGL resource. Idempotent. */
    fun release() {
        if (display != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(
                display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_CONTEXT,
            )
            if (surface != EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroySurface(display, surface)
            }
            if (context != EGL14.EGL_NO_CONTEXT) {
                EGL14.eglDestroyContext(display, context)
            }
            EGL14.eglTerminate(display)
        }
        display = EGL14.EGL_NO_DISPLAY
        context = EGL14.EGL_NO_CONTEXT
        surface = EGL14.EGL_NO_SURFACE
        config = null
    }

    companion object {
        private const val TAG = "EGLCore"
        private const val EGL_OPENGL_ES3_BIT = 0x40
    }
}
