import 'enums.dart';

/// A downloadable offline model (whisper.cpp GGML/GGUF weights, translation
/// engine weights, ...). Downloaded separately so the APK stays small, and the
/// checksum is verified before the model can be selected.
class AiModel {
  const AiModel({
    required this.id,
    required this.kind,
    required this.variant,
    required this.displayName,
    required this.languageSupport,
    required this.sizeBytes,
    required this.state,
    this.filePath,
    this.sha256,
    this.license,
    this.downloadedBytes = 0,
    this.isDefault = false,
    this.installedAtMs,
  });

  final String id;
  final ModelKind kind;
  final String variant;
  final String displayName;
  final String languageSupport;
  final int sizeBytes;
  final String? filePath;
  final String? sha256;
  final String? license;
  final ModelState state;
  final int downloadedBytes;
  final bool isDefault;
  final int? installedAtMs;

  bool get isInstalled => state == ModelState.installed;
  String get sizeLabel => '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  /// Real download progress only - derived from bytes actually written.
  double get progress =>
      sizeBytes <= 0 ? 0 : (downloadedBytes / sizeBytes).clamp(0.0, 1.0).toDouble();

  factory AiModel.fromMap(Map<String, Object?> map) => AiModel(
        id: map['id']! as String,
        kind: ModelKind.fromDb(map['kind'] as String?),
        variant: map['variant']! as String,
        displayName: map['display_name']! as String,
        languageSupport: (map['language_support'] as String?) ?? 'multi',
        sizeBytes: (map['size_bytes'] as int?) ?? 0,
        filePath: map['file_path'] as String?,
        sha256: map['sha256'] as String?,
        license: map['license'] as String?,
        state: ModelState.fromDb(map['state'] as String?),
        downloadedBytes: (map['downloaded_bytes'] as int?) ?? 0,
        isDefault: ((map['is_default'] as int?) ?? 0) == 1,
        installedAtMs: map['installed_at_ms'] as int?,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'kind': kind.dbValue,
        'variant': variant,
        'display_name': displayName,
        'language_support': languageSupport,
        'file_path': filePath,
        'size_bytes': sizeBytes,
        'sha256': sha256,
        'license': license,
        'state': state.dbValue,
        'downloaded_bytes': downloadedBytes,
        'is_default': isDefault ? 1 : 0,
        'installed_at_ms': installedAtMs,
      };

  AiModel copyWith({ModelState? state, int? downloadedBytes, String? filePath, bool? isDefault}) {
    return AiModel(
      id: id,
      kind: kind,
      variant: variant,
      displayName: displayName,
      languageSupport: languageSupport,
      sizeBytes: sizeBytes,
      filePath: filePath ?? this.filePath,
      sha256: sha256,
      license: license,
      state: state ?? this.state,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      isDefault: isDefault ?? this.isDefault,
      installedAtMs: installedAtMs,
    );
  }
}
