package app.subflow.bridge

/**
 * Single source of truth for the Dart <-> Kotlin contract.
 *
 * Every constant here is mirrored in `lib/core/constants.dart`
 * (`Channels`, `NativeMethods`). `tools/check-project.py` fails the build if the
 * two files drift apart, which is what keeps a hand-written channel safer than
 * a generated one nobody reviews.
 */
object BridgeContract {
    const val CHANNEL = "app.subflow/native"

    const val PLAYER_VIEW_TYPE = "app.subflow/player_view"
    const val PLAYER_CHANNEL_PREFIX = "app.subflow/player"

    // Inbound (Dart -> Kotlin)
    const val METHOD_PICK_VIDEO = "media.pickVideo"
    const val METHOD_PROBE_VIDEO = "media.probe"
    const val METHOD_FILE_EXISTS = "media.fileExists"
    const val METHOD_CAPABILITIES = "device.capabilities"
    const val METHOD_WRITE_SRT = "subtitle.writeSrt"
    const val METHOD_WRITE_ASS = "subtitle.writeAss"
    const val METHOD_PLAN_EXPORT = "export.plan"

    // Outbound (Kotlin -> Dart) on the per-player channel
    const val METHOD_PLAYER_EVENT = "onPlayerEvent"

    // Player commands
    const val PLAYER_PLAY = "play"
    const val PLAYER_PAUSE = "pause"
    const val PLAYER_SEEK = "seek"
    const val PLAYER_SET_SPEED = "setSpeed"
    const val PLAYER_DISPOSE = "dispose"
}
