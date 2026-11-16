import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/assistant_repository.dart';
import '../../data/repositories/job_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/settings_repository.dart';

/// The single application database instance.
///
/// Overridden during bootstrap (and in tests) with an already-opened instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('appDatabaseProvider must be overridden during bootstrap.');
});

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(ref.watch(appDatabaseProvider)),
);

final jobRepositoryProvider = Provider<JobRepository>(
  (ref) => JobRepository(ref.watch(appDatabaseProvider)),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(appDatabaseProvider)),
);

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => AssistantRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);
