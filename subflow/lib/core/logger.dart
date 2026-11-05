import 'package:flutter/foundation.dart';

/// Thin logging facade. Kept dependency-free and quiet in release builds; the
/// export/transcription pipelines log through this so a support log can be
/// attached to a bug report.
class SfLog {
  const SfLog(this.tag);

  final String tag;

  void d(String message) {
    if (kDebugMode) debugPrint('[SF/$tag] $message');
  }

  void e(String message, [Object? error, StackTrace? stack]) {
    debugPrint('[SF/$tag] ERROR $message');
    if (error != null) debugPrint('  cause: $error');
    if (stack != null) debugPrint('$stack');
  }
}
