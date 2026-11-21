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
 * the platform permits it, and fall back to an inexact alarm otherwise.
 * `SCHEDULE_EXACT_ALARM` is declared in the manifest, but it is a special
 * access the user can revoke (and that the system may grant by default), so the
 * runtime check below is what actually decides: no check-in, no crash.
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
        // Mirror the alarm so BootReceiver can restore it after a restart: the
        // jobs table lives in Flutter's sqflite file, unreachable from a receiver.
        ReminderAlarmStore(context).upsert(
            ReminderAlarmStore.Entry(id, title, body, atMillis),
        )
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
        ReminderAlarmStore(context).remove(id)
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

/**
 * Re-arms reminders after a reboot or an app update.
 *
 * `AlarmManager` forgets every alarm when the device powers off, and there is no
 * way for a receiver to query the jobs table inside Flutter's sqflite database
 * before the Dart isolate exists. So [ReminderScheduler] mirrors each armed
 * reminder into SharedPreferences as it is scheduled, and this receiver restores
 * that mirror. The Dart side re-arms authoritatively on next launch; this only
 * makes sure a reminder set for tomorrow morning still fires if the phone was
 * restarted overnight.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        val ctx = context ?: return
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            return
        }
        // BOOT_COMPLETED is delivered while the device is still unlocking; the
        // direct-boot unaware receiver runs after the user unlock, which is when
        // the app's private storage is readable.
        rearmAll(ctx, System.currentTimeMillis())
    }

    companion object {
        /** A reminder missed by more than this window is stale and is dropped. */
        const val MISSED_WINDOW_MILLIS = 12L * 60 * 60 * 1000

        /** Restores every alarm still worth firing. Exposed for Robolectric tests. */
        @JvmStatic
        fun rearmAll(context: Context, nowMillis: Long) {
            val scheduler = ReminderScheduler(context)
            val pending = ReminderAlarmStore(context).load()
            val keep = mutableListOf<ReminderAlarmStore.Entry>()
            for (entry in pending) {
                if (entry.atMillis > nowMillis) {
                    scheduler.schedule(entry.id, entry.title, entry.body, entry.atMillis)
                    keep.add(entry)
                } else if (nowMillis - entry.atMillis <= MISSED_WINDOW_MILLIS) {
                    // Missed while the phone was off: show it once, don't re-arm.
                    ReminderNotifications.show(context, entry.id, entry.title, entry.body)
                }
                // Anything older than the window is silently forgotten.
            }
            ReminderAlarmStore(context).replaceAll(keep)
        }
    }
}

/**
 * Small durable mirror of the alarms that are currently armed.
 *
 * This is deliberately *not* a source of truth: the jobs table is. It exists
 * only because [BootReceiver] has to restore alarms before any Dart code runs.
 * Every value is last-writer-wins and is re-armed from the database on the next
 * app launch, so a stale entry can at worst post one extra reminder.
 */
class ReminderAlarmStore(context: Context) {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    data class Entry(
        val id: Int,
        val title: String,
        val body: String,
        val atMillis: Long,
    )

    fun upsert(entry: Entry) {
        val all = load().filterNot { it.id == entry.id } + entry
        replaceAll(all)
    }

    fun remove(id: Int) {
        replaceAll(load().filterNot { it.id == id })
    }

    fun load(): List<Entry> {
        val raw = prefs.getString(KEY_ALARMS, null) ?: return emptyList()
        return raw.lines().mapNotNull { line ->
            val parts = line.split(SEPARATOR)
            if (parts.size < 4) return@mapNotNull null
            val id = parts[0].toIntOrNull() ?: return@mapNotNull null
            val atMillis = parts[3].toLongOrNull() ?: return@mapNotNull null
            Entry(id, parts[1], parts[2], atMillis)
        }
    }

    fun replaceAll(entries: List<Entry>) {
        val encoded = entries.joinToString("\n") { entry ->
            listOf(entry.id, entry.title, entry.body, entry.atMillis)
                .joinToString(SEPARATOR.toString()) { sanitise(it.toString()) }
        }
        prefs.edit().putString(KEY_ALARMS, encoded).apply()
    }

    /** Keeps the line/field delimiters out of user-supplied reminder text. */
    private fun sanitise(value: String): String =
        value.replace("\n", " ").replace(SEPARATOR, ' ')

    companion object {
        private const val PREFS_NAME = "javid_reminder_alarms"
        private const val KEY_ALARMS = "alarms"
        private const val SEPARATOR = '\u001F'
    }
}
