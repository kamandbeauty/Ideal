package com.motionshot.app

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import java.io.File

/**
 * Opens the system document picker restricted to audio and hands back a **local
 * copy** of the chosen file.
 *
 * A copy is used rather than the content uri because MediaExtractor needs a
 * stable, seekable data source for the whole export, and the user may revoke
 * access or delete the original mid-render. The copy lives in the app cache and
 * is removed with the other export temporaries.
 */
object AudioPicker {
    private const val TAG = "AudioPicker"
    const val REQUEST_PICK_AUDIO = 4901

    sealed interface Outcome {
        data object Cancelled : Outcome
        data class Picked(val path: String) : Outcome
        data class Failed(val code: String, val message: String) : Outcome
    }

    /** Starts the picker. Returns false if no document picker is installed. */
    fun open(activity: Activity): Boolean {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "audio/mpeg",
                    "audio/mp4",
                    "audio/aac",
                    "audio/wav",
                    "audio/x-wav",
                    "audio/ogg",
                    "audio/flac",
                ),
            )
        }
        return try {
            activity.startActivityForResult(intent, REQUEST_PICK_AUDIO)
            true
        } catch (e: Exception) {
            Log.e(TAG, "no document picker: ${e.message}")
            false
        }
    }

    /**
     * Handles the activity result. Returns null only when [requestCode] belongs
     * to another requester (such as `image_picker`), otherwise returns an
     * [Outcome] so the pending Dart call always completes.
     */
    fun handleResult(requestCode: Int, resultCode: Int, data: Intent?): Outcome? {
        if (requestCode != REQUEST_PICK_AUDIO) return null
        if (resultCode != Activity.RESULT_OK) return Outcome.Cancelled
        val uri = data?.data ?: return Outcome.Cancelled
        return copyToCache(uri)
    }

    private fun copyToCache(uri: Uri): Outcome {
        val ctx = AppContextHolder.context
            ?: return Outcome.Failed("INTERNAL", "application context unavailable")
        return try {
            val name = displayName(
                ctx.contentResolver.query(
                    uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null,
                ),
            ) ?: "audio_${System.currentTimeMillis()}"
            val dir = File(ctx.cacheDir, "audio")
            dir.mkdirs()
            val target = File(dir, name.replace(Regex("[^A-Za-z0-9._-]"), "_"))
            ctx.contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { out -> input.copyTo(out, 128 * 1024) }
            } ?: return Outcome.Failed("AUDIO_UNREADABLE", "could not open selected audio stream")
            if (target.length() == 0L) {
                target.delete()
                return Outcome.Failed("AUDIO_UNREADABLE", "selected audio file is empty")
            }
            Outcome.Picked(target.absolutePath)
        } catch (e: SecurityException) {
            Log.e(TAG, "permission denied reading audio: ${e.message}")
            Outcome.Failed("PERMISSION_DENIED", e.message ?: "permission denied reading audio")
        } catch (e: Exception) {
            Log.e(TAG, "copy failed: ${e.message}")
            Outcome.Failed("AUDIO_UNREADABLE", e.message ?: "could not read audio file")
        }
    }

    private fun displayName(cursor: Cursor?): String? {
        cursor ?: return null
        return try {
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) cursor.getString(idx) else null
            } else {
                null
            }
        } finally {
            cursor.close()
        }
    }
}

/**
 * Holds the application context for helpers that run outside an Activity
 * (the audio picker copy, thumbnail work). Set once in `MainActivity`.
 */
object AppContextHolder {
    @Volatile
    var context: android.content.Context? = null
}
