package app.subflow.media

import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts

/**
 * Android Photo Picker wrapper.
 *
 * The picker is the required UX (no storage permission, system-scoped access).
 * Photo Picker grants read access for the current app lifetime, so we also try
 * to take a persistable permission; when the platform refuses (it usually does
 * for the picker), the project is still usable and the editor detects a stale
 * URI and asks the user to re-pick the file - which is the behaviour the brief
 * asks for instead of a crash.
 */
class MediaPicker(private val activity: ComponentActivity) {
    private var pending: ((Result<Uri?>) -> Unit)? = null

    private val launcher = activity.registerForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        val callback = pending
        pending = null
        if (uri == null) {
            callback?.invoke(Result.success(null))
            return@registerForActivityResult
        }
        persistPermission(uri)
        callback?.invoke(Result.success(uri))
    }

    private fun persistPermission(uri: Uri) {
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            Log.d(TAG, "persistable read permission acquired")
        } catch (error: SecurityException) {
            Log.d(TAG, "photo picker granted transient access only", error)
        }
    }

    fun pickVideo(callback: (Result<Uri?>) -> Unit) {
        if (pending != null) {
            callback(Result.failure(IllegalStateException("picker already open")))
            return
        }
        pending = callback
        launcher.launch(
            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly)
        )
    }

    companion object {
        private const val TAG = "SubFlowPicker"
    }
}
