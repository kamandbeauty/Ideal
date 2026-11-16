/// Provider-agnostic text-to-speech contract.
///
/// The MVP uses the device's Android TTS engine ([NativeTtsEngine]); a cloud
/// provider (e.g. Azure `fa-IR-DilaraNeural`) can be added later behind the
/// same interface.
abstract class TtsEngine {
  /// Returns whether a Persian voice is installed and usable.
  Future<TtsAvailability> initialize();

  /// Speaks [text]; completes when speech starts. [onDone] fires when the
  /// utterance finishes (or is stopped).
  Future<void> speak(String text, {void Function()? onDone});

  Future<void> stop();

  Future<void> setRate(double rate);

  Future<void> setPitch(double pitch);

  Future<void> dispose();
}

/// Availability of a Persian voice, with an actionable message for the UI.
class TtsAvailability {
  const TtsAvailability({
    required this.available,
    this.voiceName,
    this.message,
  });

  const TtsAvailability.unavailable(String this.message)
      : available = false,
        voiceName = null;

  final bool available;
  final String? voiceName;
  final String? message;
}
