import 'package:flutter/services.dart';

/// Channel to the Android host for capabilities Flutter plugins do not cover.
///
/// All methods degrade gracefully on non-Android platforms and in tests, so the
/// rest of the app can call them unconditionally.
class NativeBridge {
  NativeBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('ai.javid.app/native');

  final MethodChannel _channel;

  /// Whether the user allowed JavidAI to read notifications.
  Future<bool> hasNotificationAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasNotificationAccess') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system "notification access" settings screen.
  Future<bool> openNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Whether the app is exempt from battery optimisation (affects reliability
  /// of scheduled jobs).
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests battery optimisation exemption (opens the system dialog).
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches the most recent notifications captured by the listener while the
  /// app was in the background and stores nothing itself.
  Future<List<Map<String, Object?>>> fetchCapturedNotifications({int limit = 50}) async {
    try {
      final result = await _channel.invokeListMethod<Object?>(
        'fetchCapturedNotifications',
        {'limit': limit},
      );
      return result
              ?.whereType<Map<Object?, Object?>>()
              .map((raw) => raw.map((key, value) => MapEntry('$key', value)))
              .toList(growable: false) ??
          const [];
    } catch (_) {
      return const [];
    }
  }

  /// Posts a local notification (used by reminders).
  Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('showNotification', {
            'id': id,
            'title': title,
            'body': body,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Schedules (or replaces) the native alarm that makes reminders fire even
  /// when the app is not running.
  Future<bool> scheduleReminder({
    required int reminderId,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('scheduleReminder', {
            'id': reminderId,
            'title': title,
            'body': body,
            'atMillis': fireAt.millisecondsSinceEpoch,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelReminder(int reminderId) async {
    try {
      return await _channel.invokeMethod<bool>(
            'cancelReminder',
            {'id': reminderId},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// A short description of the device for the settings/diagnostics screen.
  Future<String?> deviceSummary() async {
    try {
      return await _channel.invokeMethod<String>('deviceSummary');
    } catch (_) {
      return null;
    }
  }
}

final nativeBridge = NativeBridge();
