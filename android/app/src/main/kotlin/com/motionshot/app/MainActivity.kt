package com.motionshot.app

import android.content.Intent
import android.os.Bundle
import com.motionshot.app.motion.ExportService
import com.motionshot.app.motion.SilenceAnalyzer
import com.motionshot.app.motion.StorageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the Flutter UI and registers the native channels.
 *
 * Lifecycle notes:
 *  * the two channels are re-registered on every engine attach, so a hot restart
 *    or a configuration change cannot leave the UI without a renderer
 *  * `onDestroy` cancels a running export: a killed activity means the user
 *    left, and a background render with no notification would be killed by the
 *    system anyway, leaving a corrupt file
 *  * stale temporaries from a previous run are cleaned at startup
 */
class MainActivity : FlutterActivity() {

    private var bridge: NativeBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppContextHolder.context = applicationContext
        // Remove exports from a previous session that never completed.
        StorageManager.cleanupTemp(File(cacheDir, "export").apply { mkdirs() })
        StorageManager.cleanupTemp(cacheDir)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val b = NativeBridge(applicationContext, this)
        bridge = b
        ExportService.bridge = b

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NativeBridge.METHOD_CHANNEL,
        ).setMethodCallHandler(b)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NativeBridge.EVENT_CHANNEL,
        ).setStreamHandler(b)

        // Audio picking lives on its own channel so the renderer contract stays
        // focused on rendering.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NativeBridge.MEDIA_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAudio" -> b.pickAudio { outcome ->
                    when (outcome) {
                        is AudioPicker.Outcome.Picked -> result.success(outcome.path)
                        is AudioPicker.Outcome.Cancelled -> result.success(null)
                        is AudioPicker.Outcome.Failed ->
                            result.error(outcome.code, outcome.message, null)
                    }
                }
                // Silence midpoints (seconds) of the given audio file; the
                // decode is heavy, so it runs on a worker thread.
                "analyzeSilences" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("BAD_ARGUMENT", "missing path", null)
                    } else {
                        Thread {
                            try {
                                result.success(SilenceAnalyzer.analyze(path))
                            } catch (e: SilenceAnalyzer.SilenceException) {
                                result.error(
                                    "AUDIO_UNREADABLE",
                                    e.message ?: "silence analysis failed",
                                    null,
                                )
                            } catch (e: Exception) {
                                result.error(
                                    "INTERNAL",
                                    e.message ?: "silence analysis failed",
                                    null,
                                )
                            }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val handled = bridge?.onActivityResult(requestCode, resultCode, data) ?: false
        if (!handled) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onDestroy() {
        ExportService.cancelAll()
        bridge = null
        ExportService.bridge = null
        super.onDestroy()
    }
}
