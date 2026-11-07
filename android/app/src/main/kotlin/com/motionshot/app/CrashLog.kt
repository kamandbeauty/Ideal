package com.motionshot.app

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Local, append-only crash log (no network, by design).
 *
 * The worker thread catches `Exception`s on its own, but JVM `Error`s
 * (NoSuchMethodError on an OEM lib, VerifyError, ...) and native faults can
 * still kill the process. Writing the stack to a file before dying means the
 * next run can show the user exactly what happened instead of a silent
 * "app closed".
 */
object CrashLog {
    private const val MAX_BYTES = 96 * 1024

    private var file: File? = null

    fun init(context: Context) {
        file = File(context.filesDir, "motionshot_crash.log")
    }

    fun append(threadName: String, throwable: Throwable) {
        val f = file ?: return
        try {
            val stamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
            val sb = StringBuilder()
            sb.append("\n===== $stamp thread=$threadName =====\n")
            sb.append(throwable.stackTraceToString())
            var cause = throwable
            var hops = 0
            while (cause.cause != null && cause.cause !== cause && hops < 5) {
                cause = cause.cause!!
                hops++
                sb.append("Caused by: ${cause.stackTraceToString()}")
            }
            val existing = if (f.exists()) f.length() else 0L
            var text = if (existing > 0) f.readText() else ""
            text += sb.toString()
            if (text.toByteArray().size > MAX_BYTES) {
                text = text.substring(text.length - MAX_BYTES)
            }
            f.writeText(text)
        } catch (e: Exception) {
            // Logging must never make things worse.
        }
    }

    /** The captured crash text, or null when there is none. */
    fun read(): String? {
        val f = file ?: return null
        return try {
            if (!f.exists()) null else f.readText().takeIf { it.isNotBlank() }
        } catch (e: Exception) {
            null
        }
    }

    fun clear() {
        try {
            file?.delete()
        } catch (e: Exception) {
            // ignore
        }
    }
}
