import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_notification.dart';
import '../../data/repositories/settings_repository.dart';
import 'database_provider.dart';

/// Every persisted preference key, in one place.
abstract final class SettingsKeys {
  static const themeMode = 'theme_mode';
  static const displayName = 'display_name';
  static const aiProvider = 'ai_provider';
  static const aiBaseUrl = 'ai_base_url';
  static const aiModel = 'ai_model';
  static const cloudAiEnabled = 'cloud_ai_enabled';
  static const sendNotificationsToAi = 'send_notifications_to_ai';
  static const sttProvider = 'stt_provider';
  static const ttsProvider = 'tts_provider';
  static const ttsRate = 'tts_rate';
  static const ttsPitch = 'tts_pitch';
  static const onboardingDone = 'onboarding_done';
  static const notificationRetentionDays = 'notification_retention_days';
  static const speakReplies = 'speak_replies';
  static const notificationSourcePrefix = 'notification_source_';
  static const accessibilityConfirmed = 'accessibility_confirmed';
}

/// Theme mode preference.
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(settingsRepositoryProvider));
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._repository) : super(ThemeMode.dark) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    final raw = await _repository.read(SettingsKeys.themeMode);
    if (raw == 'light') state = ThemeMode.light;
    if (raw == 'system') state = ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _repository.write(
      SettingsKeys.themeMode,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      },
    );
  }
}

/// Whether a given notification source is enabled by the user.
final notificationSourceProvider =
    StateNotifierProvider<NotificationSourceController, Map<NotificationSource, bool>>(
        (ref) {
  return NotificationSourceController(ref.watch(settingsRepositoryProvider));
});

class NotificationSourceController
    extends StateNotifier<Map<NotificationSource, bool>> {
  NotificationSourceController(this._repository)
      : super({
          for (final source in NotificationSource.values) source: source != NotificationSource.other,
        }) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    final next = Map<NotificationSource, bool>.from(state);
    for (final source in NotificationSource.values) {
      final raw =
          await _repository.read('${SettingsKeys.notificationSourcePrefix}${source.name}');
      if (raw != null) next[source] = raw == 'true';
    }
    state = next;
  }

  Future<void> toggle(NotificationSource source, bool enabled) async {
    state = {...state, source: enabled};
    await _repository.write(
      '${SettingsKeys.notificationSourcePrefix}${source.name}',
      enabled.toString(),
    );
  }

  bool isEnabled(NotificationSource source) => state[source] ?? false;
}

/// Whether assistant replies are spoken aloud (default: yes).
final speakRepliesProvider = StateNotifierProvider<BoolSettingController, bool>((ref) {
  return BoolSettingController(
    ref.watch(settingsRepositoryProvider),
    key: SettingsKeys.speakReplies,
    fallback: true,
  );
});

/// Whether cloud AI is allowed at all (default: no – local-first).
final cloudAiEnabledProvider =
    StateNotifierProvider<BoolSettingController, bool>((ref) {
  return BoolSettingController(
    ref.watch(settingsRepositoryProvider),
    key: SettingsKeys.cloudAiEnabled,
    fallback: false,
  );
});

/// Whether notification contents may be sent to a cloud AI (default: no).
final sendNotificationsToAiProvider =
    StateNotifierProvider<BoolSettingController, bool>((ref) {
  return BoolSettingController(
    ref.watch(settingsRepositoryProvider),
    key: SettingsKeys.sendNotificationsToAi,
    fallback: false,
  );
});

/// Reusable boolean preference controller.
class BoolSettingController extends StateNotifier<bool> {
  BoolSettingController(
    this._repository, {
    required this.key,
    required bool fallback,
  })  : _fallback = fallback,
        super(fallback) {
    _load();
  }

  final SettingsRepository _repository;
  final String key;
  final bool _fallback;

  Future<void> _load() async {
    final value = await _repository.readBool(key, fallback: _fallback);
    if (mounted) state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    await _repository.writeBool(key, value);
  }
}
