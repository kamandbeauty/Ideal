package app.subflow.bridge

import android.app.Activity
import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.net.Uri
import android.os.Build
import android.util.Log
import app.subflow.core.NativeCore
import app.subflow.media.MediaPicker
import app.subflow.media.VideoProbe
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * The single native entry point for the app.
 *
 * Every expensive operation (probing, codec lookup, native codecs) runs off the
 * main thread - the UI isolate never blocks on file IO (product non-negotiable
 * #1/#5 in the brief: no heavy work on the main thread).
 */
class SubFlowBridge(
    private val activity: Activity,
    private val picker: MediaPicker,
) : MethodChannel.MethodCallHandler {

    private val io = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "subflow-bridge-io").apply { isDaemon = true }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            BridgeContract.METHOD_PICK_VIDEO -> handlePickVideo(result)
            BridgeContract.METHOD_PROBE_VIDEO -> handleProbe(call, result)
            BridgeContract.METHOD_FILE_EXISTS -> handleFileExists(call, result)
            BridgeContract.METHOD_CAPABILITIES -> handleCapabilities(result)
            BridgeContract.METHOD_WRITE_SRT -> handleWriteSrt(call, result)
            BridgeContract.METHOD_WRITE_ASS -> handleWriteAss(call, result)
            BridgeContract.METHOD_PLAN_EXPORT -> handlePlanExport(call, result)
            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------------ media
    private fun handlePickVideo(result: MethodChannel.Result) {
        activity.runOnUiThread {
            picker.pickVideo { outcome ->
                outcome.fold(
                    onSuccess = { uri ->
                        if (uri == null) {
                            result.success(null)
                            return@fold
                        }
                        io.execute {
                            val map = HashMap<String, Any?>()
                            map["uri"] = uri.toString()
                            map["displayName"] = queryDisplayName(uri)
                            map["sizeBytes"] = querySize(uri)
                            activity.runOnUiThread { result.success(map) }
                        }
                    },
                    onFailure = { error ->
                        result.error("picker_failed", error.message, null)
                    }
                )
            }
        }
    }

    private fun handleProbe(call: MethodCall, result: MethodChannel.Result) {
        val uriString: String? = call.argument<String>("uri")
        if (uriString.isNullOrEmpty()) {
            result.error("bad_args", "uri is required", null)
            return
        }
        io.execute {
            try {
                val map = VideoProbe.probe(activity, Uri.parse(uriString))
                activity.runOnUiThread { result.success(map) }
            } catch (error: Exception) {
                Log.e(TAG, "probe failed", error)
                activity.runOnUiThread {
                    result.error("probe_failed", error.message ?: "probe failed", null)
                }
            }
        }
    }

    private fun handleFileExists(call: MethodCall, result: MethodChannel.Result) {
        val uriString: String? = call.argument<String>("uri")
        if (uriString.isNullOrEmpty()) {
            result.success(false)
            return
        }
        io.execute {
            val exists = VideoProbe.exists(activity, uriString)
            activity.runOnUiThread { result.success(exists) }
        }
    }

    // ----------------------------------------------------------- capabilities
    private fun handleCapabilities(result: MethodChannel.Result) {
        io.execute {
            val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
            val map = HashMap<String, Any?>()
            map["sdkInt"] = Build.VERSION.SDK_INT
            map["abi"] = abi
            map["hardwareH264"] = hasHardwareDecoder(MediaCodecMime.H264)
            map["hardwareHevc"] = hasHardwareDecoder(MediaCodecMime.HEVC)
            map["nativeCoreReady"] = NativeCore.isReady
            map["nativeCoreVersion"] = NativeCore.loadError ?: "1"
            activity.runOnUiThread { result.success(map) }
        }
    }

    // ------------------------------------------------------- native codecs
    private fun handleWriteSrt(call: MethodCall, result: MethodChannel.Result) {
        if (!NativeCore.isReady) {
            result.error("native_missing", NativeCore.loadError, null)
            return
        }
        val starts = call.argument<List<Long>>("starts")?.toLongArray()
        val ends = call.argument<List<Long>>("ends")?.toLongArray()
        val texts = call.argument<List<String>>("texts")?.toTypedArray()
        if (starts == null || ends == null || texts == null) {
            result.error("bad_args", "starts/ends/texts are required", null)
            return
        }
        io.execute {
            try {
                val srt = NativeCore.nativeWriteSrt(starts, ends, texts)
                activity.runOnUiThread { result.success(srt) }
            } catch (error: Exception) {
                Log.e(TAG, "writeSrt failed", error)
                activity.runOnUiThread {
                    result.error("srt_failed", error.message ?: "srt failed", null)
                }
            }
        }
    }

    private fun handleWriteAss(call: MethodCall, result: MethodChannel.Result) {
        if (!NativeCore.isReady) {
            result.error("native_missing", NativeCore.loadError, null)
            return
        }
        val starts = call.argument<List<Long>>("starts")?.toLongArray()
        val ends = call.argument<List<Long>>("ends")?.toLongArray()
        val texts = call.argument<List<String>>("texts")?.toTypedArray()
        val styles = call.argument<List<String>>("styles")?.toTypedArray() ?: arrayOf()
        if (starts == null || ends == null || texts == null) {
            result.error("bad_args", "starts/ends/texts are required", null)
            return
        }
        io.execute {
            try {
                val ass = NativeCore.nativeWriteAss(
                    starts,
                    ends,
                    texts,
                    styles,
                    call.argument<String>("fontName") ?: "Vazirmatn",
                    call.argument<Number>("fontSize")?.toDouble() ?: 64.0,
                    call.argument<Number>("primaryColor")?.toInt() ?: 0xFFFFFF,
                    call.argument<Number>("outlineColor")?.toInt() ?: 0x000000,
                    call.argument<Boolean>("bold") ?: true,
                    call.argument<Number>("outlineWidth")?.toDouble() ?: 3.0,
                    call.argument<Number>("shadowDepth")?.toDouble() ?: 1.5,
                    call.argument<Number>("alignment")?.toInt() ?: 2,
                    call.argument<Number>("playResX")?.toInt() ?: 1080,
                    call.argument<Number>("playResY")?.toInt() ?: 1920
                )
                activity.runOnUiThread { result.success(ass) }
            } catch (error: Exception) {
                Log.e(TAG, "writeAss failed", error)
                activity.runOnUiThread {
                    result.error("ass_failed", error.message ?: "ass failed", null)
                }
            }
        }
    }

    private fun handlePlanExport(call: MethodCall, result: MethodChannel.Result) {
        if (!NativeCore.isReady) {
            result.error("native_missing", NativeCore.loadError, null)
            return
        }
        io.execute {
            try {
                val json = NativeCore.nativePlanExport(
                    call.argument<Number>("srcWidth")?.toInt() ?: 0,
                    call.argument<Number>("srcHeight")?.toInt() ?: 0,
                    call.argument<Number>("srcFps")?.toDouble() ?: 0.0,
                    call.argument<Number>("srcBitrate")?.toLong() ?: 0L,
                    call.argument<Boolean>("hdr") ?: false,
                    call.argument<Number>("audioSampleRate")?.toInt() ?: 0,
                    call.argument<Number>("audioChannels")?.toInt() ?: 0,
                    call.argument<Number>("audioBitrate")?.toLong() ?: 0L,
                    call.argument<Number>("durationUs")?.toLong() ?: 0L,
                    call.argument<Number>("presetHeight")?.toInt() ?: 0,
                    call.argument<Number>("customFps")?.toDouble() ?: 0.0,
                    call.argument<Number>("customBitrate")?.toLong() ?: 0L,
                    call.argument<Boolean>("burnIn") ?: true,
                    call.argument<Boolean>("allowUpscale") ?: false,
                    call.argument<Boolean>("preferHevc") ?: false,
                    call.argument<Boolean>("hevcSupported") ?: false,
                    call.argument<Boolean>("hardware") ?: true,
                    call.argument<Boolean>("keepSourceAudio") ?: true,
                    call.argument<Number>("quality")?.toDouble() ?: 0.75
                )
                activity.runOnUiThread { result.success(json) }
            } catch (error: Exception) {
                Log.e(TAG, "planExport failed", error)
                activity.runOnUiThread {
                    result.error("plan_failed", error.message ?: "plan failed", null)
                }
            }
        }
    }

    // --------------------------------------------------------------- helpers
    private fun hasHardwareDecoder(mime: String): Boolean {
        return try {
            MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { info ->
                if (info.isEncoder) return@any false
                val supported = info.supportedTypes.any { it.equals(mime, ignoreCase = true) }
                supported && isHardwareAccelerated(info)
            }
        } catch (error: Exception) {
            Log.w(TAG, "codec lookup failed", error)
            false
        }
    }

    private fun isHardwareAccelerated(info: MediaCodecInfo): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return info.isHardwareAccelerated
        }
        val name = info.name.lowercase()
        return !(name.startsWith("omx.google.") || name.startsWith("c2.android."))
    }

    private fun queryDisplayName(uri: Uri): String {
        return try {
            activity.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (cursor.moveToFirst() && index >= 0) {
                    cursor.getString(index) ?: uri.lastPathSegment ?: "video"
                } else {
                    uri.lastPathSegment ?: "video"
                }
            } ?: (uri.lastPathSegment ?: "video")
        } catch (error: Exception) {
            uri.lastPathSegment ?: "video"
        }
    }

    private fun querySize(uri: Uri): Long {
        return try {
            activity.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(android.provider.OpenableColumns.SIZE)
                if (cursor.moveToFirst() && index >= 0 && !cursor.isNull(index)) {
                    cursor.getLong(index)
                } else {
                    0L
                }
            } ?: 0L
        } catch (error: Exception) {
            0L
        }
    }

    companion object {
        private const val TAG = "SubFlowBridge"
    }
}

/** Codec MIME strings kept out of call sites so a typo cannot pass silently. */
private object MediaCodecMime {
    const val H264 = "video/avc"
    const val HEVC = "video/hevc"
}
