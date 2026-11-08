/// Product-wide constants. Everything that other layers must agree on lives
/// here so a rename cannot silently desynchronise Dart, Kotlin and C++.
class SubFlowInfo {
  const SubFlowInfo._();

  static const String appName = 'SubFlow';
  static const String tagline = 'Professional Offline AI Subtitle & Video Editor';
  static const String databaseName = 'subflow.db';
  static const String databaseDir = 'databases';
  static const String migrationManifestAsset = 'assets/db/manifest.json';
  static const int minAndroidApi = 26;

  /// Projects live in app-private storage; the original video is *never* copied
  /// or modified, only referenced through its content URI.
  static const String projectsDirName = 'projects';
  static const String modelsDirName = 'models';
  static const String exportsDirName = 'exports';
}

/// Method/event channel names. Each player instance gets its own channel so two
/// previews can never fight over the same player state.
class Channels {
  const Channels._();

  static const String native = 'app.subflow/native';
  static const String playerViewType = 'app.subflow/player_view';
  static const String playerEventPrefix = 'app.subflow/player';
  static String player(int viewId) => '$playerEventPrefix/$viewId';

  /// Progress of a long Whisper run (0..100). Separate from the method channel
  /// so one slow transcription cannot delay ordinary calls.
  static const String asrEvents = 'app.subflow/asr';
}

/// Keys of the `app_settings` table (no SharedPreferences: one storage story).
class SettingKeys {
  const SettingKeys._();

  static const String locale = 'app_locale';
  static const String defaultWhisperModel = 'default_whisper_model';
  static const String defaultTranslationModel = 'default_translation_model';
  static const String preferHardwareEncoder = 'prefer_hardware_encoder';
  static const String preferredCodec = 'preferred_codec';
  static const String lastExportPreset = 'last_export_preset';
}

/// Native method names, mirrored 1:1 in `SubFlowBridge.kt`.
class NativeMethods {
  const NativeMethods._();

  static const String pickVideo = 'media.pickVideo';
  static const String probeVideo = 'media.probe';
  static const String thumbnail = 'media.thumbnail';
  static const String waveform = 'media.waveform';
  static const String fileExists = 'media.fileExists';
  static const String capabilities = 'device.capabilities';
  static const String writeSrt = 'subtitle.writeSrt';
  static const String writeAss = 'subtitle.writeAss';
  static const String planExport = 'export.plan';
  static const String asrCapabilities = 'asr.capabilities';
  static const String asrListModels = 'asr.listModels';
  static const String asrImportModel = 'asr.importModel';
  static const String asrDeleteModel = 'asr.deleteModel';
  static const String asrTranscribe = 'asr.transcribe';
  static const String asrCancel = 'asr.cancel';
  static const String asrCatalog = 'asr.catalog';
  static const String asrDownloadModel = 'asr.downloadModel';
  static const String asrSelfTest = 'asr.selfTest';
  static const String asrCloudTranscribe = 'asr.cloudTranscribe';
  static const String asrCloudCheck = 'asr.cloudCheck';
}
