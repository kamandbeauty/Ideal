import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/job.dart';
import '../../features/agent/intent_parser.dart';
import '../../services/briefing_service.dart';
import '../../services/job_runner.dart';
import '../../services/job_service.dart';
import '../../services/note_service.dart';
import 'database_provider.dart';
import 'permission_providers.dart';

final noteServiceProvider = Provider<NoteService>(
  (ref) => NoteService(ref.watch(noteRepositoryProvider)),
);

/// Platform-facing alarm helper: keeps Android in sync with a job's next run.
final jobAlarmProvider = Provider<JobAlarm>(
  (ref) => JobAlarm(ref.watch(nativeBridgeProvider)),
);

final jobServiceProvider = Provider<JobService>(
  (ref) => JobService(
    ref.watch(jobRepositoryProvider),
    onScheduleChanged: (job) async {
      // Re-arm on every create/enable/disable so an alarm always exists for the
      // next run, even if the UI is closed a second later.
      await ref.read(jobAlarmProvider).arm(job);
    },
  ),
);

final briefingServiceProvider = Provider<BriefingService>(
  (ref) => const BriefingService(),
);

final intentParserProvider = Provider<IntentParser>((ref) => IntentParser());

/// All jobs, newest scheduling first. Refreshed after every mutation.
final jobsProvider = FutureProvider<List<Job>>(
  (ref) => ref.watch(jobServiceProvider).list(),
);
