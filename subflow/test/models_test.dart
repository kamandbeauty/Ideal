import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/models/enums.dart';
import 'package:subflow/models/project.dart';
import 'package:subflow/models/subtitle.dart';
import 'package:subflow/models/subtitle_style.dart';
import 'package:subflow/models/video_asset.dart';
import 'package:subflow/models/watermark.dart';

/// Every model must round-trip through its SQLite map without losing data.
/// A silent field drop here would corrupt a saved project.
void main() {
  test('Project round-trips through its map', () {
    final Project project = Project(
      id: 'p1',
      name: 'پروژه فارسی',
      status: ProjectStatus.transcribing,
      createdAtMs: 1700000000000,
      updatedAtMs: 1700000001000,
      lastOpenedAtMs: 1700000002000,
    );
    final Project copy = Project.fromMap(project.toMap());
    expect(copy.name, project.name);
    expect(copy.status, ProjectStatus.transcribing);
    expect(copy.updatedAtMs, project.updatedAtMs);
    expect(copy.toMap().keys, project.toMap().keys);
  });

  test('VideoAsset keeps sub-1000 fps precision', () {
    final VideoAsset asset = VideoAsset.fromMap(<String, Object?>{
      'id': 'v1',
      'project_id': 'p1',
      'uri': 'content://media/1',
      'display_name': 'clip.mp4',
      'size_bytes': 1024,
      'duration_us': 60000000,
      'width': 1920,
      'height': 1080,
      'rotation_degrees': 0,
      'fps_milli': 29970,
      'bitrate_bps': 8000000,
      'video_codec': 'H.264',
      'color_transfer': 'SDR_BT709',
      'hdr': 0,
      'audio_codec': 'AAC',
      'audio_sample_rate': 48000,
      'audio_channels': 2,
      'audio_bitrate_bps': 128000,
      'imported_at_ms': 1,
      'is_missing': 0,
    });
    expect(asset.fps, 29.97);
    expect(asset.fpsLabel, '29.97');
    expect(asset.isPortrait, isFalse);
    expect(asset.shortEdge, 1080);
  });

  test('SubtitleSegment rejects impossible durations at the model level', () {
    final SubtitleSegment segment = SubtitleSegment(
      id: 's1',
      trackId: 't1',
      ordinal: 0,
      startUs: 500000,
      endUs: 2250000,
      text: 'سلام (SubFlow)',
      source: SubtitleSource.whisper,
      createdAtMs: 0,
      updatedAtMs: 0,
    );
    expect(segment.durationUs, 1750000);
    final SubtitleSegment copy = SubtitleSegment.fromMap(segment.toMap());
    expect(copy.text, segment.text);
    expect(copy.source, SubtitleSource.whisper);
  });

  test('SubtitleStyle survives a full parameter round-trip', () {
    const SubtitleStyle style = SubtitleStyle.fallback;
    final Map<String, Object?> map = style.toMap();
    final SubtitleStyle copy = SubtitleStyle.fromMap(map);
    expect(copy.fontFamily, 'Vazirmatn');
    expect(copy.positionY, style.positionY);
    expect(copy.align, CaptionAlign.center);
    expect(copy.direction, CaptionDirection.auto);
  });

  test('Watermark fade maths produce a real ramp', () {
    const Watermark watermark = Watermark(
      id: 'w1',
      projectId: 'p1',
      kind: 'text',
      payload: '@subflow',
      opacity: 1,
      startUs: 1000000,
      endUs: 5000000,
      fadeInUs: 500000,
      fadeOutUs: 500000,
      createdAtMs: 0,
      updatedAtMs: 0,
    );
    expect(watermark.opacityAt(500000), 0);
    expect(watermark.opacityAt(1250000), closeTo(0.5, 0.001));
    expect(watermark.opacityAt(3000000), 1);
    expect(watermark.opacityAt(4750000), closeTo(0.5, 0.001));
    expect(watermark.opacityAt(6000000), 0);
  });

  test('enum db values match the SQL CHECK constraints', () {
    expect(ModelState.notInstalled.dbValue, 'not_installed');
    expect(ExportMode.renderedVideo.dbValue, 'rendered_video');
    expect(ProjectStatus.fromDb('exporting'), ProjectStatus.exporting);
    expect(ProjectStatus.fromDb('nonsense'), ProjectStatus.draft);
  });
}
