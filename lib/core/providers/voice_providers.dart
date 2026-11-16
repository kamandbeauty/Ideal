import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assistant_message.dart';
import '../../features/assistant/assistant_controller.dart';
import '../../services/voice/native_speech_recognizer.dart';
import '../../services/voice/native_tts_engine.dart';
import 'agent_providers.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

/// Speech engine instances (overridable with fakes in tests).
final speechRecognizerProvider =
    Provider((ref) => NativeSpeechRecognizer());

final ttsEngineProvider = Provider((ref) => NativeTtsEngine());

/// Conversation/activity log of the assistant.
final assistantActivityProvider =
    StateNotifierProvider<AssistantActivity, List<AssistantMessage>>(
  (ref) => AssistantActivity(ref),
);

/// The assistant state machine.
final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>((ref) {
  return AssistantController(
    recognizer: ref.watch(speechRecognizerProvider),
    tts: ref.watch(ttsEngineProvider),
    agent: ref.watch(agentCoreProvider),
    activity: ref.watch(assistantActivityProvider.notifier),
    speakReplies: ref.watch(speakRepliesProvider),
  );
});
