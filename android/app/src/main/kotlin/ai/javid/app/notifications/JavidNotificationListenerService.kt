package ai.javid.app.notifications

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Reads notifications from the status bar (SMS, WhatsApp, Telegram, others).
 *
 * Hard limits, by design:
 *  * only notifications the system publishes are visible — never chat history;
 *  * only the app package, title, sender, trimmed text and timestamp are kept;
 *  * images, actions, replies and messaging-style extras are ignored;
 *  * per-source toggles are enforced *here* before anything is stored;
 *  * entries are deduplicated and capped so storage cannot grow unbounded.
 *
 * Nothing is uploaded anywhere: the capture store is a private
 * SharedPreferences file that the Flutter layer reads through the method
 * channel and copies into its own SQLite database.
 */
class JavidNotificationListenerService : NotificationListenerService() {

    override fun onListenerConnected() {
        Log.i(TAG, "notification listener connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn ?: return
        try {
            capture(notification)
        } catch (error: Exception) {
            // Never crash the system listener: a bad notification must not take
            // the service down.
            Log.w(TAG, "failed to capture notification", error)
        }
    }

    private fun capture(sbn: StatusBarNotification) {
        val packageName = sbn.packageName ?: return
        val source = NotificationSources.classify(packageName) ?: return
        val store = NotificationStore(this)
        if (!store.isSourceEnabled(source)) return

        val extras = sbn.notification?.extras ?: return
        if (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) {
            // Group summaries duplicate their children; skip them.
            return
        }

        val title = NotificationText.normalize(
            extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty(),
        ).take(NotificationText.MAX_TEXT_LENGTH)
        val body = NotificationText.bestBody(
            text = extras.getCharSequence(Notification.EXTRA_TEXT),
            bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT),
            subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT),
        )
        if (title.isEmpty() && body.isEmpty()) return

        store.add(
            packageName = packageName,
            appLabel = NotificationSources.labelFor(this, packageName),
            sender = title,
            text = body,
            postedAt = sbn.postTime,
            dedupeKey = NotificationText.dedupeKey(packageName, title, body),
        )
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Intentionally ignored: JavidAI keeps a short history for the briefing.
    }

    companion object {
        private const val TAG = "JavidListener"

        /** Whether the listener is currently bound (used by settings diagnostics). */
        fun isConnected(context: Context): Boolean {
            val flat = android.provider.Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            val component = ComponentName(context, JavidNotificationListenerService::class.java)
            return flat.contains(component.flattenToString()) ||
                flat.contains(component.flattenToShortString())
        }
    }
}

/** Known package → source mapping, mirrored (and unit-tested) in Dart. */
object NotificationSources {
    const val WHATSAPP = "whatsapp"
    const val TELEGRAM = "telegram"
    const val SMS = "sms"

    private val whatsappPackages = setOf("com.whatsapp", "com.whatsapp.w4b")
    private val telegramPackages = setOf(
        "org.telegram.messenger",
        "org.telegram.messenger.web",
        "org.thunderdog.challegram",
        "org.telegram.plus",
    )
    private val smsPackages = setOf(
        "com.google.android.apps.messaging",
        "com.android.mms",
        "com.samsung.android.messaging",
        "com.miui.smsextra",
    )

    fun classify(packageName: String): String? = when {
        whatsappPackages.contains(packageName) -> WHATSAPP
        telegramPackages.contains(packageName) -> TELEGRAM
        smsPackages.contains(packageName) -> SMS
        else -> null
    }

    fun labelFor(context: Context, packageName: String): String {
        return try {
            val info = context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(info).toString()
        } catch (error: Exception) {
            packageName
        }
    }
}

/**
 * Private, bounded notification store shared with the Flutter layer.
 *
 * Uses SharedPreferences (a single small JSON-ish line per entry) to avoid
 * pulling in a database for data the app already keeps in SQLite: this buffer
 * only bridges background capture → next app open.
 */
class NotificationStore(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun isSourceEnabled(source: String): Boolean =
        prefs.getBoolean("source_$source", source != "other")

    fun setSourceEnabled(source: String, enabled: Boolean) {
        prefs.edit().putBoolean("source_$source", enabled).apply()
    }

    fun add(
        packageName: String,
        appLabel: String,
        sender: String,
        text: String,
        postedAt: Long,
        dedupeKey: String,
    ) {
        val entry = mapOf(
            "packageName" to packageName,
            "appLabel" to appLabel,
            "sender" to sender,
            "text" to text,
            "postedAt" to postedAt,
            "dedupeKey" to dedupeKey,
        )
        val entries = recent(MAX_ENTRIES).toMutableList()
        if (entries.any { it["dedupeKey"] == dedupeKey }) return
        entries.add(0, entry)
        val trimmed = entries.take(MAX_ENTRIES)
        prefs.edit().putString(KEY_ENTRIES, encode(trimmed)).apply()
    }

    fun recent(limit: Int): List<Map<String, Any>> {
        val raw = prefs.getString(KEY_ENTRIES, null) ?: return emptyList()
        return decode(raw).take(limit)
    }

    fun clear() {
        prefs.edit().remove(KEY_ENTRIES).apply()
    }

    private fun encode(entries: List<Map<String, Any>>): String =
        entries.joinToString("\n") { entry ->
            listOf(
                entry["packageName"],
                entry["appLabel"],
                entry["sender"],
                entry["text"],
                entry["postedAt"],
                entry["dedupeKey"],
            ).joinToString("\u001F") { value -> value.toString().replace("\n", " ").replace("\u001F", " ") }
        }

    private fun decode(raw: String): List<Map<String, Any>> = raw.lines().mapNotNull { line ->
        val parts = line.split("\u001F")
        if (parts.size < 6) return@mapNotNull null
        mapOf(
            "packageName" to parts[0],
            "appLabel" to parts[1],
            "sender" to parts[2],
            "text" to parts[3],
            "postedAt" to (parts[4].toLongOrNull() ?: return@mapNotNull null),
            "dedupeKey" to parts[5],
        )
    }

    companion object {
        private const val PREFS_NAME = "javid_captured_notifications"
        private const val KEY_ENTRIES = "entries"
        private const val MAX_ENTRIES = 300
    }
}
