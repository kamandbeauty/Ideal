package app.subflow.media

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts

/**
 * Android Photo Picker wrapper.
 *
 * The picker is the required UX (no storage permission, system-scoped access).
 * `registerForActivityResult` is not usable here because `FlutterActivity`
 * extends `android.app.Activity`, not `ComponentActivity`; instead the contract
 * object is used directly - it creates the correct intent (Photo Picker on
 * Android 13+, the system fallback or `ACTION_OPEN_DOCUMENT` below that) and
 * parses the result, so behaviour is identical to the modern API without
 * forcing a different activity base class.
 *
 * The picker grants read access for the current app lifetime, so we also try to
 * take a persistable permission; when the platform refuses, the project stays
 * usable and the editor detects a stale URI and asks the user to re-pick.
 */
class MediaPicker(private val activity: Activity) {
    private var pending: ((Result<Uri?>) -> Unit)? = null
    private val contract = ActivityResultContracts.PickVisualMedia()

    fun pickVideo(callback: (Result<Uri?>) -> Unit) {
        if (pending != null) {
            callback(Result.failure(IllegalStateException("picker already open")))
            return
        }
        if (!ActivityResultContracts.PickVisualMedia.isPhotoPickerAvailable(activity)) {
            Log.w(TAG, "no photo picker; falling back to document picker")
        }
        val request = PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly)
        val intent = contract.createIntent(activity, request)
        if (intent.resolveActivity(activity.packageManager) == null) {
            callback(Result.failure(IllegalStateException("no picker app available")))
            return
        }
        pending = callback
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (error: Exception) {
            pending = null
            callback(Result.failure(error))
        }
    }

    /**
     * Returns true when the result belonged to this picker, so the activity can
     * stop propagating it to plugins.
     */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val callback = pending
        pending = null
        if (callback == null) return true
        val uri = contract.parseResult(resultCode, data)
        if (uri == null) {
            callback(Result.success(null))
            return true
        }
        persistPermission(uri)
        callback(Result.success(uri))
        return true
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

    companion object {
        private const val TAG = "SubFlowPicker"
        private const val REQUEST_CODE = 0x5F107
    }
}
