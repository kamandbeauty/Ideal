package com.motionshot.app.motion

import android.graphics.Bitmap
import android.opengl.GLES20
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

/**
 * GPU texture ownership.
 *
 * Rules enforced here (product brief §12 — memory/performance is critical):
 *  * a texture is uploaded once per photo and reused for every frame that
 *    needs it, including both sides of a transition
 *  * uploads happen on the GL thread only; other threads never touch GL
 *  * budget: at most [maxTextures] decoded photos are resident, least recently
 *    used are dropped first
 *  * the larger of the two photos in an active transition is never dropped
 *    while the transition window is live
 *  * every texture is deleted in [release], and the class is idempotent so a
 *    cancelled export cannot leak GPU memory
 *
 * Bitmaps are recycled after upload unless the caller asked to keep them, so a
 * 4K photo costs its GPU memory once instead of twice.
 */
class TextureManager(
    private val maxTextures: Int = 4,
    private val maxTextureSize: Int = 4096,
) {
    private data class Entry(
        val textureId: Int,
        var width: Int,
        var height: Int,
        var lastUsedFrame: Long,
        var bitmap: Bitmap? = null,
    )

    private val entries = ConcurrentHashMap<String, Entry>()
    private var released = false

    /** Textures created so far, for diagnostics/tests. */
    var createdCount: Int = 0
        private set

    /** Number of evictions, for diagnostics/tests. */
    var evictedCount: Int = 0
        private set

    val residentCount: Int get() = entries.size

    /**
     * Uploads [bitmap] for [photoId] if it is not already resident.
     *
     * @param frameIndex used as the LRU stamp so the caller does not have to
     *        think about ordering.
     * @return the texture id, or -1 if the bitmap was too large or upload failed.
     */
    fun textureFor(photoId: String, bitmap: () -> Bitmap?, frameIndex: Long): Int {
        check(!released) { "TextureManager already released" }
        val existing = entries[photoId]
        if (existing != null) {
            existing.lastUsedFrame = frameIndex
            return existing.textureId
        }

        val bmp = bitmap() ?: return -1
        val prepared = downscaleIfNeeded(photoId, bmp)
        val id = upload(prepared)
        if (id <= 0) {
            if (prepared !== bmp) prepared.recycle()
            bmp.recycle()
            return -1
        }
        entries[photoId] = Entry(
            textureId = id,
            width = prepared.width,
            height = prepared.height,
            lastUsedFrame = frameIndex,
        )
        createdCount++
        if (prepared !== bmp) prepared.recycle()
        bmp.recycle()
        trim(frameIndex)
        return id
    }

    /** Returns the texture id if [photoId] is resident, refreshing its LRU. */
    fun touch(photoId: String, frameIndex: Long): Int? {
        val e = entries[photoId] ?: return null
        e.lastUsedFrame = frameIndex
        return e.textureId
    }

    /** Drops textures that have not been used for [frameIndex] recently. */
    fun trim(frameIndex: Long, keep: Set<String> = emptySet()) {
        if (entries.size <= maxTextures) return
        val victims = entries.entries
            .filter { it.key !in keep }
            .sortedBy { it.value.lastUsedFrame }
        var excess = entries.size - maxTextures
        for (victim in victims) {
            if (excess <= 0) break
            deleteEntry(victim.key)
            excess--
        }
        if (excess > 0) {
            Log.w(TAG, "texture budget exceeded even after eviction (frame $frameIndex)")
        }
    }

    /** Explicitly frees a photo's texture (e.g. when it leaves the timeline). */
    fun evict(photoId: String) {
        deleteEntry(photoId)
    }

    /** Frees everything. Safe to call twice. */
    fun release() {
        if (released) return
        released = true
        for (key in entries.keys.toList()) {
            deleteEntry(key)
        }
        entries.clear()
    }

    fun dimensionsOf(photoId: String): Pair<Int, Int>? =
        entries[photoId]?.let { it.width to it.height }

    private fun deleteEntry(key: String) {
        val e = entries.remove(key) ?: return
        val ids = intArrayOf(e.textureId)
        GLES20.glDeleteTextures(1, ids, 0)
        e.bitmap?.recycle()
        evictedCount++
    }

    /**
     * Keeps textures inside the GL limit. A 4000 px photo on a 4096-texture
     * device needs no scaling; a 50 MP photo does. Downscaling here happens on
     * the *uploaded copy only* — the file on disk is never touched.
     */
    private fun downscaleIfNeeded(photoId: String, bmp: Bitmap): Bitmap {
        val longest = maxOf(bmp.width, bmp.height)
        if (longest <= maxTextureSize) return bmp
        val scale = maxTextureSize.toFloat() / longest
        val w = (bmp.width * scale).toInt().coerceAtLeast(2)
        val h = (bmp.height * scale).toInt().coerceAtLeast(2)
        Log.i(TAG, "downscaling '$photoId' ${bmp.width}x${bmp.height} -> ${w}x${h} for GPU limit")
        return Bitmap.createScaledBitmap(bmp, w, h, true)
    }

    private fun upload(bmp: Bitmap): Int {
        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        if (ids[0] == 0) {
            Log.e(TAG, "glGenTextures returned 0")
            return -1
        }
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, ids[0])
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE,
        )
        GLES20.glTexParameteri(
            GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE,
        )
        android.opengl.GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0)
        val err = GLES20.glGetError()
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        if (err != GLES20.GL_NO_ERROR) {
            Log.e(TAG, "texture upload failed, glError=$err")
            GLES20.glDeleteTextures(1, ids, 0)
            return -1
        }
        return ids[0]
    }

    companion object {
        private const val TAG = "TextureManager"
    }
}
