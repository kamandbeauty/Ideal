package app.subflow

import android.os.Bundle
import app.subflow.bridge.BridgeContract
import app.subflow.bridge.SubFlowBridge
import app.subflow.media.MediaPicker
import app.subflow.media.PlayerViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Single activity. Wiring only - all logic lives in the bridge, the media
 * modules and the C++ core, which keeps this class reviewable.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep the window background dark so Flutter's first frame never flashes white.
        window.setBackgroundDrawableResource(R.color.subflow_background)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The picker must be registered before the activity reaches RESUMED,
        // which is exactly where configureFlutterEngine runs.
        val picker = MediaPicker(this)
        val bridge = SubFlowBridge(this, picker)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BridgeContract.CHANNEL)
            .setMethodCallHandler(bridge)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            BridgeContract.PLAYER_VIEW_TYPE,
            PlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
    }
}
