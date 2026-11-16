import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/agent/agent_core.dart';
import 'repository_providers.dart';
import 'service_providers.dart';

/// The agent brain, wired to the local services.
final agentCoreProvider = Provider<AgentCore>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return AgentCore(
    parser: ref.watch(intentParserProvider),
    notes: ref.watch(noteServiceProvider),
    jobs: ref.watch(jobServiceProvider),
    briefing: ref.watch(briefingServiceProvider),
    notifications: notifications,
  );
});
