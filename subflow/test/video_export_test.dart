import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/features/subtitles/subtitle_document.dart';
import 'package:subflow/models/enums.dart';
import 'package:subflow/models/subtitle.dart';
import 'package:subflow/services/video_export_service.dart';

/// The render path's contract with the native painter: cues, word timings and
/// the human-readable result numbers. Everything here runs without a platform,
/// which is exactly why it is worth testing - a shape change in these maps is
/// silent at runtime (the exporter just draws the wrong thing) and visible here.
void main() {
  SubtitleWord word(int ordinal, int startUs, int endUs, String text) => SubtitleWord(
        id: 'w$ordinal',
        segmentId: 'seg',
        ordinal: ordinal,
        startUs: startUs,
        endUs: endUs,
        text: text,
      );

  SubtitleSegment segment({
    required int startUs,
    required int endUs,
    required String text,
    List<SubtitleWord> words = const <SubtitleWord>[],
  }) =>
      SubtitleSegment(
        id: 'seg',
        trackId: 'track',
        ordinal: 0,
        startUs: startUs,
        endUs: endUs,
        text: text,
        source: SubtitleSource.whisper,
        createdAtMs: 0,
        updatedAtMs: 0,
        words: words,
      );

  group('cue mapping', () {
    test('maps every segment with its word timings', () {
      final SubtitleDocument document = SubtitleDocument(
        trackId: 'track',
        segments: <SubtitleSegment>[
          segment(
            startUs: 0,
            endUs: 2000000,
            text: 'سلام دنیا',
            words: <SubtitleWord>[word(0, 0, 800000, 'سلام'), word(1, 800000, 1600000, 'دنیا')],
          ),
          segment(startUs: 2500000, endUs: 4000000, text: 'خط دوم'),
        ],
      );

      final List<Map<String, Object?>> cues = VideoExportService.cuesOf(document);

      expect(cues.length, 2);
      expect(cues.first['startUs'], 0);
      expect(cues.first['endUs'], 2000000);
      expect(cues.first['text'], 'سلام دنیا');
      final List<Object?> words = cues.first['words']! as List<Object?>;
      expect(words.length, 2);
      expect((words.first as Map<String, Object?>)['text'], 'سلام');
      expect((words.last as Map<String, Object?>)['endUs'], 1600000);
      expect((cues.last['words']! as List<Object?>), isEmpty);
    });

    test('an empty document produces no cues', () {
      expect(VideoExportService.cuesOf(SubtitleDocument.empty('track')), isEmpty);
    });
  });

  group('quality', () {
    test('every quality is a real short edge with a Persian label', () {
      for (final RenderQuality quality in RenderQuality.values) {
        expect(quality.shortEdge, greaterThanOrEqualTo(480));
        expect(quality.label, isNotEmpty);
        expect(quality.hint, isNotEmpty);
      }
      expect(
        RenderQuality.values.map((RenderQuality q) => q.shortEdge).toSet(),
        <int>{1080, 720, 480},
      );
    });
  });

  group('result formatting', () {
    test('reports size, resolution and duration the user can read', () {
      const VideoRenderResult result = VideoRenderResult(
        path: '/tmp/subflow-demo.mp4',
        bytes: 5 * 1024 * 1024,
        width: 1080,
        height: 1920,
        durationUs: 95000000,
      );

      expect(result.fileName, 'subflow-demo.mp4');
      expect(result.resolution, '1080×1920');
      expect(result.sizeLabel, '5.0 مگابایت');
      expect(result.durationLabel, '1:35');
    });

    test('small files stay in kilobytes', () {
      const VideoRenderResult result = VideoRenderResult(
        path: '/tmp/a.mp4',
        bytes: 2048,
        width: 480,
        height: 854,
        durationUs: 3000000,
      );
      expect(result.sizeLabel, '2 کیلوبایت');
      expect(result.durationLabel, '0:03');
    });
  });
}
