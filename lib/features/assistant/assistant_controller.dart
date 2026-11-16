import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/assistant_repository.dart';
import '../../core/providers/service_providers.dart';
import '../../data/models/assistant_message.dart';
import '../../features/agent/agent_core.dart';
import '../../services/voice/speech_recognizer.dart';
import '../../services/voice/tts_engine.dart';
import 'assistant_state.dart';

/// Orchestrates the voice loop: listen → transcribe → think → speak.
///
/// Every dependency is injected, so the full state machine is unit-tested with
/// fakes (see test/assistant_controller_test.dart).
class AssistantController extends StateNotifier<AssistantState> {
  AssistantController({
    required SpeechRecognizer recognizer,
    required TtsEngine tts,
    required AgentCore agent,
    required AssistantActivity activity,
    bool speakReplies = true,
  })  : _recognizer = recognizer,
        _tts = tts,
        _agent = agent,
        _activity = activity,
        _speakReplies = speakReplies,
        super(const AssistantState());

  final SpeechRecognizer _recognizer;
  final TtsEngine _tts;
  final AgentCore _agent;
  final AssistantActivity _activity;
  bool _speakReplies;
  bool _ttsUnavailableWarned = false;

  void setSpeakReplies(bool value) => _speakReplies = value;

  /// Presses the microphone: starts listening, or stops when already listening.
  Future<void> toggleListening() async {
    switch (state.status) {
      case AssistantStatus.listening:
        await stopListening();
      case AssistantStatus.speaking:
        await _tts.stop();
        state = state.copyWith(status: AssistantStatus.idle);
      case AssistantStatus.idle:
      case AssistantStatus.processing:
        await startListening();
    }
  }

  Future<void> startListening() async {
    if (state.status == AssistantStatus.processing) return;
    final availability = await _tts.initialize();
    if (!availability.available && !_ttsUnavailableWarned) {
      _ttsUnavailableWarned = true;
    }
    state = state.copyWith(
      status: AssistantStatus.listening,
      transcript: '',
      clearError: true,
      clearConfirmation: true,
    );
    final started = await _recognizer.start(
      onPartial: (text) {
        if (state.status == AssistantStatus.listening) {
          state = state.copyWith(transcript: text);
        }
      },
      onFinal: (text) {
        if (state.status == AssistantStatus.listening) _handleUtterance(text);
      },
      onError: (message) {
        state = state.copyWith(
          status: AssistantStatus.idle,
          error: message,
        );
      },
    );
    if (!started) {
      state = state.copyWith(status: AssistantStatus.idle);
    }
  }

  Future<void> stopListening() async {
    await _recognizer.stop();
    // A final result may arrive asynchronously; give the recogniser a moment,
    // then process whatever transcript exists so the button never dead-ends.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (state.status == AssistantStatus.listening) {
      final text = state.transcript.trim();
      if (text.isEmpty) {
        state = state.copyWith(status: AssistantStatus.idle);
      } else {
        await _handleUtterance(text);
      }
    }
  }

  /// Processes typed input too, so the assistant is usable without a mic.
  Future<void> submitText(String text) async {
    if (text.trim().isEmpty) return;
    await _handleUtterance(text.trim(), fromVoice: false);
  }

  Future<void> _handleUtterance(String text, {bool fromVoice = true}) async {
    await _recognizer.cancel();
    state = state.copyWith(
      status: AssistantStatus.processing,
      transcript: text,
      lastUserText: text,
      clearError: true,
      clearConfirmation: true,
    );
    try {
      final turn = await _agent.handle(text);
      state = state.copyWith(
        status: AssistantStatus.idle,
        reply: turn.reply,
        lastAssistantText: turn.reply,
        pendingConfirmation: turn.requiresConfirmation && turn.toolCall != null
            ? _toConfirmation(turn.toolCall!)
            : null,
      );
      await _activity.record(
        text: text,
        role: AssistantRole.user,
        source: fromVoice ? AssistantTurnSource.voice : AssistantTurnSource.text,
      );
      if (!turn.requiresConfirmation) {
        await _activity.record(text: turn.reply, role: AssistantRole.assistant);
        await _speak(turn.reply);
      }
    } catch (error) {
      state = state.copyWith(
        status: AssistantStatus.idle,
        error: 'در اجرای دستور مشکلی پیش آمد. دوباره تلاش کن.',
      );
    }
  }

  PendingConfirmation _toConfirmation(AgentToolCall call) {
    return PendingConfirmation(
      title: call.title,
      summary: call.preview,
      actionLabel: call.isDestructive ? 'بله، حذف کن' : 'تأیید و انجام',
      isDestructive: call.isDestructive,
      onConfirm: () {
        unawaited(_runTool(call));
      },
      onCancel: () {
        state = state.copyWith(
          clearConfirmation: true,
          reply: 'باشه، انجام نشد.',
        );
      },
    );
  }

  Future<void> _runTool(AgentToolCall call) async {
    state = state.copyWith(
      status: AssistantStatus.processing,
      clearConfirmation: true,
    );
    final result = await call.execute();
    final message = result.success
        ? result.message
        : '${result.message}\n${result.error ?? ''}'.trim();
    state = state.copyWith(
      status: AssistantStatus.idle,
      reply: message,
      lastAssistantText: message,
    );
    await _activity.record(text: message, role: AssistantRole.assistant);
    await _speak(message);
  }

  /// Replays the last assistant reply.
  Future<void> repeat() async {
    final text = state.lastAssistantText;
    if (text.isEmpty) return;
    state = state.copyWith(repeatCount: state.repeatCount + 1);
    await _speak(text);
  }

  Future<void> _speak(String text) async {
    if (!_speakReplies || state.isMuted) return;
    if (text.trim().isEmpty) return;
    final availability = await _tts.initialize();
    if (!availability.available) {
      if (!_ttsUnavailableWarned) {
        _ttsUnavailableWarned = true;
        state = state.copyWith(error: availability.message);
      }
      return;
    }
    state = state.copyWith(status: AssistantStatus.speaking);
    await _tts.speak(
      text,
      onDone: () {
        if (state.status == AssistantStatus.speaking) {
          state = state.copyWith(status: AssistantStatus.idle);
        }
      },
    );
    // Some engines never fire the completion handler; make sure the UI returns
    // to idle so the microphone is never stuck disabled.
    unawaited(
      Future<void>.delayed(Duration(milliseconds: 800 + text.length * 55), () {
        if (state.status == AssistantStatus.speaking) {
          state = state.copyWith(status: AssistantStatus.idle);
        }
      }),
    );
  }

  /// Stops speech and listening immediately.
  Future<void> stopAll() async {
    await _tts.stop();
    await _recognizer.cancel();
    state = state.copyWith(status: AssistantStatus.idle);
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
    if (state.isMuted) unawaited(_tts.stop());
  }

  void clearError() => state = state.copyWith(clearError: true);

  @override
  void dispose() {
    unawaited(_recognizer.dispose());
    unawaited(_tts.dispose());
    super.dispose();
  }
}

/// Persists the activity log so the dashboard timeline survives restarts.
class AssistantActivity extends StateNotifier<List<AssistantMessage>> {
  AssistantActivity(this._repository) : super(const []) {
    reload();
  }

  final AssistantRepository _repository;

  Future<void> reload() async {
    final messages = await _repository.recent(limit: 20);
    if (mounted) state = messages;
  }

  Future<void> record({
    required String text,
    required AssistantRole role,
    AssistantTurnSource source = AssistantTurnSource.text,
  }) async {
    if (text.trim().isEmpty) return;
    await _repository.insert(
      AssistantMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}-${role.name}',
        text: text,
        role: role,
        createdAt: DateTime.now(),
        source: source,
      ),
    );
    await reload();
  }
}
