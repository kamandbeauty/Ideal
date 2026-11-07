import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/models/asr_provider.dart';

void main() {
  group('AsrCloudConfig', () {
    test('is not ready until url, model and key are all present', () {
      const AsrCloudConfig config = AsrCloudConfig.empty;
      expect(config.ready, isFalse);
      expect(config.copyWith(baseUrl: 'https://api.groq.com/openai/v1').ready, isFalse);
      expect(
        config
            .copyWith(baseUrl: 'https://api.groq.com/openai/v1', model: 'whisper-large-v3')
            .ready,
        isFalse,
      );
      expect(
        config
            .copyWith(
              baseUrl: 'https://api.groq.com/openai/v1',
              model: 'whisper-large-v3',
              apiKey: 'gsk_test',
            )
            .ready,
        isTrue,
      );
    });

    test('trims whitespace when persisting and never exposes the whole key', () {
      const AsrCloudConfig config = AsrCloudConfig(
        baseUrl: '  https://api.openai.com/v1  ',
        model: ' whisper-1 ',
        apiKey: ' sk-abcdefghijklmnop ',
      );
      expect(config.toMap()[CloudAsrKeys.baseUrl], 'https://api.openai.com/v1');
      expect(config.toMap()[CloudAsrKeys.model], 'whisper-1');
      expect(config.maskedKey, 'sk-a••••mnop');
      expect(config.maskedKey.contains('abcdefghij'), isFalse);
      expect(config.host, 'api.openai.com');
    });

    test('round-trips through the settings map', () {
      const AsrCloudConfig config = AsrCloudConfig(
        baseUrl: 'https://api.groq.com/openai/v1',
        model: 'whisper-large-v3',
        apiKey: 'gsk_1234567890',
        presetId: 'groq',
      );
      final AsrCloudConfig restored =
          AsrCloudConfig.fromMap(<String, String?>{...config.toMap()});
      expect(restored.baseUrl, config.baseUrl);
      expect(restored.model, config.model);
      expect(restored.apiKey, config.apiKey);
      expect(restored.presetId, AsrCloudPreset.groq.id);
      expect(restored.ready, isTrue);
    });

    test('an unknown preset falls back to custom instead of throwing', () {
      expect(AsrCloudPreset.byId('nope').id, AsrCloudPreset.custom.id);
      expect(AsrCloudConfig.fromMap(<String, String?>{}).presetId, AsrCloudPreset.groq.id);
    });
  });

  group('AsrCloudPreset', () {
    test('presets point at OpenAI-compatible endpoints', () {
      for (final AsrCloudPreset preset in AsrCloudPreset.all) {
        if (preset == AsrCloudPreset.custom) continue;
        expect(preset.baseUrl, startsWith('https://'));
        expect(preset.baseUrl, endsWith('/v1'));
        expect(preset.model, isNotEmpty);
      }
    });
  });
}
