import '../core/errors.dart';
import '../core/logger.dart';
import '../core/platform/contracts.dart';
import '../core/platform/native_bridge.dart';

/// Wraps the Android Photo Picker + MediaMetadataRetriever probe.
class MediaService {
  MediaService(this._bridge);

  final NativeBridge _bridge;
  static const SfLog _log = SfLog('media');

  /// Returns null when the user backs out of the picker (not an error).
  Future<VideoProbeResult?> pickAndProbe() async {
    final PickedVideoFile? picked = await _bridge.pickVideo();
    if (picked == null) return null;
    _log.d('picked ${picked.displayName} (${picked.sizeBytes} bytes)');
    final VideoProbeResult probe = await _bridge.probeVideo(picked.uri);
    if (!probe.isValid) {
      throw const AppFailure(
        AppErrorCode.unsupportedFormat,
        'این ویدئو قابل خواندن نیست. یک فایل MP4/H.264 یا HEVC انتخاب کنید.',
      );
    }
    return probe;
  }
}
