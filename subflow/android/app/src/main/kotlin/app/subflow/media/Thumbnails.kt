package app.subflow.media

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest

/**
 * Video frames as JPEG files in the cache directory.
 *
 * The project cards and the editor filmstrip need a still image; MediaCodec does
 * not hand one out, but MediaMetadataRetriever does. Frames are keyed by a hash of
 * the source plus the timestamp, so the second build of the same list is a file
 * read instead of a decode.
 */
object Thumbnails {
    private const val TAG = "SubFlowThumbs"

    fun frame(context: Context, uri: Uri, key: String, timeMs: Long, widthPx: Int): String? {
        val name = "${digest("$key@$timeMs@$widthPx")}.jpg"
        val dir = File(context.cacheDir, "thumbs").apply { mkdirs() }
        val target = File(dir, name)
        if (target.isFile && target.length() > 0) return target.absolutePath

        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            val scaled = retriever.getScaledFrameAtTime(
                timeMs * 1000,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                widthPx,
                widthPx,
            ) ?: retriever.getFrameAtTime(timeMs * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            if (scaled == null) return null
            val temp = File(dir, "$name.part")
            FileOutputStream(temp).use { out ->
                scaled.compress(Bitmap.CompressFormat.JPEG, 82, out)
            }
            scaled.recycle()
            if (target.exists()) target.delete()
            if (!temp.renameTo(target)) {
                temp.delete()
                return null
            }
            target.absolutePath
        } catch (error: Exception) {
            Log.w(TAG, "thumbnail failed for $uri", error)
            null
        } finally {
            try {
                retriever.release()
            } catch (ignored: Exception) {
                // A retriever that never opened has nothing to release.
            }
        }
    }

    private fun digest(value: String): String {
        val bytes = MessageDigest.getInstance("SHA-1").digest(value.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }.take(24)
    }
}
