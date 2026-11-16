import 'package:flutter/foundation.dart';

/// The voice interaction state machine.
///
/// idle → listening → processing → speaking → idle
/// with cancel/repeat transitions available in every state. The state is a
/// plain immutable value so it can be unit-tested without a device.
enum AssistantStatus { idle, listening, processing, speaking }

@immutable
class AssistantState {
  const AssistantState({
    this.status = AssistantStatus.idle,
    this.transcript = '',
    this.reply = '',
    this.error,
    this.isMuted = false,
    this.lastUserText = '',
    this.lastAssistantText = '',
    this.repeatCount = 0,
    this.pendingConfirmation,
  });

  final AssistantStatus status;

  /// Live speech-to-text while listening; the final user utterance afterwards.
  final String transcript;

  /// The assistant's latest textual reply.
  final String reply;

  /// Persian, user-facing error message (never a raw exception).
  final String? error;

  final bool isMuted;
  final String lastUserText;
  final String lastAssistantText;

  /// Incremented on every «تکرار» press; the widget listens to it to replay TTS.
  final int repeatCount;

  /// When the agent needs the user to confirm a sensitive action.
  final PendingConfirmation? pendingConfirmation;

  bool get isBusy =>
      status == AssistantStatus.listening ||
      status == AssistantStatus.processing ||
      status == AssistantStatus.speaking;

  AssistantState copyWith({
    AssistantStatus? status,
    String? transcript,
    String? reply,
    String? error,
    bool clearError = false,
    bool? isMuted,
    String? lastUserText,
    String? lastAssistantText,
    int? repeatCount,
    PendingConfirmation? pendingConfirmation,
    bool clearConfirmation = false,
  }) =>
      AssistantState(
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
        reply: reply ?? this.reply,
        error: clearError ? null : (error ?? this.error),
        isMuted: isMuted ?? this.isMuted,
        lastUserText: lastUserText ?? this.lastUserText,
        lastAssistantText: lastAssistantText ?? this.lastAssistantText,
        repeatCount: repeatCount ?? this.repeatCount,
        pendingConfirmation: clearConfirmation
            ? null
            : (pendingConfirmation ?? this.pendingConfirmation),
      );
}

/// A sensitive action waiting for explicit user approval.
@immutable
class PendingConfirmation {
  const PendingConfirmation({
    required this.title,
    required this.summary,
    required this.actionLabel,
    required this.onConfirm,
    required this.onCancel,
    this.isDestructive = false,
  });

  final String title;

  /// Plain-language preview of exactly what will happen.
  final String summary;
  final String actionLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isDestructive;
}
