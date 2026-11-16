import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_recognizer.dart';

/// Android system speech recognition via the `speech_to_text` plugin.
///
/// Persian availability depends on the device: Google's recogniser supports
/// `fa-IR` on most phones, but some OEM builds ship without a Persian model or
/// without an offline model. [isPersianAvailable] reports the truth so the UI
/// can explain the limitation instead of mis-transcribing.
class NativeSpeechRecognizer implements SpeechRecognizer {
  NativeSpeechRecognizer({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _available = false;
  void Function(String message)? _onError;

  @override
  Future<bool> initialize() async {
    if (_available) return true;
    try {
      _available = await _speech.initialize(
        onError: _handleError,
        onStatus: (_) {},
        debugLogging: false,
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  @override
  Future<bool> isPersianAvailable() async {
    if (!await initialize()) return false;
    try {
      final locales = await _speech.locales();
      return locales.any((locale) => locale.localeId.replaceAll('_', '-').startsWith('fa'));
    } catch (_) {
      // The plugin cannot always enumerate locales; do not claim support, but
      // the recogniser itself is still asked for fa-IR below.
      return false;
    }
  }

  @override
  Future<bool> start({
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(String message) onError,
  }) async {
    if (!await initialize()) {
      onError('موتور تشخیص گفتار روی این دستگاه در دسترس نیست.');
      return false;
    }
    _onError = onError;
    try {
      final ok = await _speech.listen(
        localeId: 'fa_IR',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (SpeechRecognitionResult result) {
          if (result.finalResult) {
            onFinal(result.recognizedWords.trim());
          } else {
            onPartial(result.recognizedWords.trim());
          }
        },
      );
      if (!ok) onError('شروع ضبط صدا ناموفق بود. دوباره تلاش کن.');
      return ok;
    } catch (_) {
      onError('دسترسی به میکروفون امکان‌پذیر نشد. مجوز میکروفون را بررسی کن.');
      return false;
    }
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  @override
  Future<void> dispose() async {
    await _speech.cancel();
    _onError = null;
  }

  void _handleError(SpeechRecognitionError error) {
    final message = switch (error.errorMsg) {
      'error_no_match' => 'چیزی متوجه نشدم؛ دوباره بگو.',
      'error_speech_timeout' => 'صدایی شنیده نشد.',
      'error_network' => 'تشخیص گفتار به اینترنت نیاز دارد و اتصال برقرار نیست.',
      'error_permission' => 'مجوز میکروفون داده نشده است.',
      'error_busy' => 'تشخیص گفتار مشغول است؛ کمی بعد دوباره تلاش کن.',
      _ => 'خطا در تشخیص گفتار: ${error.errorMsg}',
    };
    _onError?.call(message);
  }
}
