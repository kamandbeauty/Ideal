/// Provider-agnostic speech-to-text contract.
///
/// Implementations must be swappable: the MVP ships [NativeSpeechRecognizer]
/// (Android's system recogniser, which supports Persian `fa-IR`), and a cloud
/// provider can be added without touching the assistant UI.
abstract class SpeechRecognizer {
  /// Whether the platform recogniser exists and can be used on this device.
  Future<bool> initialize();

  /// Whether a Persian (`fa-IR`) model is actually available. When false the UI
  /// must say so honestly instead of silently transcribing another language.
  Future<bool> isPersianAvailable();

  /// Starts listening. [onPartial] receives live hypotheses, [onFinal] the
  /// final transcript. Returns false when listening could not start.
  Future<bool> start({
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(String message) onError,
  });

  /// Stops listening and (where supported) finalises the current utterance.
  Future<void> stop();

  /// Cancels listening and discards captured audio.
  Future<void> cancel();

  Future<void> dispose();
}
