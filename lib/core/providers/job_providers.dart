import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/briefing_service.dart';
import '../../services/job_runner.dart';
import '../../services/job_service.dart';
import '../../services/native_bridge.dart';
import 'permission_providers.dart';
import 'database_provider.dart';
import 'service_providers.dart';

/// Set by the shell after every tick so the dashboard can show the last run.

/// Runs due jobs and keeps the native alarm armed.
final jobRunnerProvider = Provider<JobRunner>((ref) {
  return JobRunner(
    jobs: ref.watch(jobServiceProvider),
    briefing: ref.watch(briefingServiceProvider),
    alarm: JobAlarm(ref.watch(nativeBridgeProvider)),
    notifications: () async => ref.read(notificationRepositoryProvider).list(),
  );
});

/// Foreground ticker; started by the shell and stopped when it is disposed.
final jobSchedulerProvider = Provider<JobScheduler>((ref) {
  final scheduler = JobScheduler(ref.watch(jobRunnerProvider));
  ref.onDispose(scheduler.stop);
  return scheduler;
});

/// Latest tick result, so the dashboard can show «آخرین اجرا».
final lastTickProvider = StateProvider<JobTickResult?>((ref) => null);
