import '../core/errors.dart';
import '../core/logger.dart';
import '../core/platform/contracts.dart';
import '../core/platform/native_bridge.dart';

/// Wraps the Android Photo Picker + MediaMetadataRetriever probe.
class MediaService {
  MediaService(this._bridge);

  final NativeBridge _bridge;
  static const SfLog _log = SfLog('media');

  /// In-flight/complete frame lookups, so a rebuilding list asks once per video.
  static final Map<String, Future<String?>> _thumbs = <String, Future<String?>>{};

  Future<String?> thumbnailFor(String uri, {int timeMs = 1000, int width = 480}) {
    final String key = '$uri@$timeMs@$width';
    return _thumbs.putIfAbsent(
      key,
      () => _bridge.thumbnail(uri: uri, key: uri, timeMs: timeMs, width: width),
    );
  }

  static final Map<String, Future<List<int>>> _waveforms = <String, Future<List<int>>>{};

  /// Amplitude buckets for a video's audio, computed once per file.
  Future<List<int>> waveformFor(String uri, {int buckets = 72}) {
    return _waveforms.putIfAbsent(
      '$uri@$buckets',
      () => _bridge.waveform(uri: uri, buckets: buckets),
    );
  }

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
