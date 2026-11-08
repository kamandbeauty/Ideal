package app.subflow.asr

import android.content.Context
import android.content.res.AssetManager
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import app.subflow.core.NativeCore
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
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
    private val builtinLock = Any()
    private val cancelled = AtomicBoolean(false)
    private val ioLock = Any()

    fun modelsDir(): File = File(context.filesDir, MODELS_SUBDIR).apply { mkdirs() }


    /**
     * Models the app can fetch for the user.
     *
     * whisper.cpp models live on Hugging Face and are far too large to bundle in
     * an APK, so they are downloaded once, on demand, over HTTPS - and only when
     * the user taps a button. Two mirrors are tried because one of them is
     * routinely unreachable on some networks; the file is verified (ggml magic +
     * a real load through whisper) before it is kept.
     */
    fun catalog(): List<Map<String, Any?>> = CATALOG.map { entry ->
        mapOf(
            "id" to entry.id,
            "label" to entry.label,
            "detail" to entry.detail,
            "approxBytes" to entry.approxBytes,
            "installed" to (File(modelsDir(), entry.fileName).isFile),
        )
    }

    fun downloadModel(id: String): Map<String, Any?> {
        val entry = CATALOG.firstOrNull { it.id == id }
            ?: throw IllegalArgumentException("مدل ناشناخته: $id")
        cancelled.set(false)
        val target = File(modelsDir(), entry.fileName)
        if (target.isFile) return modelMap(target)

        var lastError: String? = null
        for (url in entry.urls) {
            if (cancelled.get()) throw IllegalStateException("دریافت مدل لغو شد.")
            val temp = File(modelsDir(), "${entry.id}.part")
            try {
                downloadTo(url, temp, entry)
                verifyDownloaded(temp)
                if (target.exists()) target.delete()
                if (!temp.renameTo(target)) throw IOException("ذخیرهٔ فایل مدل ناموفق بود.")
                emit(mapOf("event" to "download", "id" to entry.id, "received" to target.length(), "total" to target.length()))
                Log.i(TAG, "model downloaded: ${target.name} (${target.length()} bytes)")
                return modelMap(target)
            } catch (error: Exception) {
                lastError = error.message
                Log.w(TAG, "download failed from $url", error)
                temp.delete()
                if (cancelled.get()) throw IllegalStateException("دریافت مدل لغو شد.")
            }
        }
        throw IllegalStateException(
            lastError ?: "دریافت مدل از اینترنت ناموفق بود. اتصال را بررسی کنید یا فایل مدل را دستی اضافه کنید."
        )
    }

    private fun modelMap(file: File): Map<String, Any?> = mapOf(
        "id" to file.name.removeSuffix(".bin"),
        "label" to file.name.removeSuffix(".bin"),
        "path" to file.absolutePath,
        "sizeBytes" to file.length(),
    )

    private fun downloadTo(url: String, temp: File, entry: CatalogEntry) {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 20_000
            readTimeout = 60_000
            instanceFollowRedirects = true
            requestMethod = "GET"
            setRequestProperty("User-Agent", "SubFlow-Android")
            setRequestProperty("Accept", "*/*")
        }
        try {
            val status = connection.responseCode
            if (status !in 200..299 && status != HttpURLConnection.HTTP_PARTIAL) {
                throw IOException("پاسخ نامعتبر از سرور: $status")
            }
            val total = connection.contentLengthLong
            val input: InputStream = connection.inputStream
            FileOutputStream(temp).use { output ->
                val buffer = ByteArray(256 * 1024)
                var received = 0L
                var lastEmit = 0L
                while (true) {
                    if (cancelled.get()) throw IllegalStateException("دریافت مدل لغو شد.")
                    val read = input.read(buffer)
                    if (read <= 0) break
                    output.write(buffer, 0, read)
                    received += read
                    if (received - lastEmit >= 1024 * 1024) {
                        lastEmit = received
                        emit(
                            mapOf(
                                "event" to "download",
                                "id" to entry.id,
                                "received" to received,
                                "total" to if (total > 0) total else entry.approxBytes,
                            )
                        )
                    }
                }
            }
            input.close()
            if (temp.length() < 1024 * 1024) throw IOException("فایل دریافتی ناقص است.")
        } finally {
            connection.disconnect()
        }
    }

    /** A ggml model must start with its magic and must actually load. */
    /** A ggml file starts with the four bytes of its magic; anything else is not a model. */
    private fun verifyMagic(file: File) {
        val magic = ByteArray(4)
        file.inputStream().use { stream ->
            if (stream.read(magic) != 4) throw IOException("فایل مدل خالی است.")
        }
        if (!isGgmlMagic(magic)) {
            throw IOException("این فایل مدل Whisper نیست.")
        }
    }

    /**
     * Real ggml files do **not** start with the text "ggml": the magic is the
     * uint32 0x67676d6c written little-endian, so the bytes on disk read "lmgg".
     * Accepting only the string rejected every genuine whisper.cpp model - the
     * download finished and verification then called it "not a Whisper model".
     * Both orders (and the older container magics) are accepted here.
     */
    private fun isGgmlMagic(magic: ByteArray): Boolean {
        if (magic.size < 4) return false
        val text = String(magic, 0, 4, Charsets.ISO_8859_1)
        return text in GGML_MAGICS
    }

    private fun verifyDownloaded(file: File) {
        verifyMagic(file)
        if (!NativeCore.isReady || !NativeCore.nativeAsrAvailable()) return
        val result = NativeCore.nativeAsrLoadModel(file.absolutePath)
        if (!result.contains("\"ok\":true")) {
            throw IOException("مدل دریافتی بارگذاری نشد؛ فایل را دوباره دریافت کنید.")
        }
        NativeCore.nativeAsrUnload()
    }

    fun capabilities(): Map<String, Any?> = mapOf(
        "available" to (NativeCore.isReady && NativeCore.nativeAsrAvailable()),
        "engineReady" to (NativeCore.isReady && NativeCore.nativeAsrReady()),
        "cores" to Runtime.getRuntime().availableProcessors(),
        "recommendedThreads" to recommendedThreads(),
        "modelsDir" to modelsDir().absolutePath,
        "nativeError" to (NativeCore.loadError ?: ""),
    )

    fun listModels(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        // The model that ships inside the APK comes first: on a fresh install it is
        // the one that is already there, and nothing has to be downloaded.
        val builtin = ensureBuiltIn()
        if (builtin != null) {
            out.add(
                mapOf(
                    "id" to BUILTIN_ID,
                    "label" to BUILTIN_LABEL,
                    "path" to builtin.absolutePath,
                    "sizeBytes" to builtin.length(),
                    "builtin" to true,
                )
            )
        }
        val files = modelsDir().listFiles { file -> file.isFile && file.name.endsWith(".bin") }
        files?.sortedBy { it.name }?.forEach { file ->
            if (builtin != null && file.name == builtin.name) return@forEach
            out.add(
                mapOf(
                    "id" to file.name.removeSuffix(".bin"),
                    "label" to file.name.removeSuffix(".bin"),
                    "path" to file.absolutePath,
                    "sizeBytes" to file.length(),
                    "builtin" to false,
                )
            )
        }
        return out
    }

    /**
     * Copies the bundled model out of the APK on first use, because whisper.cpp
     * needs a real file path and an asset stream is not one.
     *
     * Returns the file, or null when this build was made without the asset (the
     * downloadable catalogue still covers that case).
     */
    private fun ensureBuiltIn(): File? {
        val target = File(modelsDir(), BUILTIN_FILE)
        if (target.isFile && target.length() >= MIN_MODEL_BYTES) return target
        synchronized(builtinLock) {
            if (target.isFile && target.length() >= MIN_MODEL_BYTES) return target
            val declared = try {
                context.assets.openFd(BUILTIN_ASSET).use { it.length }
            } catch (error: IOException) {
                return null
            }
            val temp = File(modelsDir(), "$BUILTIN_FILE.part")
            temp.delete()
            try {
                context.assets.open(BUILTIN_ASSET, AssetManager.ACCESS_STREAMING).use { input ->
                    FileOutputStream(temp).use { output ->
                        val buffer = ByteArray(256 * 1024)
                        var copied = 0L
                        var lastEmit = 0L
                        while (true) {
                            val read = input.read(buffer)
                            if (read <= 0) break
                            output.write(buffer, 0, read)
                            copied += read
                            if (copied - lastEmit >= 4 * 1024 * 1024) {
                                lastEmit = copied
                                emit(
                                    mapOf(
                                        "event" to "extract",
                                        "id" to BUILTIN_ID,
                                        "received" to copied,
                                        "total" to declared,
                                    )
                                )
                            }
                        }
                    }
                }
                if (temp.length() < MIN_MODEL_BYTES) throw IOException("مدل همراه برنامه ناقص است.")
                verifyMagic(temp)
                if (target.exists()) target.delete()
                if (!temp.renameTo(target)) throw IOException("آماده‌سازی مدل همراه برنامه ناموفق بود.")
                Log.i(TAG, "bundled model extracted: ${target.length()} bytes")
                return target
            } catch (error: Exception) {
                Log.w(TAG, "bundled model unavailable", error)
                temp.delete()
                return null
            }
        }
    }

    fun deleteModel(path: String): Boolean {
        val file = File(path)
        val insideModels = file.canonicalPath.startsWith(modelsDir().canonicalPath + File.separator)
        if (!insideModels) return false
        // The bundled model is part of the app: deleting it would only make the
        // next call copy it back.
        if (file.name == BUILTIN_FILE) return false
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
                if (!isGgmlMagic(magic)) {
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

    /**
     * Runs every stage once and reports what happened.
     *
     * The point is diagnosability: "it doesn't work" is not actionable, but
     * "model loaded in 820 ms / decode 12.4 s of audio at peak 0.03 / whisper
     * returned 0 segments in 41 s" says exactly which stage broke.
     */
    fun selfTest(uri: Uri?, modelPath: String?, language: String, durationUs: Long): Map<String, Any?> {
        val report = LinkedHashMap<String, Any?>()
        report["nativeLib"] = NativeCore.isReady
        report["nativeError"] = NativeCore.loadError ?: ""
        if (!NativeCore.isReady) return report

        report["whisperCompiled"] = NativeCore.nativeAsrAvailable()
        report["abi"] = android.os.Build.SUPPORTED_ABIS.firstOrNull() ?: "?"
        report["sdkInt"] = android.os.Build.VERSION.SDK_INT
        report["cores"] = Runtime.getRuntime().availableProcessors()
        report["threads"] = recommendedThreads()
        if (!NativeCore.nativeAsrAvailable()) return report

        val path = modelPath ?: (listModels().firstOrNull()?.get("path") as? String)
        report["modelPath"] = path ?: "(none)"
        if (path == null) {
            report["modelError"] = "هیچ مدلی نصب نشده است."
            return report
        }
        val model = File(path)
        report["modelExists"] = model.isFile
        report["modelBytes"] = if (model.isFile) model.length() else 0L
        if (!model.isFile) {
            report["modelError"] = "فایل مدل پیدا نشد."
            return report
        }

        val loadStart = System.currentTimeMillis()
        val load = NativeCore.nativeAsrLoadModel(model.absolutePath)
        report["modelLoadMs"] = System.currentTimeMillis() - loadStart
        report["modelLoad"] = isOk(load)
        if (!isOk(load)) {
            report["modelError"] = load
            return report
        }

        if (uri == null) {
            report["audio"] = "skipped (no video)"
            return report
        }

        val decodeStart = System.currentTimeMillis()
        val pcm = try {
            WhisperAudio.decode(
                context = context,
                uri = uri,
                durationUs = durationUs,
                onProgress = {},
                isCancelled = { false },
                maxSeconds = 20.0,
            )
        } catch (error: Exception) {
            report["decodeError"] = error.message ?: error.javaClass.simpleName
            return report
        }
        report["decodeMs"] = System.currentTimeMillis() - decodeStart
        report["samples"] = pcm.size
        report["audioSeconds"] = pcm.size / 16000.0
        report["peak"] = WhisperAudio.peak(pcm)
        if (pcm.isEmpty()) {
            report["decodeError"] = "صدایی دیکد نشد."
            return report
        }

        val transcribeStart = System.currentTimeMillis()
        val json = NativeCore.nativeAsrTranscribe(pcm, language, recommendedThreads(), false)
        report["transcribeMs"] = System.currentTimeMillis() - transcribeStart
        report["transcribeOk"] = isOk(json)
        report["transcribe"] = json?.take(400) ?: ""
        Log.i(TAG, "self test: $report")
        return report
    }

    fun cancel() {
        cancelled.set(true)
        if (NativeCore.isReady) NativeCore.nativeAsrCancel()
    }

    /**
     * Decodes the video's audio, transcribes it and returns the native JSON:
     * `{"ok":true,"segments":[[startUs,endUs,"text"],…]}` or `{"ok":false,…}`.
     */
    fun transcribe(
        uri: Uri,
        modelPath: String,
        language: String,
        durationUs: Long,
        translate: Boolean = false,
    ): String {
        synchronized(lock) {
            cancelled.set(false)
            if (!NativeCore.isReady) return errorJson("هستهٔ بومی اجرا نشد؛ این نسخه روی این دستگاه کار نمی‌کند.")
            if (!NativeCore.nativeAsrAvailable()) {
                return errorJson("این نسخه بدون موتور Whisper ساخته شده است.")
            }
            // No path means "use what is in the box": the bundled model, already
            // extracted on first launch.
            val resolved = if (modelPath.isBlank()) ensureBuiltIn()?.absolutePath else modelPath
            if (resolved == null) return errorJson("مدلی برای تشخیص گفتار پیدا نشد.")
            val model = File(resolved)
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
            // Silence would burn minutes of CPU and then report "nothing found",
            // which sounds like a broken engine. Say what is actually wrong.
            if (WhisperAudio.peak(pcm) < 0.0015f) {
                return errorJson("صدای این ویدئو تقریباً بی‌صداست؛ زیرنویسی برای ساختن پیدا نشد.")
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
                NativeCore.nativeAsrTranscribe(pcm, language, recommendedThreads(), translate)
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

    private data class CatalogEntry(
        val id: String,
        val label: String,
        val detail: String,
        val approxBytes: Long,
        val fileName: String,
        val source: String,
    ) {
        val urls: List<String>
            get() = listOf(
                "https://huggingface.co/$source/resolve/main/$fileName",
                "https://hf-mirror.com/$source/resolve/main/$fileName",
            )
    }

    companion object {
        private const val TAG = "SubFlowWhisper"
        private const val MODELS_SUBDIR = "models/whisper"

        // Shipped inside the APK by tools/fetch-bundled-model.sh + CI. base q5_1 is
        // the smallest model that transcribes Persian well; the weights are not in
        // the git repository, only in the built APK.
        const val BUILTIN_ASSET = "models/ggml-base-q5_1.bin"
        const val BUILTIN_FILE = "ggml-base-q5_1.bin"
        const val BUILTIN_ID = "builtin-base-q5_1"
        private const val BUILTIN_LABEL = "مدل همراه برنامه (base، فارسی)"
        private const val MIN_MODEL_BYTES = 20L * 1024 * 1024

        // "ggml" (big-endian writer) and its little-endian twin "lmgg", plus the
        // older ggml container magics that whisper.cpp models in the wild still use.
        private val GGML_MAGICS = setOf("ggml", "lmgg", "ggmf", "fmgg", "ggjt", "tjgg", "gguf", "fugg")
        private const val REPO = "ggerganov/whisper.cpp"

        // Three sizes, all quantised so a phone download stays reasonable. base
        // is the recommendation for Persian: tiny mis-hears it far too often.
        private val CATALOG = listOf(
            CatalogEntry(
                id = "ggml-tiny-q5_1",
                label = "کوچک و سریع (tiny)",
                detail = "۳۲ مگابایت • برای تست سریع و ویدئوهای کوتاه",
                approxBytes = 32_000_000L,
                fileName = "ggml-tiny-q5_1.bin",
                source = REPO,
            ),
            CatalogEntry(
                id = "ggml-base-q5_1",
                label = "پیشنهادی برای فارسی (base)",
                detail = "۵۷ مگابایت • تعادل خوب دقت و سرعت",
                approxBytes = 60_000_000L,
                fileName = "ggml-base-q5_1.bin",
                source = REPO,
            ),
            CatalogEntry(
                id = "ggml-small-q5_1",
                label = "دقیق‌تر (small)",
                detail = "۱۹۰ مگابایت • کندتر، برای ویدئوی مهم",
                approxBytes = 190_000_000L,
                fileName = "ggml-small-q5_1.bin",
                source = REPO,
            ),
        )
    }
}
