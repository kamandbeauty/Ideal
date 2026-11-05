package com.motionshot.app.motion

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import com.motionshot.app.AppContextHolder
import com.motionshot.app.MainActivity
import com.motionshot.app.NativeBridge
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * Foreground service that owns a running export.
 *
 * Why a service: a 4K export of a 30-shot project can run for minutes. Without a
 * foreground service Android kills the process as soon as the app leaves the
 * foreground, and the user loses the render. The notification shows real
 * progress, and the cancel action is wired to the worker.
 *
 * The service is started with the full request JSON so a process death does not
 * leave a half-known job behind; on destruction everything is released and any
 * partial MP4 is removed.
 */
class ExportService : Service() {

    companion object {
        private const val TAG = "ExportService"
        private const val CHANNEL_ID = "motionshot_export"
        private const val NOTIFICATION_ID = 7311
        const val ACTION_START = "com.motionshot.app.EXPORT_START"
        const val ACTION_CANCEL = "com.motionshot.app.EXPORT_CANCEL"
        const val EXTRA_SESSION = "session"
        const val EXTRA_REQUEST = "request"

        private val running = ConcurrentHashMap<String, Session>()
        private val pendingCancels = ConcurrentHashMap.newKeySet<String>()

        @Volatile
        var bridge: NativeBridge? = null

        fun newIntent(context: Context, sessionId: String, requestJson: String): Intent =
            Intent(context, ExportService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_SESSION, sessionId)
                putExtra(EXTRA_REQUEST, requestJson)
            }

        fun requestCancel(sessionId: String) {
            val session = running[sessionId]
            if (session == null) {
                pendingCancels.add(sessionId)
                return
            }
            session.worker.cancel()
        }

        fun isRunning(sessionId: String): Boolean = running.containsKey(sessionId)

        /** Aborts everything (called when the app is being torn down). */
        fun cancelAll() {
            running.values.forEach { it.worker.cancel() }
        }
    }

    class Session(val sessionId: String, val worker: ExportWorker, val outputPath: String)

    private var notificationManager: NotificationManager? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        AppContextHolder.context = applicationContext
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createChannel()

        if (intent?.action == ACTION_CANCEL) {
            intent.getStringExtra(EXTRA_SESSION)?.let { requestCancel(it) }
            return START_NOT_STICKY
        }

        val sessionId = intent?.getStringExtra(EXTRA_SESSION)
        val requestJson = intent?.getStringExtra(EXTRA_REQUEST)
        if (sessionId == null || requestJson == null) {
            Log.e(TAG, "started without a request")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val initialNotification = buildNotification("Preparing", 0.0, sessionId)
        if (Build.VERSION.SDK_INT >= 35) {
            startForeground(
                NOTIFICATION_ID,
                initialNotification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING,
            )
        } else {
            startForeground(NOTIFICATION_ID, initialNotification)
        }

        val request = try {
            ExportRequest.fromJson(requestJson)
        } catch (e: Exception) {
            Log.e(TAG, "bad request: ${e.message}")
            bridge?.emitDone(sessionId, null, "UNSUPPORTED_FORMAT" to (e.message ?: "bad request"), false, 0)
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val started = SystemClock.elapsedRealtime()
        val listener = object : ExportWorker.ExportListener {
            override fun onProgress(stage: String, progress: Double, framesDone: Int, framesTotal: Int) {
                val elapsed = SystemClock.elapsedRealtime() - started
                val eta = if (progress > 0.02) {
                    ((elapsed / progress) - elapsed).toLong()
                } else {
                    null
                }
                bridge?.emit(
                    mapOf(
                        "sessionId" to sessionId,
                        "stage" to stage,
                        "progress" to progress,
                        "framesDone" to framesDone,
                        "framesTotal" to framesTotal,
                        "elapsedMs" to elapsed,
                        "etaMs" to eta,
                    ),
                )
                notificationManager?.notify(
                    NOTIFICATION_ID,
                    buildNotification(stageLabel(stage), progress, sessionId),
                )
            }

            override fun onCompleted(result: ExportWorker.ExportResult) {
                finish(sessionId, result, null, false, SystemClock.elapsedRealtime() - started)
            }

            override fun onFailed(code: String, message: String) {
                Log.e(TAG, "export failed ($code): $message")
                finish(sessionId, null, code to message, false, SystemClock.elapsedRealtime() - started)
            }

            override fun onCancelled() {
                finish(sessionId, null, null, true, SystemClock.elapsedRealtime() - started)
            }
        }

        val worker = ExportWorker(
            context = applicationContext,
            request = request,
            listener = listener,
            capabilities = DeviceCapabilities.detect(applicationContext),
        )
        running[sessionId] = Session(sessionId, worker, request.outputPath)
        if (pendingCancels.remove(sessionId)) {
            worker.cancel()
        }
        worker.start()
        return START_NOT_STICKY
    }

    private fun finish(
        sessionId: String,
        result: ExportWorker.ExportResult?,
        failure: Pair<String, String>?,
        cancelled: Boolean,
        elapsedMs: Long,
    ) {
        running.remove(sessionId)
        bridge?.emitDone(sessionId, result, failure, cancelled, elapsedMs)
        notificationManager?.cancel(NOTIFICATION_ID)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        // Anything still running is a teardown, not a finish: cancel hard and
        // let the worker's cleanup delete its partial file.
        running.values.forEach { session ->
            session.worker.cancel()
            try {
                File(session.outputPath).delete()
            } catch (e: Exception) {
                Log.w(TAG, "partial cleanup: ${e.message}")
            }
        }
        super.onDestroy()
    }

    private fun stageLabel(stage: String): String = when (stage) {
        "preparing" -> "Preparing"
        "decodingPhotos" -> "Reading photos"
        "rendering" -> "Rendering motion"
        "encoding" -> "Encoding video"
        "muxingAudio" -> "Mixing audio"
        "muxing" -> "Writing MP4"
        "verifying" -> "Checking the file"
        else -> "Exporting"
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Video export",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Progress of MotionShot video exports"
            setShowBadge(false)
        }
        notificationManager?.createNotificationChannel(channel)
    }

    private fun buildNotification(stage: String, progress: Double, sessionId: String): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val cancel = PendingIntent.getService(
            this,
            1,
            Intent(this, ExportService::class.java).apply {
                action = ACTION_CANCEL
                putExtra(EXTRA_SESSION, sessionId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MotionShot")
            .setContentText(stage)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel", cancel)
            .setProgress(100, (progress * 100).toInt().coerceIn(0, 100), progress <= 0.0)
            .build()
    }
}
