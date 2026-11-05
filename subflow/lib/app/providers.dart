import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/platform/contracts.dart';
import '../core/platform/native_bridge.dart';
import '../database/app_database.dart';
import '../database/dao/export_dao.dart';
import '../database/dao/media_dao.dart';
import '../database/dao/model_dao.dart';
import '../database/dao/project_dao.dart';
import '../database/dao/settings_dao.dart';
import '../models/project.dart';
import '../services/media_service.dart';
import '../services/project_repository.dart';

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
final FutureProvider<bool> onboardingDoneProvider = FutureProvider<bool>((Ref ref) async {
  final SettingsDao settings = await ref.watch(settingsDaoProvider.future);
  return settings.getBool(SettingKeys.onboardingDone);
});

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
