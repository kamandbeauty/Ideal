import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/export_settings.dart';
import '../../core/storage/app_settings_store.dart';

class SettingsController extends StateNotifier<AppPreferences> {
  SettingsController(this._store, AppPreferences initial)
      : super(initial);

  final AppSettingsStore _store;

  Future<void> setLocale(String code) async {
    state = state.copyWith(localeCode: code);
    await _store.save(state);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _store.save(state);
  }

  Future<void> setDefaultIntensity(double v) async {
    state = state.copyWith(defaultIntensity: v.clamp(0.0, 1.0));
    await _store.save(state);
  }

  Future<void> setDefaultPhotoDuration(double v) async {
    state = state.copyWith(defaultPhotoDuration: v);
    await _store.save(state);
  }

  Future<void> setDefaultExport(ExportSettings settings) async {
    state = state.copyWith(defaultExport: settings);
    await _store.save(state);
  }

  Future<void> resetAll() async {
    await _store.save(state);
  }

  Future<void> markOnboardingSeen() async {
    state = state.copyWith(hasSeenOnboarding: true);
    await _store.markOnboardingSeen();
  }
}
