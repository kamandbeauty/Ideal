import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// Android TTS engine wrapper (device voices, offline-capable).
///
/// Persian (`fa-IR`) voices ship with Google Speech Services on most devices,
/// but not all: [initialize] checks for an actual `fa` voice and returns a clear
/// Persian message when the user needs to install one.
class NativeTtsEngine implements TtsEngine {
  NativeTtsEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  TtsAvailability? _cached;

  @override
  Future<TtsAvailability> initialize() async {
    if (_cached != null) return _cached!;
    try {
      await _tts.awaitSynthCompletion(false);
      final isLanguageAvailable = await _tts.isLanguageAvailable('fa-IR');
      final voices = await _tts.getVoices;
      String? persianVoice;
      if (voices is List) {
        for (final voice in voices) {
          if (voice is Map && '${voice['locale']}'.toLowerCase().startsWith('fa')) {
            persianVoice = '${voice['name']}';
            break;
          }
        }
      }
      final available = isLanguageAvailable == true || persianVoice != null;
      _cached = available
          ? TtsAvailability(available: true, voiceName: persianVoice ?? 'fa-IR')
          : const TtsAvailability.unavailable(
              'صدای فارسی روی این دستگاه نصب نیست. از تنظیمات اندروید، '
              'بستهٔ «تبدیل متن به گفتار Google» و زبان فارسی را نصب کن.',
            );
      if (available) {
        await _tts.setLanguage('fa-IR');
        await _tts.setSpeechRate(0.5);
        await _tts.setPitch(1.0);
      }
      return _cached!;
    } catch (_) {
      _cached = const TtsAvailability.unavailable(
        'موتور تبدیل متن به گفتار در دسترس نیست.',
      );
      return _cached!;
    }
  }

  @override
  Future<void> speak(String text, {void Function()? onDone}) async {
    if (text.trim().isEmpty) return;
    final availability = await initialize();
    if (!availability.available) return;
    try {
      await _tts.stop();
      _tts.setCompletionHandler(() => onDone?.call());
      _tts.setCancelHandler(() => onDone?.call());
      _tts.setErrorHandler((dynamic message) => onDone?.call());
      await _tts.speak(text);
    } catch (_) {
      onDone?.call();
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Stopping an idle engine is not an error.
    }
  }

  @override
  Future<void> setRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.2, 1.0));
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
  }

  @override
  Future<void> dispose() => stop();
}
