import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors.dart';
import '../core/platform/contracts.dart';
import '../core/platform/native_bridge.dart';
import '../database/app_database.dart';
import '../database/dao/export_dao.dart';
import '../database/dao/media_dao.dart';
import '../database/dao/model_dao.dart';
import '../database/dao/project_dao.dart';
import '../database/dao/settings_dao.dart';
import '../database/dao/subtitle_dao.dart';
import '../features/subtitles/subtitle_document.dart';
import '../features/subtitles/subtitle_editor_model.dart';
import '../models/asr_provider.dart';
import '../models/project.dart';
import '../models/subtitle.dart';
import '../models/subtitle_style.dart';
import '../services/asr_service.dart';
import '../services/media_service.dart';
import '../services/project_repository.dart';
import '../services/subtitle_export_service.dart';
import '../services/video_export_service.dart';

// ---------------------------------------------------------------- infrastructure
final Provider<NativeBridge> nativeBridgeProvider =
    Provider<NativeBridge>((Ref ref) => NativeBridge());

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final FutureProvider<ProjectDao> projectDaoProvider = FutureProvider<ProjectDao>((Ref ref) async {
  return ProjectDao(await ref.watch(appDatabaseProvider).database);
});

final FutureProvider<MediaDao> mediaDaoProvider = FutureProvider<MediaDao>((Ref ref) async {
  return MediaDao(await ref.watch(appDatabaseProvider).database);
});

final FutureProvider<SettingsDao> settingsDaoProvider =
    FutureProvider<SettingsDao>((Ref ref) async {
  return SettingsDao(await ref.watch(appDatabaseProvider).database);
});

final FutureProvider<ExportJobDao> exportDaoProvider =
    FutureProvider<ExportJobDao>((Ref ref) async {
  return ExportJobDao(await ref.watch(appDatabaseProvider).database);
});

final FutureProvider<ModelDao> modelDaoProvider = FutureProvider<ModelDao>((Ref ref) async {
  return ModelDao(await ref.watch(appDatabaseProvider).database);
});

final Provider<ProjectRepository> projectRepositoryProvider =
    Provider<ProjectRepository>((Ref ref) {
  return ProjectRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(nativeBridgeProvider).fileExists,
  );
});

final Provider<MediaService> mediaServiceProvider = Provider<MediaService>((Ref ref) {
  return MediaService(ref.watch(nativeBridgeProvider));
});

final FutureProvider<DeviceCapabilities> deviceCapabilitiesProvider =
    FutureProvider<DeviceCapabilities>((Ref ref) {
  return ref.watch(nativeBridgeProvider).capabilities();
});

// ------------------------------------------------------------------ app state

final FutureProvider<int> projectCountProvider = FutureProvider<int>((Ref ref) async {
  final ProjectDao dao = await ref.watch(projectDaoProvider.future);
  return dao.countActive();
});

/// Project list + mutations. Every mutation refreshes the list from SQLite so
/// the UI can never show state the database does not have.
class ProjectsController extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final ProjectDao dao = await ref.watch(projectDaoProvider.future);
    return dao.listRecent();
  }

  ProjectRepository get _repo => ref.read(projectRepositoryProvider);

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final ProjectDao dao = await ref.read(projectDaoProvider.future);
      return dao.listRecent();
    });
  }

  /// Returns a Persian error message on failure, or null on success.
  Future<String?> rename(String projectId, String name) async {
    try {
      await _repo.rename(projectId, name);
      await refresh();
      return null;
    } on AppFailure catch (failure) {
      return failure.message;
    }
  }

  Future<Project> duplicate(String projectId) async {
    final Project copy = await _repo.duplicate(projectId);
    await refresh();
    return copy;
  }

  Future<void> delete(String projectId, {required bool permanent}) async {
    if (permanent) {
      await _repo.deletePermanently(projectId);
    } else {
      await _repo.softDelete(projectId);
    }
    await refresh();
  }

  Future<void> restore(String projectId) async {
    await _repo.restore(projectId);
    await refresh();
  }
}

final AsyncNotifierProvider<ProjectsController, List<Project>> projectsControllerProvider =
    AsyncNotifierProvider<ProjectsController, List<Project>>(ProjectsController.new);

/// Full editor payload for one project.
final FutureProviderFamily<ProjectDetail, String> projectDetailProvider =
    FutureProvider.family<ProjectDetail, String>((Ref ref, String projectId) async {
  final ProjectRepository repo = ref.watch(projectRepositoryProvider);
  final Project? project = await repo.find(projectId);
  if (project == null) {
    throw const AppFailure(AppErrorCode.validation, 'این پروژه پیدا نشد یا حذف شده است.');
  }
  final MediaDao media = await ref.watch(mediaDaoProvider.future);
  return ProjectDetail(
    project: project,
    asset: await media.assetOfProject(projectId),
    tracks: await media.tracksOfProject(projectId),
    watermarks: await media.watermarksOfProject(projectId),
    mediaAvailable: await repo.verifyMedia(projectId),
  );
});

// ------------------------------------------------------------------- whisper
final Provider<AsrService> asrServiceProvider =
    Provider<AsrService>((Ref ref) => AsrService());

final FutureProvider<AsrCapabilities> asrCapabilitiesProvider =
    FutureProvider<AsrCapabilities>((Ref ref) async {
  return ref.watch(asrServiceProvider).capabilities();
});

/// Installed Whisper models. Import and delete go through this controller so
/// the list on screen is the list on disk - never a cached guess.
class AsrModelsController extends AsyncNotifier<List<AsrModel>> {
  @override
  Future<List<AsrModel>> build() => ref.watch(asrServiceProvider).listModels();

  Future<AsrModel?> importModel() async {
    final AsrService service = ref.read(asrServiceProvider);
    final AsrModel? model = await service.importModel();
    state = AsyncData<List<AsrModel>>(await service.listModels());
    return model;
  }

  /// Downloads one catalogue model and refreshes both lists when it lands.
  Future<AsrModel?> download(
    String id, {
    void Function(AsrDownloadProgress progress)? onProgress,
  }) async {
    final AsrService service = ref.read(asrServiceProvider);
    final AsrModel? model = await service.downloadModel(id, onProgress: onProgress);
    state = AsyncData<List<AsrModel>>(await service.listModels());
    ref.invalidate(asrCatalogProvider);
    return model;
  }

  Future<void> delete(String path) async {
    final AsrService service = ref.read(asrServiceProvider);
    await service.deleteModel(path);
    state = AsyncData<List<AsrModel>>(await service.listModels());
    ref.invalidate(asrCatalogProvider);
  }

  Future<void> refresh() async {
    state = AsyncData<List<AsrModel>>(await ref.read(asrServiceProvider).listModels());
  }
}

final AsyncNotifierProvider<AsrModelsController, List<AsrModel>> asrModelsProvider =
    AsyncNotifierProvider<AsrModelsController, List<AsrModel>>(AsrModelsController.new);

/// Where transcription happens: on the phone, or on an opt-in online service.
final FutureProvider<AsrSettingsStore> asrSettingsStoreProvider =
    FutureProvider<AsrSettingsStore>((Ref ref) async {
  return AsrSettingsStore(await ref.watch(settingsDaoProvider.future));
});

final FutureProvider<AsrProviderMode> asrProviderModeProvider =
    FutureProvider<AsrProviderMode>((Ref ref) async {
  return (await ref.watch(asrSettingsStoreProvider.future)).mode();
});

final FutureProvider<AsrCloudConfig> asrCloudConfigProvider =
    FutureProvider<AsrCloudConfig>((Ref ref) async {
  return (await ref.watch(asrSettingsStoreProvider.future)).cloudConfig();
});

/// Writes the provider choice and credentials, then refreshes both readers.
class AsrSettingsController {
  const AsrSettingsController(this._ref);

  final Ref _ref;

  Future<void> setMode(AsrProviderMode mode) async {
    final AsrSettingsStore store = await _ref.read(asrSettingsStoreProvider.future);
    await store.setMode(mode);
    _ref.invalidate(asrProviderModeProvider);
  }

  Future<void> saveCloud(AsrCloudConfig config) async {
    final AsrSettingsStore store = await _ref.read(asrSettingsStoreProvider.future);
    await store.saveCloudConfig(config);
    _ref.invalidate(asrCloudConfigProvider);
  }
}

final Provider<AsrSettingsController> asrSettingsControllerProvider =
    Provider<AsrSettingsController>(AsrSettingsController.new);

/// Models the app can fetch itself, with their installed state.
final FutureProvider<List<AsrCatalogEntry>> asrCatalogProvider =
    FutureProvider<List<AsrCatalogEntry>>((Ref ref) async {
  return ref.watch(asrServiceProvider).catalog();
});

// ---------------------------------------------------------------- subtitles
final FutureProvider<SubtitleDao> subtitleDaoProvider = FutureProvider<SubtitleDao>((Ref ref) async {
  return SubtitleDao(await ref.watch(appDatabaseProvider).database);
});

final Provider<SubtitleExportService> subtitleExportServiceProvider =
    Provider<SubtitleExportService>((Ref ref) {
  return SubtitleExportService(bridge: ref.watch(nativeBridgeProvider));
});

/// Burns captions into an MP4 (Phase 5). One instance per app: the render is a
/// single native job, so a second concurrent render would fight over the
/// encoder anyway.
final Provider<VideoExportService> videoExportServiceProvider =
    Provider<VideoExportService>((Ref ref) {
  return VideoExportService(bridge: ref.watch(nativeBridgeProvider));
});

/// The subtitle studio for one project.
///
/// Loading happens once, every command mutates a pure `SubtitleEditorModel`
/// (which owns the undo history), and the document is written back to SQLite on
/// a short debounce so a crash can lose at most one edit. The notifier never
/// invents state: `state` is always the model's snapshot.
class SubtitleEditorNotifier extends FamilyAsyncNotifier<SubtitleEditorSnapshot, String> {
  SubtitleEditorModel? _model;
  SubtitleTrack? _track;
  Timer? _saveTimer;
  bool _saving = false;
  String? lastSaveError;

  @override
  Future<SubtitleEditorSnapshot> build(String projectId) async {
    ref.onDispose(() {
      _saveTimer?.cancel();
      final SubtitleEditorModel? model = _model;
      final SubtitleTrack? track = _track;
      if (model != null && track != null && model.snapshot.dirty) {
        // Best effort final flush; nothing else can await inside onDispose.
        unawaited(_persist(track.id, model));
      }
    });
    final SubtitleDao dao = await ref.watch(subtitleDaoProvider.future);
    final SubtitleTrack track = await dao.ensureOriginalTrack(projectId);
    final List<SubtitleSegment> segments = await dao.loadSegments(track.id);
    _track = track;
    _model = SubtitleEditorModel(
      document: SubtitleDocument(trackId: track.id, segments: segments),
    );
    return _model!.snapshot;
  }

  SubtitleEditorModel get _require {
    final SubtitleEditorModel? model = _model;
    if (model == null) {
      throw StateError('subtitle editor is not loaded yet');
    }
    return model;
  }

  void _publish({bool scheduleSave = true}) {
    final SubtitleEditorModel model = _require;
    state = AsyncData<SubtitleEditorSnapshot>(model.snapshot);
    if (scheduleSave && model.snapshot.dirty) _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveNow());
    });
  }

  Future<void> _saveNow() async {
    final SubtitleEditorModel? model = _model;
    final SubtitleTrack? track = _track;
    if (model == null || track == null || _saving) return;
    _saving = true;
    try {
      await _persist(track.id, model);
      model.markSaved();
      lastSaveError = null;
      state = AsyncData<SubtitleEditorSnapshot>(model.snapshot);
    } on Object catch (error) {
      lastSaveError = '$error';
      if (state.hasValue) {
        state = AsyncData<SubtitleEditorSnapshot>(model.snapshot);
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _persist(String trackId, SubtitleEditorModel model) async {
    final SubtitleDao dao = await ref.read(subtitleDaoProvider.future);
    await dao.replaceSegments(trackId, model.document.segments);
  }

  /// Force a save (used before export and when leaving the screen).
  Future<void> flush() async {
    _saveTimer?.cancel();
    await _saveNow();
  }

  void select(String? segmentId) {
    _require.select(segmentId);
    _publish(scheduleSave: false);
  }

  void setText(String segmentId, String text) {
    if (_require.setText(segmentId, text)) _publish();
  }

  void retime(String segmentId, {int? startUs, int? endUs}) {
    if (_require.retime(segmentId, startUs: startUs, endUs: endUs)) _publish();
  }

  void insertAt(int atUs) {
    if (_require.insertAt(atUs)) _publish();
  }

  void split(String segmentId, int atUs) {
    if (_require.split(segmentId, atUs)) _publish();
  }

  void mergeWithNext(String segmentId) {
    if (_require.mergeWithNext(segmentId)) _publish();
  }

  void remove(String segmentId) {
    if (_require.remove(segmentId)) _publish();
  }

  void shiftAll(int deltaUs) {
    if (_require.shiftAll(deltaUs)) _publish();
  }

  void undo() {
    if (_require.undo()) _publish();
  }

  void redo() {
    if (_require.redo()) _publish();
  }

  void copyStyle() {
    _require.copyStyle();
    _publish(scheduleSave: false);
  }

  void pasteStyle() {
    if (_require.pasteStyle()) _publish();
  }

  /// Saves the mapped gallery style and applies it to every caption.
  Future<void> applyStyle(SubtitleStyle style) async {
    final SubtitleDao dao = await ref.read(subtitleDaoProvider.future);
    await dao.saveStyle(style);
    if (_require.applyStyleToAll(style.id)) _publish();
  }
}

final AsyncNotifierProviderFamily<SubtitleEditorNotifier, SubtitleEditorSnapshot, String>
    subtitleEditorProvider = AsyncNotifierProvider.family<SubtitleEditorNotifier,
        SubtitleEditorSnapshot, String>(SubtitleEditorNotifier.new);
