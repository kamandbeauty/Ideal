import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../models/asr_provider.dart';

/// One installed Whisper model (a ggml `.bin` copied into app storage).
class AsrModel {
  const AsrModel({
    required this.id,
    required this.label,
    required this.path,
    required this.sizeBytes,
    this.builtin = false,
  });

  final String id;
  final String label;
  final String path;
  final int sizeBytes;

  /// Shipped inside the APK: always present, cannot be deleted.
  final bool builtin;

  String get sizeLabel {
    final double mb = sizeBytes / (1024 * 1024);
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(0)} MB';
  }

  static AsrModel? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final Object? path = raw['path'];
    if (path is! String || path.isEmpty) return null;
    final Object? size = raw['sizeBytes'];
    return AsrModel(
      id: '${raw['id'] ?? path}',
      label: '${raw['label'] ?? raw['id'] ?? path.split('/').last}',
      path: path,
      sizeBytes: size is num ? size.toInt() : 0,
      builtin: raw['builtin'] == true,
    );
  }
}

/// A model the app can fetch in one tap. Whisper weights are far too large to
/// bundle, so the download is explicit, visible and cancellable.
class AsrCatalogEntry {
  const AsrCatalogEntry({
    required this.id,
    required this.label,
    required this.detail,
    required this.approxBytes,
    required this.installed,
  });

  final String id;
  final String label;
  final String detail;
  final int approxBytes;
  final bool installed;

  String get sizeLabel => '${(approxBytes / (1024 * 1024)).round()} MB';

  static AsrCatalogEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final Object? id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final Object? size = raw['approxBytes'];
    return AsrCatalogEntry(
      id: id,
      label: '${raw['label'] ?? id}',
      detail: '${raw['detail'] ?? ''}',
      approxBytes: size is num ? size.toInt() : 0,
      installed: raw['installed'] == true,
    );
  }
}

/// Progress of a model download, in bytes.
class AsrDownloadProgress {
  const AsrDownloadProgress({required this.id, required this.received, required this.total});

  final String id;
  final int received;
  final int total;

  double get fraction => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0).toDouble();

  String get label {
    String mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(0);
    return '${mb(received)} / ${mb(total)} MB';
  }
}

/// What this install can actually do.
class AsrCapabilities {
  const AsrCapabilities({
    required this.available,
    required this.engineReady,
    required this.cores,
    required this.recommendedThreads,
    this.nativeError = '',
  });

  final bool available;
  final bool engineReady;
  final int cores;
  final int recommendedThreads;

  /// Why the native library (or the engine) is missing, when it is.
  final String nativeError;

  static const AsrCapabilities unavailable = AsrCapabilities(
    available: false,
    engineReady: false,
    cores: 0,
    recommendedThreads: 2,
  );

  static AsrCapabilities fromMap(Map<Object?, Object?> map) {
    int asInt(Object? value, int fallback) => value is num ? value.toInt() : fallback;
    return AsrCapabilities(
      available: map['available'] == true,
      engineReady: map['engineReady'] == true,
      cores: asInt(map['cores'], 0),
      recommendedThreads: asInt(map['recommendedThreads'], 2),
      nativeError: '${map['nativeError'] ?? ''}',
    );
  }
}

/// Outcome of a credential check against an online service.
class AsrCloudCheck {
  const AsrCloudCheck({required this.ok, this.error = '', this.models = const <String>[]});

  final bool ok;
  final String error;
  final List<String> models;
}

class AsrSegmentData {
  const AsrSegmentData({required this.startUs, required this.endUs, required this.text});

  final int startUs;
  final int endUs;
  final String text;

  Duration get duration => Duration(microseconds: endUs - startUs);
}

class AsrResult {
  const AsrResult({required this.ok, required this.segments, this.error});

  final bool ok;
  final List<AsrSegmentData> segments;
  final String? error;

  static const AsrResult failure = AsrResult(ok: false, segments: <AsrSegmentData>[]);

  /// Parses the native reply. Anything unexpected becomes a refusal with the raw
  /// payload as the message - never a silent empty transcript.
  static AsrResult fromJson(String payload) {
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return AsrResult(ok: false, segments: const <AsrSegmentData>[], error: payload);
      }
      if (decoded['ok'] != true) {
        final Object? error = decoded['error'];
        return AsrResult(
          ok: false,
          segments: const <AsrSegmentData>[],
          error: error is String ? error : 'تشخیص گفتار ناموفق بود.',
        );
      }
      final List<AsrSegmentData> segments = <AsrSegmentData>[];
      final Object? raw = decoded['segments'];
      if (raw is List) {
        for (final Object? entry in raw) {
          if (entry is! List || entry.length < 3) continue;
          final Object? start = entry[0];
          final Object? end = entry[1];
          final Object? text = entry[2];
          if (start is! num || end is! num || text is! String) continue;
          final int startUs = start.toInt();
          final int endUs = end.toInt();
          if (endUs <= startUs || text.trim().isEmpty) continue;
          segments.add(AsrSegmentData(startUs: startUs, endUs: endUs, text: text.trim()));
        }
      }
      if (segments.isEmpty) {
        return const AsrResult(
          ok: false,
          segments: <AsrSegmentData>[],
          error: 'گفتاری در این ویدئو شناخته نشد.',
        );
      }
      return AsrResult(ok: true, segments: segments);
    } on FormatException {
      return AsrResult(ok: false, segments: const <AsrSegmentData>[], error: payload);
    }
  }
}

/// Dart side of the offline Whisper pipeline (`app.subflow/native` +
/// `app.subflow/asr`).
///
/// The heavy lifting is in Kotlin/C++: this class only moves arguments, streams
/// progress, and turns the native JSON into typed results. A build without the
/// engine reports itself through [capabilities] instead of throwing.
class AsrService {
  AsrService({MethodChannel? channel, EventChannel? events})
      : _channel = channel ?? const MethodChannel(Channels.native),
        _events = events ?? const EventChannel(Channels.asrEvents);

  final MethodChannel _channel;
  final EventChannel _events;

  Future<AsrCapabilities> capabilities() async {
    try {
      final Map<Object?, Object?>? map =
          await _channel.invokeMapMethod<Object?, Object?>(NativeMethods.asrCapabilities);
      if (map == null) return AsrCapabilities.unavailable;
      return AsrCapabilities.fromMap(map);
    } on PlatformException {
      return AsrCapabilities.unavailable;
    } on MissingPluginException {
      return AsrCapabilities.unavailable;
    }
  }

  Future<List<AsrModel>> listModels() async {
    try {
      final List<Object?>? raw =
          await _channel.invokeListMethod<Object?>(NativeMethods.asrListModels);
      if (raw == null) return const <AsrModel>[];
      return raw
          .map(AsrModel.fromMap)
          .whereType<AsrModel>()
          .toList(growable: false);
    } on PlatformException {
      return const <AsrModel>[];
    } on MissingPluginException {
      return const <AsrModel>[];
    }
  }

  /// Opens the document picker and copies the chosen model into app storage.
  /// Returns `null` when the user backs out.
  Future<AsrModel?> importModel() async {
    final Map<Object?, Object?>? map =
        await _channel.invokeMapMethod<Object?, Object?>(NativeMethods.asrImportModel);
    return AsrModel.fromMap(map);
  }

  Future<List<AsrCatalogEntry>> catalog() async {
    try {
      final List<Object?>? raw =
          await _channel.invokeListMethod<Object?>(NativeMethods.asrCatalog);
      if (raw == null) return const <AsrCatalogEntry>[];
      return raw
          .map(AsrCatalogEntry.fromMap)
          .whereType<AsrCatalogEntry>()
          .toList(growable: false);
    } on PlatformException {
      return const <AsrCatalogEntry>[];
    } on MissingPluginException {
      return const <AsrCatalogEntry>[];
    }
  }

  /// Downloads one catalogue model, reporting byte progress as it arrives.
  /// Throws [PlatformException] with a user-facing message on failure.
  Future<AsrModel?> downloadModel(
    String id, {
    void Function(AsrDownloadProgress progress)? onProgress,
  }) async {
    StreamSubscription<dynamic>? subscription;
    if (onProgress != null) {
      subscription = _events.receiveBroadcastStream().listen((dynamic event) {
        if (event is! Map || event['event'] != 'download' || event['id'] != id) return;
        final Object? received = event['received'];
        final Object? total = event['total'];
        if (received is! num) return;
        onProgress(AsrDownloadProgress(
          id: id,
          received: received.toInt(),
          total: total is num ? total.toInt() : 0,
        ));
      });
    }
    try {
      final Map<Object?, Object?>? map = await _channel.invokeMapMethod<Object?, Object?>(
        NativeMethods.asrDownloadModel,
        <String, Object?>{'id': id},
      );
      return AsrModel.fromMap(map);
    } finally {
      await subscription?.cancel();
    }
  }

  /// Runs every stage of the pipeline on the project's own audio and returns the
  /// raw report, so a failure can be located instead of guessed at.
  Future<Map<String, Object?>> selfTest({
    String? uri,
    String? modelPath,
    String language = 'fa',
    int durationUs = 0,
  }) async {
    final Map<Object?, Object?>? raw = await _channel.invokeMapMethod<Object?, Object?>(
      NativeMethods.asrSelfTest,
      <String, Object?>{
        'uri': uri,
        'modelPath': modelPath,
        'language': language,
        'durationUs': durationUs,
      },
    );
    if (raw == null) return const <String, Object?>{};
    return raw.map((Object? key, Object? value) => MapEntry<String, Object?>('$key', value));
  }

  /// Uploads the project's audio to an OpenAI-compatible endpoint.
  ///
  /// The reply is normalised in Kotlin to the same JSON the native engine
  /// returns, so [AsrResult] parses both without knowing the difference.
  Future<AsrResult> transcribeCloud({
    required String uri,
    required AsrCloudConfig config,
    required String language,
    required int durationUs,
    bool translate = false,
    void Function(int value)? onProgress,
  }) async {
    StreamSubscription<dynamic>? subscription;
    if (onProgress != null) {
      subscription = _events.receiveBroadcastStream().listen((dynamic event) {
        if (event is Map && event['event'] == 'cloud-progress') {
          final Object? value = event['progress'];
          if (value is num) onProgress(value.toInt());
        }
      });
    }
    try {
      final String? payload = await _channel.invokeMethod<String>(
        NativeMethods.asrCloudTranscribe,
        <String, Object?>{
          'uri': uri,
          'baseUrl': config.baseUrl,
          'apiKey': config.apiKey,
          'model': config.model,
          'language': language,
          'durationUs': durationUs,
          'translate': translate,
        },
      );
      if (payload == null) return AsrResult.failure;
      return AsrResult.fromJson(payload);
    } on PlatformException catch (error) {
      return AsrResult(ok: false, segments: const <AsrSegmentData>[], error: error.message);
    } finally {
      await subscription?.cancel();
    }
  }

  /// Confirms that the URL and key work before a long upload is attempted.
  Future<AsrCloudCheck> checkCloud(AsrCloudConfig config) async {
    try {
      final Map<Object?, Object?>? map = await _channel.invokeMapMethod<Object?, Object?>(
        NativeMethods.asrCloudCheck,
        <String, Object?>{'baseUrl': config.baseUrl, 'apiKey': config.apiKey},
      );
      if (map == null) return const AsrCloudCheck(ok: false, error: 'پاسخی دریافت نشد.');
      final Object? models = map['models'];
      return AsrCloudCheck(
        ok: map['ok'] == true,
        error: '${map['error'] ?? ''}',
        models: models is List
            ? models.map((Object? entry) => '$entry').toList(growable: false)
            : const <String>[],
      );
    } on PlatformException catch (error) {
      return AsrCloudCheck(ok: false, error: error.message ?? 'بررسی ناموفق بود.');
    } on MissingPluginException {
      return const AsrCloudCheck(ok: false, error: 'این نسخه از برنامه سرویس آنلاین را ندارد.');
    }
  }

  Future<bool> deleteModel(String path) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        NativeMethods.asrDeleteModel,
        <String, Object?>{'path': path},
      );
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>(NativeMethods.asrCancel);
    } on PlatformException {
      // Cancelling a finished/never-started job is not an error.
    }
  }

  /// Transcribes the project's video. [onProgress] runs on 0..100 and is fed by
  /// the Kotlin decoder (0-30) and whisper itself (30-100).
  Future<AsrResult> transcribe({
    required String uri,
    required String modelPath,
    required String language,
    required int durationUs,
    bool translate = false,
    void Function(int value)? onProgress,
  }) async {
    StreamSubscription<dynamic>? subscription;
    if (onProgress != null) {
      subscription = _events.receiveBroadcastStream().listen((dynamic event) {
        if (event is Map && event['event'] == 'progress') {
          final Object? value = event['value'];
          if (value is num) onProgress(value.toInt());
        }
      });
    }
    try {
      final String? payload = await _channel.invokeMethod<String>(
        NativeMethods.asrTranscribe,
        <String, Object?>{
          'uri': uri,
          'modelPath': modelPath,
          'language': language,
          'durationUs': durationUs,
          'translate': translate,
        },
      );
      if (payload == null) return AsrResult.failure;
      return AsrResult.fromJson(payload);
    } on PlatformException catch (error) {
      return AsrResult(ok: false, segments: const <AsrSegmentData>[], error: error.message);
    } finally {
      await subscription?.cancel();
    }
  }
}
