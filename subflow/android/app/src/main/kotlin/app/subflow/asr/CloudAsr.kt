package app.subflow.asr

import android.content.Context
import android.net.Uri
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Optional cloud transcription through an OpenAI-compatible endpoint.
 *
 * The on-device engine stays the default and needs no account; this exists for
 * people who want the accuracy of a large hosted model (whisper-large-v3 on
 * Groq, whisper-1 / gpt-4o-transcribe on OpenAI) and are willing to upload the
 * audio for that. Nothing leaves the device unless the user picks this provider
 * and presses start, and the audio is a temporary WAV that is deleted in a
 * `finally` block - no copy is kept.
 *
 * The reply is normalised into exactly the same JSON shape the native engine
 * returns, so the editor cannot tell the two apart.
 */
object CloudAsr {

    data class Config(
        val baseUrl: String,
        val apiKey: String,
        val model: String,
        val language: String,
        val translate: Boolean = false,
    )

    private const val TAG = "SubFlowCloudAsr"
    private const val TIMEOUT_MS = 120_000
    private const val MAX_SECONDS = 19 * 60  // 32 KB/s of 16 kHz mono → under the 25 MB cap
    private const val SAMPLE_RATE = 16_000

    /** Sends the audio of [uri] to [config] and returns the engine's JSON shape. */
    fun transcribe(
        context: Context,
        uri: Uri,
        durationUs: Long,
        config: Config,
        onProgress: (Int) -> Unit,
        isCancelled: () -> Boolean,
    ): String {
        val base = config.baseUrl.trim().trimEnd('/')
        if (base.isEmpty()) return errorJson("آدرس سرویس آنلاین تنظیم نشده است.")
        if (config.apiKey.isBlank()) return errorJson("کلید API سرویس آنلاین تنظیم نشده است.")
        if (config.model.isBlank()) return errorJson("نام مدل سرویس آنلاین تنظیم نشده است.")
        if (durationUs > MAX_SECONDS * 1_000_000L) {
            val minutes = MAX_SECONDS / 60
            return errorJson(
                "این سرویس حداکثر $minutes دقیقه صدا را در یک درخواست می‌پذیرد و این " +
                    "ویدئو بلندتر است. ویدئوی کوتاه‌تری بسازید یا از حالت «روی گوشی» استفاده کنید.",
            )
        }

        onProgress(2)
        val pcm = try {
            WhisperAudio.decode(
                context = context,
                uri = uri,
                durationUs = durationUs,
                onProgress = { onProgress(2 + it / 8) },
                isCancelled = isCancelled,
                maxSeconds = MAX_SECONDS.toDouble(),
            )
        } catch (error: Exception) {
            Log.w(TAG, "decode failed", error)
            return errorJson(error.message ?: "خواندن صدای ویدئو ناموفق بود.")
        }
        if (isCancelled()) return errorJson("تشخیص گفتار لغو شد.")
        if (pcm.isEmpty()) return errorJson("صدایی در این ویدئو پیدا نشد.")
        if (WhisperAudio.peak(pcm) < 0.0015f) {
            return errorJson("صدای این ویدئو تقریباً بی‌صداست؛ زیرنویسی برای ساختن پیدا نشد.")
        }

        val wav = File(context.cacheDir, "cloud-asr-${System.currentTimeMillis()}.wav")
        try {
            writeWav(wav, pcm)
            onProgress(15)
            val body = request(base, config, wav, onProgress, isCancelled) ?: return errorJson(
                "درخواست لغو شد.",
            )
            onProgress(92)
            return parse(body, pcm.size * 1_000_000L / SAMPLE_RATE)
        } catch (error: IOException) {
            Log.w(TAG, "upload failed", error)
            return errorJson("ارتباط با سرویس آنلاین برقرار نشد: ${error.message ?: "شبکه در دسترس نیست"}")
        } catch (error: Exception) {
            Log.w(TAG, "cloud transcription failed", error)
            return errorJson(error.message ?: "سرویس آنلاین پاسخ درستی نداد.")
        } finally {
            wav.delete()
        }
    }

    /** Cheap credential check: asks the service for its model list. */
    fun check(baseUrl: String, apiKey: String): Map<String, Any?> {
        val base = baseUrl.trim().trimEnd('/')
        if (base.isEmpty()) return mapOf("ok" to false, "error" to "آدرس سرویس خالی است.")
        if (apiKey.isBlank()) return mapOf("ok" to false, "error" to "کلید API خالی است.")
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL("$base/models") as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 15_000
                readTimeout = 20_000
                setRequestProperty("Authorization", "Bearer $apiKey")
            }
            val code = connection.responseCode
            val text = (if (code in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (code !in 200..299) {
                mapOf("ok" to false, "error" to describe(code, text))
            } else {
                val names = try {
                    val data = JSONObject(text).optJSONArray("data")
                    if (data == null) emptyList<String>() else
                        (0 until data.length()).mapNotNull { data.optJSONObject(it)?.optString("id") }
                            .filter { it.isNotEmpty() }
                } catch (error: Exception) {
                    emptyList()
                }
                mapOf("ok" to true, "models" to names.take(60), "error" to "")
            }
        } catch (error: Exception) {
            mapOf("ok" to false, "error" to "ارتباط برقرار نشد: ${error.message ?: "شبکه در دسترس نیست"}")
        } finally {
            connection?.disconnect()
        }
    }

    private fun request(
        base: String,
        config: Config,
        wav: File,
        onProgress: (Int) -> Unit,
        isCancelled: () -> Boolean,
    ): String? {
        val boundary = "----subflow${System.currentTimeMillis()}"
        val headers = StringBuilder()
        fun field(name: String, value: String) {
            headers.append("--").append(boundary).append("\r\n")
            headers.append("Content-Disposition: form-data; name=\"").append(name).append("\"\r\n\r\n")
            headers.append(value).append("\r\n")
        }
        field("model", config.model)
        if (config.language.isNotBlank() && config.language != "auto") field("language", config.language)
        field("response_format", "verbose_json")
        field("timestamp_granularities[]", "segment")
        headers.append("--").append(boundary).append("\r\n")
        headers.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        headers.append("Content-Type: audio/wav\r\n\r\n")
        val head = headers.toString().toByteArray(Charsets.UTF_8)
        val tail = "\r\n--$boundary--\r\n".toByteArray(Charsets.UTF_8)
        val total = head.size.toLong() + wav.length() + tail.size

        var connection: HttpURLConnection? = null
        try {
            val endpoint = if (config.translate) "audio/translations" else "audio/transcriptions"
            connection = (URL("$base/$endpoint") as HttpURLConnection).apply {
                requestMethod = "POST"
                doOutput = true
                connectTimeout = 30_000
                readTimeout = TIMEOUT_MS
                setFixedLengthStreamingMode(total)
                setRequestProperty("Authorization", "Bearer ${config.apiKey}")
                setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                setRequestProperty("Accept", "application/json")
            }
            BufferedOutputStream(connection.outputStream, 64 * 1024).use { out ->
                out.write(head)
                var sent = head.size.toLong()
                FileInputStream(wav).use { input ->
                    val buffer = ByteArray(64 * 1024)
                    var read = input.read(buffer)
                    while (read > 0) {
                        if (isCancelled()) return null
                        out.write(buffer, 0, read)
                        sent += read
                        onProgress((15 + sent * 70 / total).toInt().coerceIn(15, 85))
                        read = input.read(buffer)
                    }
                }
                out.write(tail)
                out.flush()
            }
            val code = connection.responseCode
            val text = (if (code in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (code !in 200..299) throw IOException(describe(code, text))
            return text
        } finally {
            connection?.disconnect()
        }
    }

    /** Accepts `verbose_json` with segments and falls back to splitting plain text. */
    private fun parse(body: String, durationUs: Long): String {
        val root = try {
            JSONObject(body)
        } catch (error: Exception) {
            throw IOException("پاسخ سرویس خوانا نبود.")
        }
        val segments = JSONArray()
        val list = root.optJSONArray("segments")
        if (list != null) {
            for (index in 0 until list.length()) {
                val item = list.optJSONObject(index) ?: continue
                val text = item.optString("text").trim()
                if (text.isEmpty()) continue
                val start = (item.optDouble("start", 0.0) * 1_000_000).toLong()
                val end = (item.optDouble("end", 0.0) * 1_000_000).toLong()
                if (end <= start) continue
                segments.put(JSONArray().put(start).put(end).put(text))
            }
        }
        if (segments.length() == 0) {
            val text = root.optString("text").trim()
            if (text.isEmpty()) return errorJson("سرویس آنلاین متنی برنگرداند.")
            // No timings: spread the words over the real duration rather than
            // inventing one caption for a ten-minute video.
            val pieces = splitText(text)
            var cursor = 0.0
            for (piece in pieces) {
                val share = if (pieces.isEmpty()) 1.0 else piece.length.toDouble() / pieces.sumOf { it.length }
                val start = (durationUs * cursor).toLong()
                val end = (durationUs * (cursor + share)).toLong().coerceAtLeast(start + 200_000)
                segments.put(JSONArray().put(start).put(end).put(piece))
                cursor += share
            }
        }
        return JSONObject().put("ok", true).put("segments", segments).put("engine", "cloud").toString()
    }

    private fun splitText(text: String): List<String> {
        val out = ArrayList<String>()
        val builder = StringBuilder()
        for (character in text) {
            builder.append(character)
            val boundary = character == '.' || character == '!' || character == '?' ||
                character == '؟' || character == '،' || character == '\n'
            if (boundary && builder.trim().length >= 8) {
                out.add(builder.toString().trim())
                builder.setLength(0)
            } else if (builder.length >= 70) {
                out.add(builder.toString().trim())
                builder.setLength(0)
            }
        }
        if (builder.trim().isNotEmpty()) out.add(builder.toString().trim())
        return out.filter { it.isNotEmpty() }
    }

    /**
     * 16-bit mono WAV at 16 kHz. Sent as-is so the service receives the same
     * audio the on-device engine would have seen.
     */
    private fun writeWav(target: File, pcm: FloatArray) {
        val dataBytes = pcm.size * 2
        BufferedOutputStream(FileOutputStream(target), 64 * 1024).use { out ->
            val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
            header.put("RIFF".toByteArray())
            header.putInt(36 + dataBytes)
            header.put("WAVE".toByteArray())
            header.put("fmt ".toByteArray())
            header.putInt(16)
            header.putShort(1)
            header.putShort(1)
            header.putInt(SAMPLE_RATE)
            header.putInt(SAMPLE_RATE * 2)
            header.putShort(2)
            header.putShort(16)
            header.put("data".toByteArray())
            header.putInt(dataBytes)
            out.write(header.array())
            val chunk = ByteBuffer.allocate(64 * 1024).order(ByteOrder.LITTLE_ENDIAN)
            for (sample in pcm) {
                if (chunk.remaining() < 2) {
                    out.write(chunk.array(), 0, chunk.position())
                    chunk.clear()
                }
                val scaled = (sample.coerceIn(-1f, 1f) * 32767f).toInt().toShort()
                chunk.putShort(scaled)
            }
            if (chunk.position() > 0) out.write(chunk.array(), 0, chunk.position())
        }
    }

    private fun describe(code: Int, body: String): String {
        val detail = body.take(200).replace("\n", " ").trim()
        val reason = when (code) {
            400 -> "درخواست پذیرفته نشد (۴۰۰)"
            401 -> "کلید API پذیرفته نشد (۴۰۱)"
            403 -> "دسترسی به این مدل ندارید (۴۰۳)"
            404 -> "آدرس یا نام مدل پیدا نشد (۴۰۴)"
            413 -> "حجم صدا برای این سرویس زیاد است (۴۱۳)"
            429 -> "محدودیت تعداد درخواست (۴۲۹)"
            in 500..599 -> "خطای سرویس (${code})"
            else -> "خطای $code"
        }
        return if (detail.isEmpty()) reason else "$reason — $detail"
    }

    private fun errorJson(message: String): String =
        JSONObject().put("ok", false).put("error", message).toString()
}
