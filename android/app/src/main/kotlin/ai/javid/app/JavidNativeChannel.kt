package ai.javid.app

import ai.javid.app.notifications.NotificationStore
import ai.javid.app.reminders.ReminderScheduler
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The single method channel between Dart and Kotlin.
 *
 * Security notes:
 *  * every method maps to a fixed, well-known Android API;
 *  * no method executes arbitrary intents or code;
 *  * notification data returned here was already captured with an explicit
 *    user-granted permission (`BIND_NOTIFICATION_LISTENER_SERVICE`).
 */
class JavidNativeChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    fun register() {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasNotificationAccess" -> result.success(isNotificationAccessGranted())
            "openNotificationSettings" -> result.success(openNotificationSettings())
            "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
            "requestIgnoreBatteryOptimizations" -> result.success(requestIgnoreBatteryOptimizations())
            "fetchCapturedNotifications" -> {
                val limit = call.argument<Int>("limit") ?: 50
                result.success(NotificationStore(context).recent(limit))
            }
            "showNotification" -> {
                val id = call.argument<Int>("id") ?: 1
                val title = call.argument<String>("title").orEmpty()
                val body = call.argument<String>("body").orEmpty()
                ai.javid.app.reminders.ReminderNotifications.show(context, id, title, body)
                result.success(true)
            }
            "scheduleReminder" -> {
                val id = call.argument<Int>("id") ?: return result.error("bad_args", "id missing", null)
                val title = call.argument<String>("title").orEmpty()
                val body = call.argument<String>("body").orEmpty()
                val atMillis = call.argument<Long>("atMillis")
                    ?: return result.error("bad_args", "atMillis missing", null)
                ReminderScheduler(context).schedule(id, title, body, atMillis)
                result.success(true)
            }
            "cancelReminder" -> {
                val id = call.argument<Int>("id") ?: return result.error("bad_args", "id missing", null)
                ReminderScheduler(context).cancel(id)
                result.success(true)
            }
            "deviceSummary" -> result.success(deviceSummary())
            else -> result.notImplemented()
        }
    }

    private fun isNotificationAccessGranted(): Boolean {
        val enabled = NotificationManagerCompatBridge.enabledListenerPackages(context)
        return enabled.contains(context.packageName)
    }

    private fun openNotificationSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (error: Exception) {
            false
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return false
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (error: Exception) {
            false
        }
    }

    private fun deviceSummary(): String {
        val manufacturer = Build.MANUFACTURER ?: ""
        val model = Build.MODEL ?: ""
        return listOf(
            "JavidAI",
            "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            "$manufacturer $model",
        ).filter { !TextUtils.isEmpty(it) }.joinToString(" · ")
    }

    companion object {
        const val CHANNEL_NAME = "ai.javid.app/native"
    }
}

/** Small indirection so the notification-access check is testable and null-safe. */
object NotificationManagerCompatBridge {
    fun enabledListenerPackages(context: Context): Set<String> {
        val flat = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return emptySet()
        val components = flat.split(":")
        val packages = HashSet<String>(components.size)
        for (component in components) {
            val parsed = android.content.ComponentName.unflattenFromString(component) ?: continue
            packages.add(parsed.packageName)
        }
        return packages
    }
}
