import 'package:flutter/services.dart';

/// Machine-readable failure codes. The UI maps them to Persian copy; logs keep
/// the code so a bug report is actionable.
enum AppErrorCode {
  unknown,
  database,
  cancelled,
  permissionDenied,
  unsupportedFormat,
  fileMissing,
  nativeFailure,
  notImplementedYet,
  validation,
}

class AppFailure implements Exception {
  const AppFailure(this.code, this.message, {this.cause});

  final AppErrorCode code;
  final String message;
  final Object? cause;

  factory AppFailure.fromPlatform(Object error) {
    if (error is PlatformException) {
      if (error.code == 'cancelled') {
        return const AppFailure(AppErrorCode.cancelled, 'عملیات لغو شد.');
      }
      return AppFailure(
        AppErrorCode.nativeFailure,
        error.message ?? 'خطای لایه بومی رخ داد.',
        cause: error,
      );
    }
    return AppFailure(AppErrorCode.unknown, 'خطای غیرمنتظره رخ داد.', cause: error);
  }

  @override
  String toString() => 'AppFailure(${code.name}): $message';
}
