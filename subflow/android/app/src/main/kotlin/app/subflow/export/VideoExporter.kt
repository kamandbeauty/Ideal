package app.subflow.export

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import java.io.File
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Renders the project video with the captions burned in.
 *
 * Media3's `Transformer` re-encodes the frame graph; the caption is an
 * `OverlayEffect` on top of the (optionally down-scaled) video, so the exported
 * file is a normal H.264/AAC MP4 that plays anywhere - no sidecar subtitle file
 * and no player support needed.
 *
 * Everything runs on a dedicated `HandlerThread` because `Transformer` requires
 * a `Looper`: the bridge's IO thread waits on a latch, the looper stays free to
 * process the encoder callbacks, and cancellation is posted to the same looper
 * so two threads never touch the transformer at once.
 */
@OptIn(UnstableApi::class)
internal class VideoExporter(
    private val context: Context,
    private val emit: (Map<String, Any?>) -> Unit,
) {

    private val lock = Any()
    private var transformer: Transformer? = null

    @Volatile
    private var handler: Handler? = null

    /** Settles the current run as cancelled; set while an export is running. */
    @Volatile
    private var cancelAction: (() -> Unit)? = null

    private class Meta(val width: Int, val height: Int, val rotation: Int, val durationUs: Long)

    /**
     * `Transformer.cancel()` only reports through `verifyApplicationThread()`,
     * not through the listener, so the pending latch is released here as well -
     * otherwise a cancelled export would leave the caller waiting forever.
     */
    fun cancel() {
        val current = synchronized(lock) { transformer }
        val looper = handler
        val settle = cancelAction
        if (looper != null) {
            looper.post {
                runCatching { current?.cancel() }
                runCatching { settle?.invoke() }
            }
        } else {
            runCatching { current?.cancel() }
            runCatching { settle?.invoke() }
        }
    }

    /** Blocks until the file exists, the user cancelled, or the encoder failed. */
    fun run(request: ExportRequest): Map<String, Any?> {
        cancelAction = null
        val latch = CountDownLatch(1)
        val outcome = AtomicReference<Map<String, Any?>?>(null)
        val thread = HandlerThread("subflow-export")
        thread.start()
        val looper = Handler(thread.looper)
        handler = looper
        looper.post { start(request, looper, latch, outcome) }
        latch.await()
        handler = null
        thread.quitSafely()
        return outcome.get() ?: failure("خروجی ویدئو ساخته نشد")
    }

    private fun start(
        request: ExportRequest,
        looper: Handler,
        latch: CountDownLatch,
        outcome: AtomicReference<Map<String, Any?>?>,
    ) {
        var finished = false

        fun settle(result: Map<String, Any?>) {
            if (finished) return
            finished = true
            outcome.set(result)
            latch.countDown()
        }

        val file: File
        val frame: Pair<Int, Int>
        try {
            val meta = probe(request.uri)
            if (meta.width <= 0 || meta.height <= 0) {
                settle(failure("ابعاد ویدئو خوانده نشد"))
                return
            }
            frame = outputFrame(meta, request.maxShortEdge)
            file = outputFile(request.outputName)
            if (file.exists() && !file.delete()) {
                settle(failure("فایل قبلی حذف نشد"))
                return
            }
            val painter = CaptionFramePainter(
                context,
                request.look,
                frame.first,
                frame.second,
                request.cues,
                request.trimStartUs ?: 0L,
            )
            val overlay = CaptionOverlay(painter)
            val effects = Effects(
                emptyList<AudioProcessor>(),
                listOf<Effect>(
                    Presentation.createForHeight(frame.second),
                    OverlayEffect(ImmutableList.of<TextureOverlay>(overlay)),
                ),
            )
            // Media3 1.4 keeps the trim on the MediaItem (milliseconds). The
            // renderer's timestamps are microseconds, so this is the one place
            // the unit changes.
            val mediaItem = MediaItem.Builder()
                .setUri(request.uri)
                .apply {
                    request.trimStartUs?.let { setClipStartPositionMs(it / 1000L) }
                    request.trimEndUs?.let { setClipEndPositionMs(it / 1000L) }
                }
                .build()
            val item = EditedMediaItem.Builder(mediaItem)
                .setEffects(effects)
                .build()

            cancelAction = {
                runCatching { file.delete() }
                settle(cancelledResult())
            }

            val listener = object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    settle(completed(file, frame))
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    runCatching { file.delete() }
                    settle(failure(describe(exportException)))
                }
            }

            val built = Transformer.Builder(context)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(listener)
                .build()
            synchronized(lock) { transformer = built }

            emit(
                mapOf(
                    "event" to "export",
                    "state" to "started",
                    "width" to frame.first,
                    "height" to frame.second,
                )
            )
            built.start(item, file.absolutePath)

            val progress = ProgressHolder()
            var lastPercent = -1
            val poll = object : Runnable {
                override fun run() {
                    if (finished) return
                    val state = runCatching { built.getProgress(progress) }.getOrElse { return }
                    if (state == Transformer.PROGRESS_STATE_AVAILABLE &&
                        progress.progressPercent > lastPercent
                    ) {
                        lastPercent = progress.progressPercent
                        emit(
                            mapOf(
                                "event" to "export",
                                "state" to "progress",
                                "progress" to lastPercent,
                            )
                        )
                    }
                    looper.postDelayed(this, 400)
                }
            }
            looper.postDelayed(poll, 400)
        } catch (error: Exception) {
            settle(failure(error.message ?: "خروجی ویدئو ناموفق بود"))
            return
        }

        // The latch is released by the listener or by cancel(); this looper is
        // never blocked, which is what lets the encoder callbacks arrive.
    }

    // --------------------------------------------------------------- results

    private fun completed(file: File, frame: Pair<Int, Int>): Map<String, Any?> {
        val meta = runCatching { probe(Uri.fromFile(file).toString()) }.getOrNull()
        val result = mapOf(
            "ok" to true,
            "path" to file.absolutePath,
            "bytes" to file.length(),
            "width" to (meta?.width ?: frame.first),
            "height" to (meta?.height ?: frame.second),
            "durationUs" to (meta?.durationUs ?: 0L),
        )
        emit(
            mapOf(
                "event" to "export",
                "state" to "done",
                "progress" to 100,
                "path" to file.absolutePath,
                "bytes" to file.length(),
            )
        )
        return result
    }

    private fun failure(message: String): Map<String, Any?> {
        emit(mapOf("event" to "export", "state" to "error", "message" to message))
        return mapOf("ok" to false, "message" to message)
    }

    private fun cancelledResult(): Map<String, Any?> {
        emit(mapOf("event" to "export", "state" to "cancelled"))
        return mapOf("ok" to false, "cancelled" to true, "message" to "ساخت ویدئو لغو شد")
    }

    private fun describe(error: ExportException): String {
        val code = error.errorCode
        return when (code) {
            ExportException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED,
            ExportException.ERROR_CODE_DECODER_INIT_FAILED,
            ExportException.ERROR_CODE_DECODING_FAILED,
            -> "این ویدئو توسط موبایل قابل رمزگشایی نیست."
            ExportException.ERROR_CODE_ENCODING_FORMAT_UNSUPPORTED,
            ExportException.ERROR_CODE_ENCODER_INIT_FAILED,
            ExportException.ERROR_CODE_ENCODING_FAILED,
            -> "سخت‌افزار رمزگذاری این خروجی را پشتیبانی نمی‌کند."
            ExportException.ERROR_CODE_IO_FILE_NOT_FOUND -> "فایل ویدئو پیدا نشد."
            ExportException.ERROR_CODE_IO_NO_PERMISSION -> "اجازهٔ خواندن ویدئو داده نشده است."
            ExportException.ERROR_CODE_MUXING_FAILED -> "نوشتن فایل خروجی ناموفق بود."
            else -> error.message ?: "خروجی ویدئو ناموفق بود (کد $code)"
        }
    }

    // ----------------------------------------------------------------- files

    private fun outputFile(name: String): File {
        val dir = File(
            context.getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: context.filesDir,
            "exports",
        )
        if (!dir.exists()) dir.mkdirs()
        val safe = name
            .replace('/', '_')
            .replace('\\', '_')
            .lowercase(Locale.ROOT)
            .let { if (it.endsWith(".mp4")) it else "$it.mp4" }
        return File(dir, safe)
    }

    private fun probe(uri: String): Meta {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(context, Uri.parse(uri))
            val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: 0
            val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: 0
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            return Meta(width, height, rotation, durationMs * 1000L)
        } finally {
            runCatching { retriever.release() }
        }
    }

    /**
     * The output frame after rotation is applied, capped on its short edge so
     * "1080p" means 1080x1920 for a portrait clip and 1920x1080 for a landscape
     * one, never a stretched frame.
     */
    private fun outputFrame(meta: Meta, maxShortEdge: Int): Pair<Int, Int> {
        val swap = meta.rotation == 90 || meta.rotation == 270
        val sourceW = if (swap) meta.height else meta.width
        val sourceH = if (swap) meta.width else meta.height
        if (sourceW <= 0 || sourceH <= 0) return Pair(1080, 1920)
        val shortEdge = min(sourceW, sourceH)
        val cap = if (maxShortEdge > 0) min(maxShortEdge, shortEdge) else shortEdge
        val scale = cap.toFloat() / shortEdge
        fun even(value: Int): Int = ((value * scale).roundToInt() / 2 * 2).coerceAtLeast(2)
        return Pair(even(sourceW), even(sourceH))
    }
}
