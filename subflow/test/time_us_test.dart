import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/core/time_us.dart';

/// Timestamp arithmetic is the backbone of subtitle sync: these tests pin the
/// exact string formats that SRT/ASS consumers expect.
void main() {
  group('TimeUs formatting', () {
    test('SRT timecode uses a comma and zero padding', () {
      expect(TimeUs.srt(0), '00:00:00,000');
      expect(TimeUs.srt(1500000), '00:00:01,500');
      expect(TimeUs.srt(3723456789), '01:02:03,456');
    });

    test('negative timestamps clamp to zero instead of wrapping', () {
      expect(TimeUs.srt(-5000), '00:00:00,000');
      expect(TimeUs.clock(-1), '00:00');
    });

    test('clock and precise views agree on seconds', () {
      expect(TimeUs.clock(65000000), '01:05');
      expect(TimeUs.precise(65432100), '01:05.432');
    });

    test('rounding never accumulates drift at 29.97 fps', () {
      // 300 frames at 29.97 fps is almost exactly 10.01 s.
      int total = 0;
      for (int i = 0; i < 300; i++) {
        total += TimeUs.fromFrames(1, 29.97);
      }
      expect((total / TimeUs.perSecond - 10.01).abs() < 0.001, isTrue);
    });

    test('human duration is Persian and plural-free', () {
      expect(TimeUs.humanDuration(45000000), '45 ثانیه');
      expect(TimeUs.humanDuration(130000000), '2 دقیقه و 10 ثانیه');
      expect(TimeUs.humanDuration(3700000000), '1 ساعت و 1 دقیقه');
    });
  });

  group('TimeUs parsing helpers', () {
    test('fromMilliseconds rounds half away from zero', () {
      expect(TimeUs.fromMilliseconds(29.97), 29970);
      expect(TimeUs.fromMilliseconds(0.5), 500);
      expect(TimeUs.fromSeconds(1.0005), 1000500);
    });

    test('clamp keeps values inside the timeline', () {
      expect(TimeUs.clamp(-10, 0, 100), 0);
      expect(TimeUs.clamp(150, 0, 100), 100);
      expect(TimeUs.clamp(50, 0, 100), 50);
    });
  });
}
