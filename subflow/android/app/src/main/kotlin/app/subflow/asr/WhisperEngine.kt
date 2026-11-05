package app.subflow.asr

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import app.subflow.core.NativeCore
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Owns the on-device Whisper models and runs one transcription at a time.
 *
 * Models are user-supplied ggml files (`ggml-base.bin`, `ggml-small-q5_1.bin`,
 * ...): they are hundreds of megabytes, so the app never downloads or bundles
 * them. Import copies the chosen document into app-private storage, verifies the
 * ggml magic number, and remembers size/sha256 so a truncated copy is detectable
 * instead of producing "the model produced garbage".
 */
class WhisperEngine(
    private val context: Context,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val lock = Any()
    private val cancelled = AtomicBoolean(false)
    private val ioLock = Any()

    fun modelsDir(): File = File(context.filesDir, MODELS_SUBDIR).apply { mkdirs() }

    fun capabilities(): Map<String, Any?> = mapOf(
        "available" to (NativeCore.isReady && NativeCore.nativeAsrAvailable()),
        "engineReady" to (NativeCore.isReady && NativeCore.nativeAsrReady()),
        "cores" to Runtime.getRuntime().availableProcessors(),
        "recommendedThreads" to recommendedThreads(),
        "modelsDir" to modelsDir().absolutePath,
    )

    fun listModels(): List<Map<String, Any?>> {
        val files = modelsDir().listFiles { file -> file.isFile && file.name.endsWith(".bin") }
            ?: return emptyList()
        return files.sortedBy { it.name }.map { file ->
            mapOf(
                "id" to file.name.removeSuffix(".bin"),
                "label" to file.name.removeSuffix(".bin"),
                "path" to file.absolutePath,
                "sizeBytes" to file.length(),
            )
        }
    }

    fun deleteModel(path: String): Boolean {
        val file = File(path)
        val insideModels = file.canonicalPath.startsWith(modelsDir().canonicalPath + File.separator)
        if (!insideModels) return false
        return file.delete()
    }

    /** Copies a picked document into [modelsDir]; throws with a user-facing message. */
    fun importModel(uri: Uri): Map<String, Any?> {
        val displayName = queryDisplayName(uri)
        val baseName = displayName
            .removeSuffix(".bin")
            .replace(Regex("[^A-Za-z0-9._-]"), "-")
            .ifBlank { "whisper-model" }
        val target = File(modelsDir(), "$baseName.bin")
        val temp = File(modelsDir(), "$baseName.part")

        val digest = MessageDigest.getInstance("SHA-256")
        var total = 0L
        context.contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(temp).use { output ->
                val buffer = ByteArray(1 shl 20)
                var magic = ByteArray(0)
                while (true) {
                    val read = input.read(buffer)
                    if (read <= 0) break
                    if (magic.size < 4) {
                        magic += buffer.copyOf(minOf(read, 4 - magic.size))
                    }
                    output.write(buffer, 0, read)
                    digest.update(buffer, 0, read)
                    total += read
                }
                if (magic.size < 4 || String(magic) != "ggml") {
                    temp.delete()
                    throw IllegalStateException(
                        "این فایل مدل Whisper نیست. فایل ggml با پسوند .bin انتخاب کنید."
                    )
                }
            }
        } ?: throw IllegalStateException("فایل انتخاب‌شده باز نشد.")

        if (target.exists()) target.delete()
        if (!temp.renameTo(target)) {
            temp.delete()
            throw IllegalStateException("ذخیرهٔ مدل در حافظهٔ برنامه ناموفق بود.")
        }
        val sha = digest.digest().joinToString("") { byte -> "%02x".format(byte) }
        Log.i(TAG, "model imported: ${target.name} (${target.length()} bytes)")
        return mapOf(
            "id" to target.name.removeSuffix(".bin"),
            "label" to target.name.removeSuffix(".bin"),
            "path" to target.absolutePath,
            "sizeBytes" to target.length(),
            "sha256" to sha,
            "bytes" to total,
        )
    }

    fun cancel() {
        cancelled.set(true)
        if (NativeCore.isReady) NativeCore.nativeAsrCancel()
    }

    /**
     * Decodes the video's audio, transcribes it and returns the native JSON:
     * `{"ok":true,"segments":[[startUs,endUs,"text"],…]}` or `{"ok":false,…}`.
     */
    fun transcribe(uri: Uri, modelPath: String, language: String, durationUs: Long): String {
        synchronized(lock) {
            cancelled.set(false)
            if (!NativeCore.isReady) return errorJson("هستهٔ بومی اجرا نشد؛ این نسخه روی این دستگاه کار نمی‌کند.")
            if (!NativeCore.nativeAsrAvailable()) {
                return errorJson("این نسخه بدون موتور Whisper ساخته شده است.")
            }
            val model = File(modelPath)
            if (!model.isFile) return errorJson("فایل مدل پیدا نشد. مدل را دوباره اضافه کنید.")

            val load = NativeCore.nativeAsrLoadModel(model.absolutePath)
            if (!isOk(load)) return load

            val pcm = try {
                WhisperAudio.decode(
                    context = context,
                    uri = uri,
                    durationUs = durationUs,
                    onProgress = { value -> emitProgress(value) },
                    isCancelled = { cancelled.get() },
                )
            } catch (error: Exception) {
                Log.e(TAG, "audio decode failed", error)
                return errorJson(error.message ?: "خواندن صدای ویدئو ناموفق بود.")
            }
            if (cancelled.get() || pcm.isEmpty()) {
                return errorJson("تشخیص گفتار لغو شد.")
            }

            val stopPolling = AtomicBoolean(false)
            val poller = Thread {
                while (!stopPolling.get()) {
                    val progress = NativeCore.nativeAsrProgress()
                    emitProgress(30 + (progress.coerceIn(0, 100) * 69 / 100))
                    try {
                        Thread.sleep(200)
                    } catch (interrupted: InterruptedException) {
                        Thread.currentThread().interrupt()
                        break
                    }
                }
            }
            poller.isDaemon = true
            poller.start()

            val json = try {
                NativeCore.nativeAsrTranscribe(pcm, language, recommendedThreads())
            } finally {
                stopPolling.set(true)
                poller.interrupt()
            }
            if (isOk(json)) emitProgress(100)
            return json
        }
    }

    private fun recommendedThreads(): Int {
        val cores = Runtime.getRuntime().availableProcessors()
        // Whisper scales sub-linearly past four threads on phones and small
        // models get slower when everything contends for the big cluster.
        return cores.coerceIn(2, 4)
    }

    private fun emitProgress(value: Int) {
        emit(mapOf("event" to "progress", "value" to value.coerceIn(0, 100)))
    }

    private fun queryDisplayName(uri: Uri): String {
        try {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index >= 0 && !cursor.isNull(index)) return cursor.getString(index)
                    }
                }
        } catch (error: Exception) {
            Log.w(TAG, "could not read display name", error)
        }
        return uri.lastPathSegment ?: "whisper-model.bin"
    }

    private fun isOk(json: String?): Boolean = json != null && json.contains("\"ok\":true")

    private fun errorJson(message: String): String =
        "{\"ok\":false,\"error\":\"${message.replace("\\", "\\\\").replace("\"", "\\\"")}\"}"

    companion object {
        private const val TAG = "SubFlowWhisper"
        private const val MODELS_SUBDIR = "models/whisper"
    }
}
