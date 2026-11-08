/// Application-wide dependency wiring.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/services/media_picker_service.dart';
import '../core/services/thumbnail_service.dart';
import '../core/storage/app_settings_store.dart';
import '../core/storage/project_repository.dart';
import '../core/utils/ratio_utils.dart';
import '../features/export/export_manager.dart';
import '../features/platform/native_video_bridge/video_bridge.dart';
import '../features/settings/settings_controller.dart';

/// Set by `main()` after opening the database and preferences.
class AppBootstrap {
  const AppBootstrap({
    required this.repository,
    required this.settingsStore,
    required this.thumbs,
    required this.mediaPicker,
    required this.settingsController,
  });

  final ProjectRepository repository;
  final AppSettingsStore settingsStore;
  final ThumbnailService thumbs;
  final MediaPickerService mediaPicker;
  final SettingsController settingsController;

  /// Everything the user can free from Settings.
  Future<int> clearCache() async {
    final freed = await thumbs.clearAll();
    return freed;
  }

  String humanFreed(int bytes) => formatBytes(bytes);
}

final bootstrapProvider = Provider<AppBootstrap>((ref) {
  throw StateError('bootstrapProvider must be overridden in main()');
});

final videoBridgeProvider = Provider<VideoBridge>((ref) => VideoBridge());

final exportManagerProvider = Provider<ExportManager>((ref) {
  final manager = ExportManager(bridge: ref.watch(videoBridgeProvider));
  ref.onDispose(() => manager.dispose());
  return manager;
});

final settingsProvider =
    StateNotifierProvider<SettingsController, AppPreferences>(
  (ref) => ref.watch(bootstrapProvider).settingsController,
);

final appLocaleProvider = Provider<String>((ref) {
  final code = ref.watch(settingsProvider).localeCode;
  return code == 'system' ? 'en' : code;
});

/// Device capabilities, resolved once. Used by the Export and Settings screens
/// to disable combinations the device cannot encode instead of failing later.
final capabilitiesProvider = FutureProvider<DeviceCapabilities>((ref) async {
  return ref.watch(videoBridgeProvider).getCapabilities();
});

/// Thumbnail path for a photo id (null while generating).
final thumbnailPathProvider =
    FutureProvider.family<String?, String>((ref, photoId) async {
  final thumbs = ref.watch(bootstrapProvider).thumbs;
  final cached = thumbs.cached(photoId);
  return cached?.path;
});

/// Amplitude envelope of the project's music, decoded natively
/// (`Waveform.kt`). `(sourceDurationSec, peaks 0..1)` — the peaks are
/// normalized by the global peak and tiled by the UI for looped music.
final audioWaveformProvider =
    NotifierProvider<WaveformNotifier, AsyncValue<(double, List<double>)>>(
        WaveformNotifier.new);

class WaveformNotifier extends Notifier<AsyncValue<(double, List<double>)>> {
  String? _path;

  @override
  AsyncValue<(double, List<double>)> build() =>
      const AsyncData((0.0, <double>[]));

  /// Loads the envelope for [path] (cached while the path is unchanged).
  /// A decode failure leaves a zeroed envelope — the UI shows a flatline
  /// rather than breaking the editor.
  Future<void> load(String path) async {
    if (_path == path) return;
    _path = path;
    state = const AsyncLoading();
    try {
      final value = await ref.read(videoBridgeProvider).waveform(path);
      if (_path == path) state = AsyncData(value);
    } catch (_) {
      if (_path == path) state = const AsyncData((0.0, <double>[]));
    }
  }
}

/// Convenience for building a stable cache path for exports.
String exportTempPath(String cacheDir) =>
    p.join(cacheDir, 'export_${DateTime.now().millisecondsSinceEpoch}.mp4');
