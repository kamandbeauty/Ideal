package com.motionshot.app.motion

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File

/**
 * Publishes finished videos and hands files to other apps.
 *
 * On API 29+ the MP4 is inserted into `MediaStore.Video` (the "Movies/MotionShot"
 * collection) with `IS_PENDING`, the bytes are copied in, then the flag is
 * cleared. That means the gallery never sees a half-written file, no storage
 * permission is required, and the export is visible in every gallery app.
 *
 * On API 24-28 it falls back to a real file in `Movies/MotionShot` plus a
 * MediaScanner notification.
 */
object StorageManager {
    private const val TAG = "StorageManager"
    private const val RELATIVE_DIR = "Movies/MotionShot"

    /** Copies [source] into the gallery, returning a content:// uri on success. */
    @JvmStatic
    fun saveVideoToGallery(context: Context, source: File, displayName: String): Uri? {
        if (!source.exists() || source.length() < 4096) {
            Log.e(TAG, "refusing to publish an empty file: ${source.absolutePath}")
            return null
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(context, source, displayName)
        } else {
            saveWithLegacyPath(context, source, displayName)
        }
    }

    private fun saveWithMediaStore(context: Context, source: File, name: String): Uri? {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, name)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, RELATIVE_DIR)
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = try {
            resolver.insert(collection, values)
        } catch (e: Exception) {
            Log.e(TAG, "MediaStore insert failed: ${e.message}")
            null
        } ?: return null

        return try {
            resolver.openOutputStream(uri)?.use { out ->
                source.inputStream().use { input -> input.copyTo(out, 256 * 1024) }
            } ?: throw IllegalStateException("cannot open output stream")
            val done = ContentValues().apply {
                put(MediaStore.Video.Media.IS_PENDING, 0)
                put(MediaStore.Video.Media.SIZE, source.length())
            }
            resolver.update(uri, done, null, null)
            Log.i(TAG, "published to gallery: $uri")
            uri
        } catch (e: Exception) {
            Log.e(TAG, "publishing failed, deleting partial entry: ${e.message}")
            try {
                resolver.delete(uri, null, null)
            } catch (ignored: Exception) {
            }
            null
        }
    }

    private fun saveWithLegacyPath(context: Context, source: File, name: String): Uri? {
        return try {
            @Suppress("DEPRECATION")
            val dir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
                "MotionShot",
            )
            dir.mkdirs()
            val target = File(dir, name)
            source.inputStream().use { input ->
                target.outputStream().use { out -> input.copyTo(out, 256 * 1024) }
            }
            MediaScannerConnection.scanFile(
                context, arrayOf(target.absolutePath), arrayOf("video/mp4"), null,
            )
            Uri.fromFile(target)
        } catch (e: Exception) {
            Log.e(TAG, "legacy gallery save failed: ${e.message}")
            null
        }
    }

    /** Share intent for a produced file, via FileProvider (no storage permission). */
    @JvmStatic
    fun shareVideo(context: Context, file: File): Boolean {
        if (!file.exists()) return false
        return try {
            val uri: Uri = FileProvider.getUriForFile(
                context, "${context.packageName}.fileprovider", file,
            )
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "video/mp4"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(
                Intent.createChooser(intent, "MotionShot").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
            true
        } catch (e: Exception) {
            Log.e(TAG, "share failed: ${e.message}")
            false
        }
    }

    /** Deletes stale exports from a previous run. */
    @JvmStatic
    fun cleanupTemp(dir: File) {
        try {
            dir.listFiles()?.forEach { f ->
                if (f.name.startsWith("export_") && f.name.endsWith(".mp4")) {
                    if (f.delete()) Log.d(TAG, "removed stale ${f.name}")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "cleanup failed: ${e.message}")
        }
    }
}
