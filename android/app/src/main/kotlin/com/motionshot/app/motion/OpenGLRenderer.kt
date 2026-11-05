package com.motionshot.app.motion

import android.opengl.GLES20
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * The GL program that draws one photo layer (plus an optional two-pass
 * separable Gaussian blur for `blurTransition`).
 *
 * Two shaders are built: an OpenGL ES 3.0 path (used when the context is ES 3)
 * and an ES 2.0 fallback for older devices. They are functionally identical —
 * the same matrix, the same alpha handling — so a fallback device produces the
 * same framing.
 *
 * Blending is premultiplied-alpha (`ONE, ONE_MINUS_SRC_ALPHA`) because the layer
 * alpha is baked into the fragment colour. That makes cross dissolves exact and
 * avoids the dark halo you get from mixing premultiplied textures with
 * straight-alpha blending.
 *
 * Layer geometry: a unit quad in texture space (0..1), transformed by the
 * camera matrix (see [cameraMatrix]) to clip space. Because the whole quad is
 * drawn and the camera matrix zooms in, the GPU's bilinear filter does the
 * sampling — the same math as the Python reference, with hardware filtering.
 */
class OpenGLRenderer(
    private val useEs3: Boolean,
    private val offsetForTransition: Boolean = true,
) {
    private var program = 0
    private var uMatrix = 0
    private var uAlpha = 0
    private var uTexture = 0
    private var aPosition = 0
    private var aTexCoord = 0

    private lateinit var quad: FloatBuffer
    private val VERTEX_COUNT = 6 // two triangles

    // Ping-pong framebuffers + separable 9-tap Gaussian blur program (spec §7.2)
    private var fbo = 0
    private var fboTexture = 0
    private var fboScratch = 0
    private var fboScratchTexture = 0
    private var fboWidth = 0
    private var fboHeight = 0

    private var blurProgram = 0
    private var blurMatrixLoc = 0
    private var blurStepLoc = 0
    private var blurAlphaLoc = 0
    private var blurSamplerLoc = 0
    private var blurPosLoc = 0
    private var blurUvLoc = 0

    val isReady: Boolean get() = program != 0

    /** Compiles the shaders. Must run on the GL thread with a current context. */
    fun init(): Boolean {
        val versionLine = if (useEs3) "#version 300 es\n" else ""
        val vs = if (useEs3) {
            """
            $versionLine
            in vec2 aPosition;
            in vec2 aTexCoord;
            uniform mat4 uMatrix;
            out vec2 vTexCoord;
            void main() {
                gl_Position = uMatrix * vec4(aPosition, 0.0, 1.0);
                vTexCoord = aTexCoord;
            }
            """.trimIndent()
        } else {
            """
            attribute vec2 aPosition;
            attribute vec2 aTexCoord;
            uniform mat4 uMatrix;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = uMatrix * vec4(aPosition, 0.0, 1.0);
                vTexCoord = aTexCoord;
            }
            """.trimIndent()
        }
        val fs = if (useEs3) {
            """
            $versionLine
            precision mediump float;
            in vec2 vTexCoord;
            uniform sampler2D uTexture;
            uniform float uAlpha;
            out vec4 fragColor;
            void main() {
                vec4 c = texture(uTexture, vTexCoord);
                fragColor = vec4(c.rgb * uAlpha, uAlpha);
            }
            """.trimIndent()
        } else {
            """
            precision mediump float;
            varying vec2 vTexCoord;
            uniform sampler2D uTexture;
            uniform float uAlpha;
            void main() {
                vec4 c = texture2D(uTexture, vTexCoord);
                gl_FragColor = vec4(c.rgb * uAlpha, uAlpha);
            }
            """.trimIndent()
        }

        program = buildProgram(vs, fs) ?: return false
        uMatrix = GLES20.glGetUniformLocation(program, "uMatrix")
        uAlpha = GLES20.glGetUniformLocation(program, "uAlpha")
        uTexture = GLES20.glGetUniformLocation(program, "uTexture")
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")

        // Optional separable 9-tap Gaussian blur shader; if compilation fails on
        // a buggy driver we keep `blurProgram == 0` and fall back to cross-dissolve.
        val blurFs = if (useEs3) {
            """
            $versionLine
            precision mediump float;
            in vec2 vTexCoord;
            uniform sampler2D uTexture;
            uniform vec2 uBlurStep;
            uniform float uAlpha;
            out vec4 fragColor;
            void main() {
                vec3 sum = texture(uTexture, vTexCoord).rgb * 0.227027;
                sum += texture(uTexture, vTexCoord + uBlurStep * 1.0).rgb * 0.1945946;
                sum += texture(uTexture, vTexCoord - uBlurStep * 1.0).rgb * 0.1945946;
                sum += texture(uTexture, vTexCoord + uBlurStep * 2.0).rgb * 0.1216216;
                sum += texture(uTexture, vTexCoord - uBlurStep * 2.0).rgb * 0.1216216;
                sum += texture(uTexture, vTexCoord + uBlurStep * 3.0).rgb * 0.054054;
                sum += texture(uTexture, vTexCoord - uBlurStep * 3.0).rgb * 0.054054;
                sum += texture(uTexture, vTexCoord + uBlurStep * 4.0).rgb * 0.016216;
                sum += texture(uTexture, vTexCoord - uBlurStep * 4.0).rgb * 0.016216;
                fragColor = vec4(sum * uAlpha, uAlpha);
            }
            """.trimIndent()
        } else {
            """
            precision mediump float;
            varying vec2 vTexCoord;
            uniform sampler2D uTexture;
            uniform vec2 uBlurStep;
            uniform float uAlpha;
            void main() {
                vec3 sum = texture2D(uTexture, vTexCoord).rgb * 0.227027;
                sum += texture2D(uTexture, vTexCoord + uBlurStep * 1.0).rgb * 0.1945946;
                sum += texture2D(uTexture, vTexCoord - uBlurStep * 1.0).rgb * 0.1945946;
                sum += texture2D(uTexture, vTexCoord + uBlurStep * 2.0).rgb * 0.1216216;
                sum += texture2D(uTexture, vTexCoord - uBlurStep * 2.0).rgb * 0.1216216;
                sum += texture2D(uTexture, vTexCoord + uBlurStep * 3.0).rgb * 0.054054;
                sum += texture2D(uTexture, vTexCoord - uBlurStep * 3.0).rgb * 0.054054;
                sum += texture2D(uTexture, vTexCoord + uBlurStep * 4.0).rgb * 0.016216;
                sum += texture2D(uTexture, vTexCoord - uBlurStep * 4.0).rgb * 0.016216;
                gl_FragColor = vec4(sum * uAlpha, uAlpha);
            }
            """.trimIndent()
        }
        blurProgram = buildProgram(vs, blurFs) ?: 0
        if (blurProgram != 0) {
            blurMatrixLoc = GLES20.glGetUniformLocation(blurProgram, "uMatrix")
            blurStepLoc = GLES20.glGetUniformLocation(blurProgram, "uBlurStep")
            blurAlphaLoc = GLES20.glGetUniformLocation(blurProgram, "uAlpha")
            blurSamplerLoc = GLES20.glGetUniformLocation(blurProgram, "uTexture")
            blurPosLoc = GLES20.glGetAttribLocation(blurProgram, "aPosition")
            blurUvLoc = GLES20.glGetAttribLocation(blurProgram, "aTexCoord")
        }

        // Unit quad, two triangles. Texture v is flipped so (0,0) is top-left
        // of the image, matching the normalized image space used everywhere.
        val verts = floatArrayOf(
            0f, 0f, 0f, 0f,
            1f, 0f, 1f, 0f,
            0f, 1f, 0f, 1f,
            1f, 0f, 1f, 0f,
            1f, 1f, 1f, 1f,
            0f, 1f, 0f, 1f,
        )
        quad = ByteBuffer.allocateDirect(verts.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                put(verts)
                position(0)
            }

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDisable(GLES20.GL_CULL_FACE)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        checkGl("init")
        return true
    }

    /**
     * Draws one layer into the currently bound framebuffer.
     *
     * @param matrix clip-space matrix for the unit quad (see [cameraMatrix])
     * @param textureId texture of the photo
     * @param alpha layer opacity 0..1 (premultiplied inside the shader)
     */
    fun drawLayer(matrix: FloatArray, textureId: Int, alpha: Float) {
        if (program == 0 || textureId <= 0) return
        GLES20.glUseProgram(program)
        GLES20.glUniformMatrix4fv(uMatrix, 1, false, matrix, 0)
        GLES20.glUniform1f(uAlpha, alpha.coerceIn(0f, 1f))
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glUniform1i(uTexture, 0)

        quad.position(0)
        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 16, quad)
        quad.position(2)
        GLES20.glEnableVertexAttribArray(aTexCoord)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 16, quad)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, VERTEX_COUNT)

        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }

    /**
     * Draws one layer with a two-pass separable Gaussian blur.
     *
     * Falls back to [drawLayer] (standard cross-dissolve, spec §7.2) if FBOs
     * or the blur shader are unavailable on this GPU.
     */
    fun drawLayerBlurred(
        matrix: FloatArray,
        textureId: Int,
        alpha: Float,
        blurRadius: Float,
        viewportWidth: Int,
        viewportHeight: Int,
    ) {
        if (blurRadius <= 0.05f || blurProgram == 0 || viewportWidth <= 0 || viewportHeight <= 0 ||
            !ensureFramebuffer(viewportWidth, viewportHeight)
        ) {
            drawLayer(matrix, textureId, alpha)
            return
        }

        // Pass 0: render the unblurred photo layer into `fbo` at full opacity.
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo)
        GLES20.glViewport(0, 0, fboWidth, fboHeight)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        drawLayer(matrix, textureId, 1f)

        val stepScale = (blurRadius / 4f).coerceAtLeast(0.25f)

        // Pass 1: horizontal Gaussian blur into `fboScratch`.
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboScratch)
        GLES20.glViewport(0, 0, fboWidth, fboHeight)
        drawBlurPass(
            srcTexture = fboTexture,
            stepX = stepScale / fboWidth.toFloat(),
            stepY = 0f,
            alpha = 1f,
        )

        // Pass 2: vertical Gaussian blur composited onto the window surface.
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glViewport(0, 0, viewportWidth, viewportHeight)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        drawBlurPass(
            srcTexture = fboScratchTexture,
            stepX = 0f,
            stepY = stepScale / fboHeight.toFloat(),
            alpha = alpha.coerceIn(0f, 1f),
        )
    }

    private fun drawBlurPass(srcTexture: Int, stepX: Float, stepY: Float, alpha: Float) {
        GLES20.glUseProgram(blurProgram)
        GLES20.glUniformMatrix4fv(blurMatrixLoc, 1, false, FULLSCREEN_QUAD_MATRIX, 0)
        GLES20.glUniform2f(blurStepLoc, stepX, stepY)
        GLES20.glUniform1f(blurAlphaLoc, alpha)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, srcTexture)
        GLES20.glUniform1i(blurSamplerLoc, 0)

        quad.position(0)
        GLES20.glEnableVertexAttribArray(blurPosLoc)
        GLES20.glVertexAttribPointer(blurPosLoc, 2, GLES20.GL_FLOAT, false, 16, quad)
        quad.position(2)
        GLES20.glEnableVertexAttribArray(blurUvLoc)
        GLES20.glVertexAttribPointer(blurUvLoc, 2, GLES20.GL_FLOAT, false, 16, quad)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, VERTEX_COUNT)

        GLES20.glDisableVertexAttribArray(blurPosLoc)
        GLES20.glDisableVertexAttribArray(blurUvLoc)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }

    /** Clears the current framebuffer to opaque black. */
    fun clear() {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
    }

    /**
     * Prepares the full-screen ping-pong FBOs used by the blur transition.
     * Returns false if framebuffers are unavailable, in which case the caller
     * falls back to a cross dissolve (documented behaviour, spec §7.2).
     */
    fun ensureFramebuffer(width: Int, height: Int): Boolean {
        if (fboWidth == width && fboHeight == height && fbo != 0 && fboScratch != 0) return true
        releaseFramebuffer()
        val first = createTarget(width, height) ?: return false
        fbo = first.first
        fboTexture = first.second
        val second = createTarget(width, height)
        if (second == null) {
            releaseFramebuffer()
            return false
        }
        fboScratch = second.first
        fboScratchTexture = second.second
        fboWidth = width
        fboHeight = height
        return true
    }

    private fun createTarget(width: Int, height: Int): Pair<Int, Int>? {
        val ids = IntArray(1)
        GLES20.glGenFramebuffers(1, ids, 0)
        val fb = ids[0]
        val texIds = IntArray(1)
        GLES20.glGenTextures(1, texIds, 0)
        val tex = texIds[0]
        if (fb == 0 || tex == 0) {
            if (fb != 0) GLES20.glDeleteFramebuffers(1, intArrayOf(fb), 0)
            if (tex != 0) GLES20.glDeleteTextures(1, intArrayOf(tex), 0)
            return null
        }
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, width, height, 0,
            GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null,
        )
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fb)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D, tex, 0,
        )
        val status = GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        if (status != GLES20.GL_FRAMEBUFFER_COMPLETE) {
            Log.e(TAG, "framebuffer incomplete: 0x${Integer.toHexString(status)}")
            GLES20.glDeleteFramebuffers(1, intArrayOf(fb), 0)
            GLES20.glDeleteTextures(1, intArrayOf(tex), 0)
            return null
        }
        return fb to tex
    }

    fun bindFramebuffer() {
        check(fbo != 0) { "framebuffer not prepared" }
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo)
        GLES20.glViewport(0, 0, fboWidth, fboHeight)
    }

    fun unbindFramebuffer() {
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
    }

    fun framebufferTextureId(): Int = fboTexture

    /** Frees programs and buffers. Idempotent. */
    fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        if (blurProgram != 0) {
            GLES20.glDeleteProgram(blurProgram)
            blurProgram = 0
        }
        releaseFramebuffer()
        Log.i(TAG, "renderer released")
    }

    private fun releaseFramebuffer() {
        if (fbo != 0) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(fbo), 0)
            fbo = 0
        }
        if (fboTexture != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(fboTexture), 0)
            fboTexture = 0
        }
        if (fboScratch != 0) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(fboScratch), 0)
            fboScratch = 0
        }
        if (fboScratchTexture != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(fboScratchTexture), 0)
            fboScratchTexture = 0
        }
        fboWidth = 0
        fboHeight = 0
    }

    private fun buildProgram(vsSrc: String, fsSrc: String): Int? {
        val vs = compile(GLES20.GL_VERTEX_SHADER, vsSrc) ?: return null
        val fs = compile(GLES20.GL_FRAGMENT_SHADER, fsSrc) ?: return null
        val p = GLES20.glCreateProgram()
        GLES20.glAttachShader(p, vs)
        GLES20.glAttachShader(p, fs)
        GLES20.glLinkProgram(p)
        val status = IntArray(1)
        GLES20.glGetProgramiv(p, GLES20.GL_LINK_STATUS, status, 0)
        if (status[0] != GLES20.GL_TRUE) {
            Log.e(TAG, "program link failed: ${GLES20.glGetProgramInfoLog(p)}")
            GLES20.glDeleteProgram(p)
            GLES20.glDeleteShader(vs)
            GLES20.glDeleteShader(fs)
            return null
        }
        GLES20.glDeleteShader(vs)
        GLES20.glDeleteShader(fs)
        return p
    }

    private fun compile(type: Int, src: String): Int? {
        val shader = GLES20.glCreateShader(type)
        if (shader == 0) return null
        GLES20.glShaderSource(shader, src)
        GLES20.glCompileShader(shader)
        val status = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0)
        if (status[0] != GLES20.GL_TRUE) {
            Log.e(TAG, "shader compile failed: ${GLES20.glGetShaderInfoLog(shader)}")
            GLES20.glDeleteShader(shader)
            return null
        }
        return shader
    }

    private fun checkGl(stage: String) {
        val err = GLES20.glGetError()
        if (err != GLES20.GL_NO_ERROR) {
            Log.w(TAG, "glError 0x${Integer.toHexString(err)} after $stage")
        }
    }

    companion object {
        private const val TAG = "OpenGLRenderer"

        /** Maps unit quad `[0,1]^2` straight to clip space `[-1,1]^2` (column-major). */
        private val FULLSCREEN_QUAD_MATRIX = floatArrayOf(
            2f, 0f, 0f, 0f,
            0f, 2f, 0f, 0f,
            0f, 0f, 1f, 0f,
            -1f, -1f, 0f, 1f,
        )
    }
}
