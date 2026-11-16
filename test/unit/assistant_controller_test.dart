import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/repositories/assistant_repository.dart';
import 'package:javid_ai/data/repositories/job_repository.dart';
import 'package:javid_ai/data/repositories/note_repository.dart';
import 'package:javid_ai/features/agent/agent_core.dart';
import 'package:javid_ai/features/agent/intent_parser.dart';
import 'package:javid_ai/features/assistant/assistant_controller.dart';
import 'package:javid_ai/features/assistant/assistant_state.dart';
import 'package:javid_ai/services/briefing_service.dart';
import 'package:javid_ai/services/job_service.dart';
import 'package:javid_ai/services/note_service.dart';
import 'package:javid_ai/services/voice/speech_recognizer.dart';
import 'package:javid_ai/services/voice/tts_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/provider_overrides.dart';
import '../helpers/test_database.dart';

/// Test double: records calls and lets the test drive the callbacks.
class FakeRecognizer implements SpeechRecognizer {
  void Function(String)? onPartial;
  void Function(String)? onFinal;
  void Function(String)? onError;
  bool started = false;
  int startCalls = 0;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> isPersianAvailable() async => true;

  @override
  Future<bool> start({
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(String message) onError,
  }) async {
    this.onPartial = onPartial;
    this.onFinal = onFinal;
    this.onError = onError;
    startCalls++;
    started = true;
    return true;
  }

  @override
  Future<void> stop() async => started = false;

  @override
  Future<void> cancel() async => started = false;

  @override
  Future<void> dispose() async {}
}

class FakeTts implements TtsEngine {
  final List<String> spoken = [];
  bool stopped = false;

  @override
  Future<TtsAvailability> initialize() async =>
      const TtsAvailability(available: true, voiceName: 'fa-fake');

  @override
  Future<void> speak(String text, {void Function()? onDone}) async {
    spoken.add(text);
    onDone?.call();
  }

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> dispose() async {}
}

class FakeTtsUnavailable extends FakeTts {
  @override
  Future<TtsAvailability> initialize() async =>
      const TtsAvailability.unavailable('صدای فارسی نصب نیست.');
}

void main() {
  setUpAll(setUpSqfliteFfi);

  final now = DateTime(2026, 11, 16, 10, 0);
  late TestDatabase database;
  late NoteService notes;
  late AgentCore agent;
  late AssistantActivity activity;
  late FakeRecognizer recognizer;
  late FakeTts tts;
  late ProviderContainer container;

  setUp(() async {
    database = TestDatabase();
    await database.open();
    notes = NoteService(NoteRepository(database));
    final jobs = JobService(JobRepository(database), clock: () => now);
    agent = AgentCore(
      parser: IntentParser(clock: () => now),
      notes: notes,
      jobs: jobs,
      briefing: const BriefingService(),
      clock: () => now,
    );
    container = ProviderContainer(
      overrides: [appDatabaseProviderOverride(database)],
    );
    activity = AssistantActivity(AssistantRepository(database));
    recognizer = FakeRecognizer();
    tts = FakeTts();
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  AssistantController build({TtsEngine? engine}) => AssistantController(
        recognizer: recognizer,
        tts: engine ?? tts,
        agent: agent,
        activity: activity,
        speakReplies: true,
      );

  test('starts in the idle state', () {
    final controller = build();
    expect(controller.state.status, AssistantStatus.idle);
    expect(controller.state.reply, isEmpty);
  });

  test('listening captures partial transcripts', () async {
    final controller = build();
    await controller.startListening();
    expect(controller.state.status, AssistantStatus.listening);
    recognizer.onPartial!('سلام');
    expect(controller.state.transcript, 'سلام');
  });

  test('processing a final transcript produces and speaks a reply', () async {
    final controller = build();
    await controller.startListening();
    recognizer.onFinal!('سلام');
    // Let the async handler finish.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.state.status, AssistantStatus.idle);
    expect(controller.state.reply, contains('صبح بخیر'));
    expect(tts.spoken.single, contains('صبح بخیر'));
  });

  test('confirmation-gated intents do not execute before approval', () async {
    final controller = build();
    await controller.startListening();
    recognizer.onFinal!('یادداشت جدید بساز: تست');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.state.pendingConfirmation, isNotNull);
    expect(await notes.count(), 0);

    controller.state.pendingConfirmation!.onConfirm();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await notes.count(), 1);
    expect(controller.state.pendingConfirmation, isNull);
  });

  test('cancel on the confirmation sheet keeps data untouched', () async {
    final controller = build();
    await controller.startListening();
    recognizer.onFinal!('یادداشت جدید بساز: تست');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    controller.state.pendingConfirmation!.onCancel();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await notes.count(), 0);
    expect(controller.state.reply, contains('انجام نشد'));
  });

  test('recognition errors surface a Persian message and return to idle', () async {
    final controller = build();
    await controller.startListening();
    recognizer.onError!('مجوز میکروفون داده نشده است.');
    expect(controller.state.status, AssistantStatus.idle);
    expect(controller.state.error, contains('مجوز'));
  });

  test('repeat replays the last assistant reply', () async {
    final controller = build();
    await controller.submitText('سلام');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    tts.spoken.clear();
    await controller.repeat();
    expect(tts.spoken, isNotEmpty);
    expect(controller.state.repeatCount, 1);
  });

  test('missing Persian TTS voice is reported, text answer still works', () async {
    final controller = build(engine: FakeTtsUnavailable());
    await controller.submitText('سلام');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.state.reply, isNotEmpty);
    expect(controller.state.error, contains('صدای فارسی'));
  });

  test('typed input is recorded in the activity log', () async {
    final controller = build();
    await controller.submitText('یادداشت‌ها را نشان بده');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final messages = await AssistantRepository(database).recent();
    expect(messages, isNotEmpty);
    expect(messages.any((message) => message.text.contains('یادداشت')), isTrue);
  });

  test('stopAll returns to idle and stops audio', () async {
    final controller = build();
    await controller.startListening();
    await controller.stopAll();
    expect(controller.state.status, AssistantStatus.idle);
    expect(tts.stopped, isTrue);
  });

  test('mute prevents speech output', () async {
    final controller = build();
    controller.toggleMute();
    await controller.submitText('سلام');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(tts.spoken, isEmpty);
  });
}
