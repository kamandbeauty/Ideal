package app.subflow.media

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import app.subflow.bridge.BridgeContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Hosts one Media3 ExoPlayer inside a Flutter platform view.
 *
 * The player renders the original file untouched (no decoding/re-encoding in
 * the preview path). Later phases draw the caption overlay on top of the same
 * surface, using the shared style model, so preview and export cannot diverge.
 *
 * Each instance owns its own MethodChannel (`app.subflow/player/<id>`), which
 * means two previews can never share control state.
 */
class PlayerViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?> ?: emptyMap()
        val uri = params["uri"] as? String ?: ""
        val channelId = (params["viewId"] as? Number)?.toInt() ?: viewId
        return SubFlowPlayerView(context, messenger, channelId, uri)
    }
}

class SubFlowPlayerView(
    context: Context,
    messenger: BinaryMessenger,
    private val viewId: Int,
    private val uri: String,
) : PlatformView {

    private val playerView: PlayerView = PlayerView(context).apply {
        useController = false
        setShowBuffering(PlayerView.SHOW_BUFFERING_NEVER)
    }

    private val player: ExoPlayer = ExoPlayer.Builder(context).build()
    private val channel = MethodChannel(messenger, "${BridgeContract.PLAYER_CHANNEL_PREFIX}/$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())
    private var released = false
    private var lastError: String? = null

    private val ticker = object : Runnable {
        override fun run() {
            emitState()
            if (!released) mainHandler.postDelayed(this, TICK_MS)
        }
    }

    private val listener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) = emitState()

        override fun onIsPlayingChanged(isPlaying: Boolean) = emitState()

        override fun onPlayerError(error: PlaybackException) {
            lastError = error.errorCodeName
            emitState()
        }
    }

    init {
        playerView.player = player
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                BridgeContract.PLAYER_PLAY -> {
                    player.play()
                    result.success(null)
                }
                BridgeContract.PLAYER_PAUSE -> {
                    player.pause()
                    result.success(null)
                }
                BridgeContract.PLAYER_SEEK -> {
                    val positionUs = (call.argument<Number>("positionUs"))?.toLong() ?: 0L
                    player.seekTo(positionUs / 1000L)
                    emitState()
                    result.success(null)
                }
                BridgeContract.PLAYER_SET_SPEED -> {
                    val speed = (call.argument<Number>("speed"))?.toFloat() ?: 1f
                    player.setPlaybackSpeed(speed.coerceIn(0.25f, 4f))
                    result.success(null)
                }
                BridgeContract.PLAYER_DISPOSE -> {
                    dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        player.addListener(listener)
        if (uri.isNotEmpty()) {
            player.setMediaItem(MediaItem.fromUri(uri))
            player.prepare()
        } else {
            lastError = "EMPTY_URI"
        }
        mainHandler.post(ticker)
    }

    private fun emitState() {
        if (released) return
        val durationMs = player.duration.coerceAtLeast(0L)
        val positionMs = player.currentPosition.coerceIn(0L, durationMs)
        val payload = HashMap<String, Any?>()
        payload["positionUs"] = positionMs * 1000L
        payload["durationUs"] = if (durationMs == 0L) 0L else durationMs * 1000L
        payload["isPlaying"] = player.isPlaying
        payload["isReady"] = player.playbackState == Player.STATE_READY
        payload["isBuffering"] = player.playbackState == Player.STATE_BUFFERING
        lastError?.let { payload["error"] = it }
        channel.invokeMethod(BridgeContract.METHOD_PLAYER_EVENT, payload)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        if (released) return
        released = true
        mainHandler.removeCallbacks(ticker)
        channel.setMethodCallHandler(null)
        player.removeListener(listener)
        playerView.player = null
        player.release()
    }

    companion object {
        private const val TICK_MS = 200L
    }
}
