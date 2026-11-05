/// Data contracts exchanged with Kotlin. Parsed defensively: a probe that
/// returns a half-filled map must surface as a clear error, not a 0×0 preview.
class PickedVideoFile {
  const PickedVideoFile({
    required this.uri,
    required this.displayName,
    required this.sizeBytes,
  });

  final String uri;
  final String displayName;
  final int sizeBytes;

  factory PickedVideoFile.fromMap(Map<Object?, Object?> map) => PickedVideoFile(
        uri: (map['uri'] as String?) ?? '',
        displayName: (map['displayName'] as String?) ?? 'video',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      );
}

class VideoProbeResult {
  const VideoProbeResult({
    required this.uri,
    required this.displayName,
    required this.sizeBytes,
    required this.durationUs,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.fpsMilli,
    required this.bitrateBps,
    required this.hdr,
    this.videoCodec,
    this.colorTransfer,
    this.audioCodec,
    this.audioSampleRate = 0,
    this.audioChannels = 0,
    this.audioBitrateBps = 0,
    this.rawJson,
  });

  final String uri;
  final String displayName;
  final int sizeBytes;
  final int durationUs;

  /// Display geometry: rotation already applied, so a portrait phone clip
  /// reports 1080×1920 rather than 1920×1080.
  final int width;
  final int height;
  final int rotationDegrees;
  final int fpsMilli;
  final int bitrateBps;
  final bool hdr;
  final String? videoCodec;
  final String? colorTransfer;
  final String? audioCodec;
  final int audioSampleRate;
  final int audioChannels;
  final int audioBitrateBps;
  final String? rawJson;

  bool get isValid => width > 0 && height > 0 && durationUs > 0;

  factory VideoProbeResult.fromMap(Map<Object?, Object?> map) => VideoProbeResult(
        uri: (map['uri'] as String?) ?? '',
        displayName: (map['displayName'] as String?) ?? 'video',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        durationUs: (map['durationUs'] as num?)?.toInt() ?? 0,
        width: (map['width'] as num?)?.toInt() ?? 0,
        height: (map['height'] as num?)?.toInt() ?? 0,
        rotationDegrees: (map['rotationDegrees'] as num?)?.toInt() ?? 0,
        fpsMilli: (map['fpsMilli'] as num?)?.toInt() ?? 0,
        bitrateBps: (map['bitrateBps'] as num?)?.toInt() ?? 0,
        hdr: (map['hdr'] as bool?) ?? false,
        videoCodec: map['videoCodec'] as String?,
        colorTransfer: map['colorTransfer'] as String?,
        audioCodec: map['audioCodec'] as String?,
        audioSampleRate: (map['audioSampleRate'] as num?)?.toInt() ?? 0,
        audioChannels: (map['audioChannels'] as num?)?.toInt() ?? 0,
        audioBitrateBps: (map['audioBitrateBps'] as num?)?.toInt() ?? 0,
        rawJson: map['rawJson'] as String?,
      );
}

class DeviceCapabilities {
  const DeviceCapabilities({
    required this.sdkInt,
    required this.hardwareH264,
    required this.hardwareHevc,
    required this.nativeCoreReady,
    required this.abi,
    this.nativeCoreVersion,
  });

  final int sdkInt;
  final bool hardwareH264;
  final bool hardwareHevc;
  final bool nativeCoreReady;
  final String abi;
  final String? nativeCoreVersion;

  factory DeviceCapabilities.fromMap(Map<Object?, Object?> map) => DeviceCapabilities(
        sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
        hardwareH264: (map['hardwareH264'] as bool?) ?? false,
        hardwareHevc: (map['hardwareHevc'] as bool?) ?? false,
        nativeCoreReady: (map['nativeCoreReady'] as bool?) ?? false,
        abi: (map['abi'] as String?) ?? 'unknown',
        nativeCoreVersion: map['nativeCoreVersion'] as String?,
      );
}

/// Result of the *real* export planner in C++ (`sf_quality.cpp`).
class ExportPlanDto {
  const ExportPlanDto({
    required this.ok,
    required this.width,
    required this.height,
    required this.fps,
    required this.videoBitrateBps,
    required this.audioBitrateBps,
    required this.codec,
    required this.reencode,
    required this.passthroughVideo,
    required this.passthroughAudio,
    required this.hardwareEncoder,
    required this.hdr,
    required this.keyframeInterval,
    required this.estimatedBytes,
    required this.warnings,
    this.errorCode,
  });

  final bool ok;
  final int width;
  final int height;
  final double fps;
  final int videoBitrateBps;
  final int audioBitrateBps;
  final String codec;
  final bool reencode;
  final bool passthroughVideo;
  final bool passthroughAudio;
  final bool hardwareEncoder;
  final bool hdr;
  final int keyframeInterval;
  final int estimatedBytes;
  final List<String> warnings;
  final String? errorCode;

  factory ExportPlanDto.fromJson(Map<String, Object?> json) => ExportPlanDto(
        ok: (json['ok'] as bool?) ?? false,
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
        fps: (json['fps'] as num?)?.toDouble() ?? 0,
        videoBitrateBps: (json['videoBitrate'] as num?)?.toInt() ?? 0,
        audioBitrateBps: (json['audioBitrate'] as num?)?.toInt() ?? 0,
        codec: (json['codec'] as String?) ?? 'h264',
        reencode: (json['reencode'] as bool?) ?? true,
        passthroughVideo: (json['passthroughVideo'] as bool?) ?? false,
        passthroughAudio: (json['passthroughAudio'] as bool?) ?? false,
        hardwareEncoder: (json['hardwareEncoder'] as bool?) ?? false,
        hdr: (json['hdr'] as bool?) ?? false,
        keyframeInterval: (json['keyframeInterval'] as num?)?.toInt() ?? 0,
        estimatedBytes: (json['estimatedBytes'] as num?)?.toInt() ?? 0,
        warnings: (json['warnings'] as List<Object?>? ?? const <Object?>[])
            .map((Object? e) => e?.toString() ?? '')
            .where((String e) => e.isNotEmpty)
            .toList(growable: false),
        errorCode: json['errorCode'] as String?,
      );
}
