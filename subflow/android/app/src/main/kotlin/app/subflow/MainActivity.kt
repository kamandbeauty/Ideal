package app.subflow

import android.content.Intent
import android.os.Bundle
import app.subflow.bridge.BridgeContract
import app.subflow.bridge.SubFlowBridge
import app.subflow.media.MediaPicker
import app.subflow.media.PlayerViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Single activity. Wiring only - all logic lives in the bridge, the media
 * modules and the C++ core, which keeps this class reviewable.
 */
class MainActivity : FlutterActivity() {

    // Held so `onActivityResult` can hand the Photo Picker result back; the
    // bridge itself owns the channel and the IO thread.
    private var picker: MediaPicker? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep the window background dark so Flutter's first frame never flashes white.
        window.setBackgroundDrawableResource(R.color.subflow_background)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The picker must be registered before the activity reaches RESUMED,
        // which is exactly where configureFlutterEngine runs.
        val mediaPicker = MediaPicker(this)
        picker = mediaPicker
        var asrSink: EventChannel.EventSink? = null
        var exportSink: EventChannel.EventSink? = null
        val bridge = SubFlowBridge(
            this,
            mediaPicker,
            { event -> runOnUiThread { asrSink?.success(event) } },
            { event -> runOnUiThread { exportSink?.success(event) } },
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BridgeContract.CHANNEL)
            .setMethodCallHandler(bridge)

        // Whisper progress travels on its own event channel: transcription can
        // run for minutes, and one sink keeps the method channel reply clean.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BridgeContract.ASR_EVENTS_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        asrSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        asrSink = null
                    }
                }
            )

        // A render can run for a minute or two, so its progress travels on its
        // own channel for the same reason the Whisper one does.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BridgeContract.EXPORT_EVENTS_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        exportSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        exportSink = null
                    }
                }
            )

        flutterEngine.platformViewsController.registry.registerViewFactory(
            BridgeContract.PLAYER_VIEW_TYPE,
            PlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val handled = picker?.handleActivityResult(requestCode, resultCode, data) ?: false
        if (!handled) super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        picker = null
        super.onDestroy()
    }
}
