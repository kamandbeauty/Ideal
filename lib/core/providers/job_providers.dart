import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/job_runner.dart';
import 'database_provider.dart';
import 'permission_providers.dart';
import 'service_providers.dart';

/// Stops background work before the database is closed.
///
/// Production leaves this as a no-op; widget tests override it so a pending
/// timer or frame callback cannot touch a closed database during teardown.
final appShutdownProvider = Provider<Future<void> Function()>((ref) => () async {});

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
final jobSchedulerProvider = Provider<JobTicker>((ref) {
  final scheduler = JobScheduler(ref.watch(jobRunnerProvider));
  ref.onDispose(scheduler.stop);
  return scheduler;
});

/// Latest tick result, so the dashboard can show «آخرین اجرا».
final lastTickProvider = StateProvider<JobTickResult?>((ref) => null);
