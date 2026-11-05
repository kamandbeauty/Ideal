/// User-facing error model.
///
/// Every failure carries a stable [code] that maps to a localized message, plus
/// a [technicalDetail] that is logged (and shown behind "details") but never the
/// only thing the user sees (product brief §17).
library;

enum FailureKind {
  photoUnreadable,
  photoMissing,
  unsupportedFormat,
  outOfMemory,
  outOfStorage,
  codecUnsupported,
  resolutionUnsupported,
  encoderFailed,
  muxerFailed,
  cancelled,
  permissionDenied,
  audioUnreadable,
  glFailed,
  internal,
  unknown;

  String get messageKey => 'error_$name';

  /// Whether the user can plausibly fix it, which decides the action buttons.
  bool get isRecoverable => switch (this) {
        FailureKind.codecUnsupported => true,
        FailureKind.resolutionUnsupported => true,
        FailureKind.outOfStorage => true,
        FailureKind.photoMissing => true,
        FailureKind.photoUnreadable => true,
        FailureKind.audioUnreadable => true,
        FailureKind.permissionDenied => true,
        FailureKind.outOfMemory => true,
        _ => false,
      };
}

class AppFailure implements Exception {
  const AppFailure(
    this.kind, {
    this.technicalDetail,
    this.photoId,
    this.recoverableWith,
  });

  final FailureKind kind;
  final String? technicalDetail;
  final String? photoId;

  /// Suggestion shown to the user, e.g. "try 1080p instead of 4K".
  final String? recoverableWith;

  String get messageKey => kind.messageKey;

  factory AppFailure.fromNative(Object error) {
    final text = error.toString();
    // The Kotlin side reports "<FAILURE_CODE>|<detail>".
    final parts = text.split('|');
    final code = parts.first.replaceFirst(RegExp(r'^.*?Exception:?\s*'), '').trim();
    final detail = parts.length > 1 ? parts.sublist(1).join('|') : text;
    final kind = switch (code) {
      'PHOTO_UNREADABLE' => FailureKind.photoUnreadable,
      'PHOTO_MISSING' => FailureKind.photoMissing,
      'UNSUPPORTED_FORMAT' => FailureKind.unsupportedFormat,
      'OUT_OF_MEMORY' => FailureKind.outOfMemory,
      'OUT_OF_STORAGE' => FailureKind.outOfStorage,
      'CODEC_UNSUPPORTED' => FailureKind.codecUnsupported,
      'RESOLUTION_UNSUPPORTED' => FailureKind.resolutionUnsupported,
      'ENCODER_FAILED' => FailureKind.encoderFailed,
      'MUXER_FAILED' => FailureKind.muxerFailed,
      'CANCELLED' => FailureKind.cancelled,
      'PERMISSION_DENIED' => FailureKind.permissionDenied,
      'AUDIO_UNREADABLE' => FailureKind.audioUnreadable,
      'GL_FAILED' => FailureKind.glFailed,
      _ => FailureKind.unknown,
    };
    return AppFailure(kind, technicalDetail: detail);
  }

  @override
  String toString() => 'AppFailure(${kind.name})'
      '${technicalDetail == null ? '' : ': $technicalDetail'}';
}
