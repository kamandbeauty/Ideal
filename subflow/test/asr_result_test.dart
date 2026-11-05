import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/services/asr_service.dart';

/// The native layer answers with JSON, so the parsing rules are the contract
/// between C++/Kotlin and the editor: a refusal must stay a refusal, and a
/// half-formed payload must never turn into "0 subtitles, no error".
void main() {
  group('AsrResult.fromJson', () {
    test('reads segments in order', () {
      final String payload = jsonEncode(<String, Object?>{
        'ok': true,
        'segments': <Object?>[
          <Object?>[0, 1500000, ' سلام دنیا '],
          <Object?>[1600000, 3000000, 'خداحافظ'],
        ],
      });
      final AsrResult result = AsrResult.fromJson(payload);
      expect(result.ok, isTrue);
      expect(result.segments.length, 2);
      expect(result.segments.first.text, 'سلام دنیا');
      expect(result.segments.first.startUs, 0);
      expect(result.segments.last.endUs, 3000000);
      expect(result.segments.last.duration, const Duration(milliseconds: 1400));
    });

    test('keeps the native error message', () {
      final AsrResult result = AsrResult.fromJson(
        jsonEncode(<String, Object?>{'ok': false, 'error': 'فایل مدل پیدا نشد.'}),
      );
      expect(result.ok, isFalse);
      expect(result.segments, isEmpty);
      expect(result.error, 'فایل مدل پیدا نشد.');
    });

    test('drops zero-length and blank segments', () {
      final String payload = jsonEncode(<String, Object?>{
        'ok': true,
        'segments': <Object?>[
          <Object?>[1000, 1000, 'صفر'],
          <Object?>[2000, 3000, '   '],
          <Object?>[4000, 5000, 'واقعی'],
        ],
      });
      final AsrResult result = AsrResult.fromJson(payload);
      expect(result.ok, isTrue);
      expect(result.segments.length, 1);
      expect(result.segments.single.text, 'واقعی');
    });

    test('a payload with no usable segments is a failure, not an empty success', () {
      final AsrResult result = AsrResult.fromJson(
        jsonEncode(<String, Object?>{'ok': true, 'segments': <Object?>[]}),
      );
      expect(result.ok, isFalse);
      expect(result.error, isNotNull);
    });

    test('malformed json is reported instead of thrown', () {
      final AsrResult result = AsrResult.fromJson('not json at all');
      expect(result.ok, isFalse);
      expect(result.error, 'not json at all');
    });

    test('a non-object json value is a failure', () {
      final AsrResult result = AsrResult.fromJson('[1,2,3]');
      expect(result.ok, isFalse);
    });
  });

  group('AsrModel', () {
    test('formats sizes for the picker', () {
      final AsrModel? model = AsrModel.fromMap(<Object?, Object?>{
        'id': 'ggml-base',
        'label': 'ggml-base',
        'path': '/data/user/0/app.subflow/files/models/whisper/ggml-base.bin',
        'sizeBytes': 147951465,
      });
      expect(model, isNotNull);
      expect(model!.sizeLabel, '141 MB');
    });

    test('falls back to the file name when no label is given', () {
      final AsrModel? model = AsrModel.fromMap(<Object?, Object?>{
        'path': '/models/ggml-small-q5_1.bin',
        'sizeBytes': 0,
      });
      expect(model, isNotNull);
      expect(model!.label, 'ggml-small-q5_1.bin');
    });

    test('rejects a map without a path', () {
      expect(AsrModel.fromMap(<Object?, Object?>{'id': 'x'}), isNull);
      expect(AsrModel.fromMap(null), isNull);
      expect(AsrModel.fromMap('a string'), isNull);
    });
  });

  group('AsrCapabilities', () {
    test('reads the native capability map', () {
      final AsrCapabilities caps = AsrCapabilities.fromMap(<Object?, Object?>{
        'available': true,
        'engineReady': false,
        'cores': 8,
        'recommendedThreads': 4,
      });
      expect(caps.available, isTrue);
      expect(caps.engineReady, isFalse);
      expect(caps.cores, 8);
      expect(caps.recommendedThreads, 4);
    });

    test('defaults are conservative when keys are missing', () {
      final AsrCapabilities caps = AsrCapabilities.fromMap(<Object?, Object?>{});
      expect(caps.available, isFalse);
      expect(caps.recommendedThreads, 2);
      expect(AsrCapabilities.unavailable.available, isFalse);
    });
  });
}
