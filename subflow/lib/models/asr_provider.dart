import '../database/dao/settings_dao.dart';

/// Where transcription happens.
///
/// [onDevice] is the default: whisper.cpp on the phone, no account, no upload.
/// [cloud] sends the extracted audio to an OpenAI-compatible endpoint for the
/// accuracy of a large hosted model, and is opt-in only.
enum AsrProviderMode { onDevice, cloud }

/// A service that speaks the OpenAI `/audio/transcriptions` dialect.
class AsrCloudPreset {
  const AsrCloudPreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.model,
    required this.note,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String model;
  final String note;

  static const AsrCloudPreset groq = AsrCloudPreset(
    id: 'groq',
    label: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    model: 'whisper-large-v3',
    note: 'سریع و دقیق، مدل large-v3، سطح رایگان هم دارد',
  );

  static const AsrCloudPreset openai = AsrCloudPreset(
    id: 'openai',
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    model: 'whisper-1',
    note: 'whisper-1 با زمان‌بندی جمله‌ها؛ کیفیت خوب، هزینهٔ پرداختی',
  );

  static const AsrCloudPreset custom = AsrCloudPreset(
    id: 'custom',
    label: 'دلخواه',
    baseUrl: '',
    model: '',
    note: 'هر سرویسی که با OpenAI سازگار است',
  );

  static const List<AsrCloudPreset> all = <AsrCloudPreset>[groq, openai, custom];

  static AsrCloudPreset byId(String id) {
    for (final AsrCloudPreset preset in all) {
      if (preset.id == id) return preset;
    }
    return custom;
  }
}

/// Saved online-transcription settings.
class AsrCloudConfig {
  const AsrCloudConfig({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    this.presetId = 'groq',
  });

  final String baseUrl;
  final String model;
  final String apiKey;
  final String presetId;

  static const AsrCloudConfig empty = AsrCloudConfig(baseUrl: '', model: '', apiKey: '');

  /// True when a transcription could actually be attempted.
  bool get ready => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  String get host {
    final Uri? uri = Uri.tryParse(baseUrl.trim());
    return uri?.host.isNotEmpty == true ? uri!.host : baseUrl.trim();
  }

  /// Never show the whole key: screenshots and screen shares are common.
  String get maskedKey {
    final String key = apiKey.trim();
    if (key.isEmpty) return '';
    if (key.length <= 8) return '••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  AsrCloudConfig copyWith({String? baseUrl, String? model, String? apiKey, String? presetId}) {
    return AsrCloudConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      presetId: presetId ?? this.presetId,
    );
  }

  static AsrCloudConfig fromMap(Map<String, String?> map) {
    return AsrCloudConfig(
      baseUrl: map[CloudAsrKeys.baseUrl] ?? '',
      model: map[CloudAsrKeys.model] ?? '',
      apiKey: map[CloudAsrKeys.apiKey] ?? '',
      presetId: map[CloudAsrKeys.preset] ?? AsrCloudPreset.groq.id,
    );
  }

  Map<String, String> toMap() {
    return <String, String>{
      CloudAsrKeys.baseUrl: baseUrl.trim(),
      CloudAsrKeys.model: model.trim(),
      CloudAsrKeys.apiKey: apiKey.trim(),
      CloudAsrKeys.preset: presetId,
    };
  }
}

/// Setting keys owned by the online provider, kept next to its model so the
/// three strings cannot drift apart.
class CloudAsrKeys {
  const CloudAsrKeys._();

  static const String provider = 'asr_provider';
  static const String baseUrl = 'asr_cloud_base_url';
  static const String model = 'asr_cloud_model';
  static const String apiKey = 'asr_cloud_api_key';
  static const String preset = 'asr_cloud_preset';

  static const List<String> all = <String>[provider, baseUrl, model, apiKey, preset];
}

/// Reads and writes the provider choice + credentials.
class AsrSettingsStore {
  const AsrSettingsStore(this._dao);

  final SettingsDao _dao;

  Future<AsrProviderMode> mode() async {
    final String? raw = await _dao.get(CloudAsrKeys.provider);
    return raw == 'cloud' ? AsrProviderMode.cloud : AsrProviderMode.onDevice;
  }

  Future<void> setMode(AsrProviderMode mode) => _dao.set(
        CloudAsrKeys.provider,
        mode == AsrProviderMode.cloud ? 'cloud' : 'ondevice',
      );

  Future<AsrCloudConfig> cloudConfig() async {
    final Map<String, String?> values = <String, String?>{};
    for (final String key in <String>[
      CloudAsrKeys.baseUrl,
      CloudAsrKeys.model,
      CloudAsrKeys.apiKey,
      CloudAsrKeys.preset,
    ]) {
      values[key] = await _dao.get(key);
    }
    return AsrCloudConfig.fromMap(values);
  }

  Future<void> saveCloudConfig(AsrCloudConfig config) async {
    for (final MapEntry<String, String> entry in config.toMap().entries) {
      await _dao.set(entry.key, entry.value);
    }
  }
}
