/// Probe result for the imported video. Field names mirror `video_assets`.
class VideoAsset {
  const VideoAsset({
    required this.id,
    required this.projectId,
    required this.uri,
    required this.displayName,
    required this.sizeBytes,
    required this.durationUs,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.fpsMilli,
    required this.bitrateBps,
    required this.videoCodec,
    required this.colorTransfer,
    required this.hdr,
    required this.audioCodec,
    required this.audioSampleRate,
    required this.audioChannels,
    required this.audioBitrateBps,
    required this.importedAtMs,
    this.probeJson,
    this.isMissing = false,
  });

  final String id;
  final String projectId;
  final String uri;
  final String displayName;
  final int sizeBytes;
  final int durationUs;
  final int width;
  final int height;
  final int rotationDegrees;

  /// Frame rate stored as milli-fps (29970 == 29.97 fps) so 23.976/29.97 survive.
  final int fpsMilli;
  final int bitrateBps;
  final String? videoCodec;
  final String? colorTransfer;
  final bool hdr;
  final String? audioCodec;
  final int audioSampleRate;
  final int audioChannels;
  final int audioBitrateBps;
  final int importedAtMs;
  final String? probeJson;
  final bool isMissing;

  double get fps => fpsMilli / 1000.0;
  int get shortEdge => width < height ? width : height;
  int get longEdge => width < height ? height : width;
  bool get isPortrait => height > width;
  String get resolutionLabel => '$width×$height';
  String get fpsLabel => fpsMilli % 1000 == 0
      ? fps.round().toString()
      : fps.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
  String get sizeLabel {
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    double value = sizeBytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  factory VideoAsset.fromMap(Map<String, Object?> map) => VideoAsset(
        id: map['id']! as String,
        projectId: map['project_id']! as String,
        uri: map['uri']! as String,
        displayName: map['display_name']! as String,
        sizeBytes: (map['size_bytes'] as int?) ?? 0,
        durationUs: (map['duration_us'] as int?) ?? 0,
        width: (map['width'] as int?) ?? 0,
        height: (map['height'] as int?) ?? 0,
        rotationDegrees: (map['rotation_degrees'] as int?) ?? 0,
        fpsMilli: (map['fps_milli'] as int?) ?? 0,
        bitrateBps: (map['bitrate_bps'] as int?) ?? 0,
        videoCodec: map['video_codec'] as String?,
        colorTransfer: map['color_transfer'] as String?,
        hdr: ((map['hdr'] as int?) ?? 0) == 1,
        audioCodec: map['audio_codec'] as String?,
        audioSampleRate: (map['audio_sample_rate'] as int?) ?? 0,
        audioChannels: (map['audio_channels'] as int?) ?? 0,
        audioBitrateBps: (map['audio_bitrate_bps'] as int?) ?? 0,
        importedAtMs: map['imported_at_ms']! as int,
        probeJson: map['probe_json'] as String?,
        isMissing: ((map['is_missing'] as int?) ?? 0) == 1,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'project_id': projectId,
        'uri': uri,
        'display_name': displayName,
        'size_bytes': sizeBytes,
        'duration_us': durationUs,
        'width': width,
        'height': height,
        'rotation_degrees': rotationDegrees,
        'fps_milli': fpsMilli,
        'bitrate_bps': bitrateBps,
        'video_codec': videoCodec,
        'color_transfer': colorTransfer,
        'hdr': hdr ? 1 : 0,
        'audio_codec': audioCodec,
        'audio_sample_rate': audioSampleRate,
        'audio_channels': audioChannels,
        'audio_bitrate_bps': audioBitrateBps,
        'probe_json': probeJson,
        'is_missing': isMissing ? 1 : 0,
        'imported_at_ms': importedAtMs,
      };

  VideoAsset copyWith({bool? isMissing}) => VideoAsset(
        id: id,
        projectId: projectId,
        uri: uri,
        displayName: displayName,
        sizeBytes: sizeBytes,
        durationUs: durationUs,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        fpsMilli: fpsMilli,
        bitrateBps: bitrateBps,
        videoCodec: videoCodec,
        colorTransfer: colorTransfer,
        hdr: hdr,
        audioCodec: audioCodec,
        audioSampleRate: audioSampleRate,
        audioChannels: audioChannels,
        audioBitrateBps: audioBitrateBps,
        importedAtMs: importedAtMs,
        probeJson: probeJson,
        isMissing: isMissing ?? this.isMissing,
      );
}
