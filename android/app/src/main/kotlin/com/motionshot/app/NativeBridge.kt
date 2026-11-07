package com.motionshot.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.motionshot.app.motion.DeviceCapabilities
import com.motionshot.app.motion.ExportRequest
import com.motionshot.app.motion.ExportService
import com.motionshot.app.motion.ExportWorker
import com.motionshot.app.motion.MediaProbe
import com.motionshot.app.motion.StorageManager
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

/**
 * The Flutter <-> Kotlin boundary.
 *
 * Contract (mirrored in `lib/features/platform/native_video_bridge/video_bridge.dart`):
 *
 *   getCapabilities()            -> JSON DeviceCapabilities
 *   probeRequest(json)           -> JSON { supported, note, actualWidth, ... }
 *   startExport(json)            -> sessionId (String)
 *   cancelExport({sessionId})    -> Boolean
 *   isExportRunning({sessionId}) -> Boolean
 *   probeFile({path})            -> JSON ProbeResult
 *   saveToGallery({path})        -> content uri or null
 *   shareFile({path})            -> void
 *
 * Errors: every failure is reported as a `PlatformException` whose `code` is one
 * of the documented failure codes (`PHOTO_MISSING`, `CODEC_UNSUPPORTED`,
 * `RESOLUTION_UNSUPPORTED`, `ENCODER_FAILED`, `MUXER_FAILED`, `GL_FAILED`,
 * `OUT_OF_MEMORY`, `OUT_OF_STORAGE`, `CANCELLED`, `PERMISSION_DENIED`,
 * `AUDIO_UNREADABLE`) and whose `message` is a human-usable detail string. The
 * Dart layer maps those to localized copy and never shows a raw stack trace.
 *
 * Progress is pushed on `motionshot/render/progress` as JSON:
 *   { sessionId, stage, progress, framesDone, framesTotal, elapsedMs, etaMs }
 * and terminates with a `done` event carrying the result object.
 */
class NativeBridge(
    private val context: Context,
    private val activity: Activity?,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "motionshot/render"
        const val EVENT_CHANNEL = "motionshot/render/progress"
        const val MEDIA_CHANNEL = "motionshot/media"
        private const val TAG = "NativeBridge"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var events: EventChannel.EventSink? = null

    /** Pending audio-pick callback, resolved by the activity's result handler. */
    private var audioCallback: ((AudioPicker.Outcome) -> Unit)? = null

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    private fun runOnMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            mainHandler.post(block)
        }
    }

    /** Called by [ExportService] to push a progress event to Dart on @UiThread. */
    fun emit(payload: Map<String, Any?>) {
        val encoded = try {
            JSONObject(payload).toString()
        } catch (e: Exception) {
            Log.e(TAG, "emit serialise failed: ${e.message}")
            return
        }
        runOnMain {
            try {
                events?.success(encoded)
            } catch (e: Exception) {
                Log.e(TAG, "emit failed: ${e.message}")
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getCapabilities" -> {
                    val caps = DeviceCapabilities.detect(context)
                    result.success(caps.toJson().toString())
                }
                "probeRequest" -> {
                    val raw = call.arguments as? String
                        ?: return result.error("BAD_ARGUMENT", "probeRequest needs JSON", null)
                    val req = try {
                        ExportRequest.fromJson(raw)
                    } catch (e: Exception) {
                        return result.error("UNSUPPORTED_FORMAT", e.message, null)
                    }
                    val caps = DeviceCapabilities.detect(context)
                    val supported = caps.canEncode(req.width, req.height, req.fps)
                    val json = JSONObject().apply {
                        put("supported", supported)
                        put("note", caps.note)
                        put("actualWidth", minOf(req.width, caps.maxWidth))
                        put("actualHeight", minOf(req.height, caps.maxHeight))
                        put("maxBitrate", caps.maxBitrate)
                    }
                    result.success(json.toString())
                }
                "startExport" -> {
                    val raw = call.arguments as? String
                        ?: return result.error("BAD_ARGUMENT", "startExport needs JSON", null)
                    val req = try {
                        ExportRequest.fromJson(raw)
                    } catch (e: Exception) {
                        return result.error("UNSUPPORTED_FORMAT", e.message, null)
                    }
                    try {
                        req.validate()
                    } catch (e: Exception) {
                        return result.error("UNSUPPORTED_FORMAT", e.message, null)
                    }
                    val sessionId = "s${System.currentTimeMillis()}"
                    val intent = ExportService.newIntent(context, sessionId, raw)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                    result.success(sessionId)
                }
                "cancelExport" -> {
                    val sessionId = call.argument<String>("sessionId")
                    if (sessionId == null) {
                        result.error("BAD_ARGUMENT", "missing sessionId", null)
                        return
                    }
                    ExportService.requestCancel(sessionId)
                    result.success(true)
                }
                "isExportRunning" -> {
                    val sessionId = call.argument<String>("sessionId")
                    result.success(sessionId != null && ExportService.isRunning(sessionId))
                }
                "probeFile" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("BAD_ARGUMENT", "missing path", null)
                        return
                    }
                    val probe = MediaProbe.probe(context, path)
                    if (probe == null) {
                        result.error("ENCODER_FAILED", "not a readable video: $path", null)
                    } else {
                        result.success(probe.toJson().toString())
                    }
                }
                "saveToGallery" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("BAD_ARGUMENT", "missing path", null)
                        return
                    }
                    val file = File(path)
                    val name = "MotionShot_${System.currentTimeMillis()}.mp4"
                    val uri = StorageManager.saveVideoToGallery(context, file, name)
                    result.success(uri?.toString())
                }
                "shareFile" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("BAD_ARGUMENT", "missing path", null)
                        return
                    }
                    val ok = StorageManager.shareVideo(context, File(path))
                    if (ok) {
                        result.success(null)
                    } else {
                        result.error("INTERNAL", "no app accepted the share intent", null)
                    }
                }
                "getCrashLog" -> {
                    result.success(CrashLog.read())
                }
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.message, null)
        } catch (e: OutOfMemoryError) {
            result.error("OUT_OF_MEMORY", "out of memory", null)
        } catch (e: Exception) {
            Log.e(TAG, "unhandled bridge error", e)
            result.error("INTERNAL", "${e.javaClass.simpleName}: ${e.message}", null)
        }
    }

    /** Opens the system audio picker and delivers an [AudioPicker.Outcome]. */
    fun pickAudio(callback: (AudioPicker.Outcome) -> Unit) {
        val act = activity ?: run {
            callback(AudioPicker.Outcome.Cancelled)
            return
        }
        audioCallback = callback
        if (!AudioPicker.open(act)) {
            audioCallback = null
            callback(AudioPicker.Outcome.Failed("AUDIO_UNREADABLE", "no document picker installed"))
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        val outcome = AudioPicker.handleResult(requestCode, resultCode, data) ?: return false
        val cb = audioCallback
        audioCallback = null
        cb?.invoke(outcome)
        return true
    }

    /** Delivers an ExportWorker outcome to the Dart side as one ordered event. */
    /** The single terminal event for a session. */
    fun emitDone(
        sessionId: String,
        result: ExportWorker.ExportResult?,
        failure: Pair<String, String>?,
        cancelled: Boolean,
        elapsedMs: Long,
    ) {
        val payload = JSONObject().apply {
            put("sessionId", sessionId)
            put("stage", "done")
            put("progress", if (result != null) 1.0 else 0.0)
            put("framesDone", result?.frameCount ?: 0)
            put("framesTotal", result?.frameCount ?: 0)
            put("elapsedMs", elapsedMs)
            when {
                cancelled -> {
                    put("cancelled", true)
                    put("errorCode", "CANCELLED")
                    put("errorMessage", "export cancelled")
                }
                failure != null -> {
                    put("errorCode", failure.first)
                    put("errorMessage", failure.second)
                }
                result != null -> {
                    put(
                        "result",
                        JSONObject().apply {
                            put("path", result.path)
                            put("width", result.width)
                            put("height", result.height)
                            put("fps", result.fps)
                            put("durationMs", result.durationMs)
                            put("frameCount", result.frameCount)
                            put("bitrate", result.bitrate)
                    put("codec", result.codec)
                    put("sizeBytes", result.sizeBytes)
                    put("hasAudio", result.hasAudio)
                    put("galleryUri", result.galleryUri)
                    put("texturesCreated", result.texturesCreated)
                    put("texturesEvicted", result.texturesEvicted)
                        },
                    )
                }
            }
        }
        val encoded = payload.toString()
        runOnMain {
            events?.success(encoded)
        }
    }
}
