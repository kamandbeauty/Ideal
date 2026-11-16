package ai.javid.app.reminders

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Schedules reminders with `AlarmManager`.
 *
 * Why AlarmManager instead of only WorkManager: WorkManager defers work under
 * Doze and battery restrictions (a job requested for 08:00 may run at 08:40).
 * For a *user-visible reminder* we use a precise, allow-while-idle alarm when
 * the platform permits it, and fall back to an inexact alarm otherwise. We never
 * ask for `SCHEDULE_EXACT_ALARM` – on Android 12+ an app without that permission
 * simply gets the inexact fallback, which is honest and Play-policy friendly.
 */
class ReminderScheduler(private val context: Context) {

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun schedule(id: Int, title: String, body: String, atMillis: Long) {
        val intent = Intent(context, ReminderActionReceiver::class.java).apply {
            action = ReminderActionReceiver.ACTION_FIRE
            putExtra(ReminderActionReceiver.EXTRA_ID, id)
            putExtra(ReminderActionReceiver.EXTRA_TITLE, title)
            putExtra(ReminderActionReceiver.EXTRA_BODY, body)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val canScheduleExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        if (canScheduleExact) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
        } else {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
        }
    }

    fun cancel(id: Int) {
        val intent = Intent(context, ReminderActionReceiver::class.java).apply {
            action = ReminderActionReceiver.ACTION_FIRE
        }
        val pending = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        if (pending != null) alarmManager.cancel(pending)
    }
}

/** Receives alarm intents and posts the reminder notification. */
class ReminderActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        val ctx = context ?: return
        val action = intent?.action ?: return
        if (action != ACTION_FIRE) return
        val id = intent.getIntExtra(EXTRA_ID, 1)
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty().ifEmpty { "یادآوری جویده" }
        val body = intent.getStringExtra(EXTRA_BODY).orEmpty()
        ReminderNotifications.show(ctx, id, title, body)
    }

    companion object {
        const val ACTION_FIRE = "ai.javid.app.reminders.FIRE"
        const val EXTRA_ID = "id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
    }
}

/** Notification channel + posting helper. */
object ReminderNotifications {
    private const val CHANNEL_ID = "javid_reminders"

    fun show(context: Context, id: Int, title: String, body: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "یادآوری وظایف",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "یادآوری‌های زمان‌بندی‌شدهٔ جویده"
            }
            manager.createNotificationChannel(channel)
        }

        val openApp = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = openApp?.let {
            PendingIntent.getActivity(
                context,
                id,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .apply { contentIntent?.let { setContentIntent(it) } }
            .build()

        try {
            NotificationManagerCompat.from(context).notify(id, notification)
        } catch (error: SecurityException) {
            // POST_NOTIFICATIONS not granted (Android 13+): the reminder is
            // still recorded in the app, so nothing is silently lost.
        }
    }
}
