import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/job.dart';
import '../../features/agent/intent_parser.dart';
import '../../services/briefing_service.dart';
import '../../services/job_service.dart';
import '../../services/note_service.dart';
import 'database_provider.dart';

final noteServiceProvider = Provider<NoteService>(
  (ref) => NoteService(ref.watch(noteRepositoryProvider)),
);

final jobServiceProvider = Provider<JobService>(
  (ref) => JobService(ref.watch(jobRepositoryProvider)),
);

final briefingServiceProvider = Provider<BriefingService>(
  (ref) => const BriefingService(),
);

final intentParserProvider = Provider<IntentParser>((ref) => IntentParser());

/// All jobs, newest scheduling first. Refreshed after every mutation.
final jobsProvider = FutureProvider<List<Job>>(
  (ref) => ref.watch(jobServiceProvider).list(),
);
