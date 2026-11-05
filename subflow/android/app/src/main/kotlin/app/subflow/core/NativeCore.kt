package app.subflow.core

import android.util.Log

/**
 * JNI facade for libsubflow_core.so (C++ core in `app/src/main/cpp`).
 *
 * The library is loaded lazily and defensively: if the ABI is missing, the app
 * still runs and features that need the core fail with a clear message instead
 * of crashing on startup.
 */
object NativeCore {
    private const val TAG = "SubFlowNative"

    val loadError: String? by lazy {
        try {
            System.loadLibrary("subflow_core")
            null
        } catch (error: UnsatisfiedLinkError) {
            Log.e(TAG, "libsubflow_core.so could not be loaded", error)
            error.message
        }
    }

    val isReady: Boolean get() = loadError == null

    // ---------------------------------------------------------------- whisper
    // The engine is compiled in only when third_party/whisper.cpp is present
    // (CMake option SF_ENABLE_WHISPER). `nativeAsrAvailable` is the honest
    // answer to "can this APK transcribe?", and the UI asks it before offering
    // the feature.
    external fun nativeAsrAvailable(): Boolean

    external fun nativeAsrLoadModel(modelPath: String): String

    external fun nativeAsrUnload()

    external fun nativeAsrReady(): Boolean

    external fun nativeAsrCancel()

    external fun nativeAsrProgress(): Int

    external fun nativeAsrTranscribe(pcm: FloatArray, language: String, threads: Int): String

    external fun nativeWriteSrt(starts: LongArray, ends: LongArray, texts: Array<String>): String

    external fun nativeWriteAss(
        starts: LongArray,
        ends: LongArray,
        texts: Array<String>,
        styles: Array<String>,
        fontName: String,
        fontSize: Double,
        primaryRgb: Int,
        outlineRgb: Int,
        bold: Boolean,
        outlineWidth: Double,
        shadowDepth: Double,
        alignment: Int,
        playResX: Int,
        playResY: Int
    ): String

    external fun nativeDetectSilence(
        pcm: FloatArray,
        sampleRate: Int,
        thresholdDbfs: Double,
        minSilenceUs: Long,
        minSpeechUs: Long,
        padUs: Long
    ): LongArray

    @Suppress("LongParameterList")
    external fun nativePlanExport(
        srcWidth: Int,
        srcHeight: Int,
        srcFps: Double,
        srcBitrate: Long,
        hdr: Boolean,
        audioSampleRate: Int,
        audioChannels: Int,
        audioBitrate: Long,
        durationUs: Long,
        presetHeight: Int,
        customFps: Double,
        customBitrate: Long,
        burnIn: Boolean,
        allowUpscale: Boolean,
        preferHevc: Boolean,
        hevcSupported: Boolean,
        hardware: Boolean,
        keepSourceAudio: Boolean,
        quality: Double
    ): String
}
