package ai.javid.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Flutter host activity.
 *
 * Extra behaviour beyond the default template:
 *  * registers [JavidNativeChannel] so Dart can query notification access,
 *    trigger alarms and show local notifications;
 *  * exposes nothing else: no shell, no arbitrary intents.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        JavidNativeChannel(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        ).register()
    }
}
