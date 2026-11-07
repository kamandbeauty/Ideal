/// Persistent app preferences (Settings screen, product brief §13).
library;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/export_settings.dart';

class AppPreferences {
  const AppPreferences({
    required this.localeCode,
    required this.themeMode,
    required this.defaultExport,
    required this.defaultIntensity,
    required this.defaultPhotoDuration,
    required this.hasSeenOnboarding,
  });

  final String localeCode; // 'fa', 'en' or 'system'
  final ThemeMode themeMode;
  final ExportSettings defaultExport;
  final double defaultIntensity;
  final double defaultPhotoDuration;
  final bool hasSeenOnboarding;

  AppPreferences copyWith({
    String? localeCode,
    ThemeMode? themeMode,
    ExportSettings? defaultExport,
    double? defaultIntensity,
    double? defaultPhotoDuration,
    bool? hasSeenOnboarding,
  }) =>
      AppPreferences(
        localeCode: localeCode ?? this.localeCode,
        themeMode: themeMode ?? this.themeMode,
        defaultExport: defaultExport ?? this.defaultExport,
        defaultIntensity: defaultIntensity ?? this.defaultIntensity,
        defaultPhotoDuration: defaultPhotoDuration ?? this.defaultPhotoDuration,
        hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      );
}

class AppSettingsStore {
  AppSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppSettingsStore> open() async =>
      AppSettingsStore(await SharedPreferences.getInstance());

  static const String _kLocale = 'locale';
  static const String _kTheme = 'themeMode';
  static const String _kExport = 'defaultExport';
  static const String _kIntensity = 'defaultIntensity';
  static const String _kDuration = 'defaultPhotoDuration';
  static const String _kOnboarding = 'hasSeenOnboarding';

  AppPreferences load() {
    ThemeMode theme = ThemeMode.dark;
    switch (_prefs.getString(_kTheme)) {
      case 'light':
        theme = ThemeMode.light;
      case 'system':
        theme = ThemeMode.system;
      default:
        theme = ThemeMode.dark;
    }
    ExportSettings export = const ExportSettings();
    final raw = _prefs.getString(_kExport);
    if (raw != null) {
      try {
        export = exportSettingsFromPreferences(raw);
      } on FormatException {
        export = const ExportSettings();
      }
    }
    return AppPreferences(
      localeCode: _prefs.getString(_kLocale) ?? 'fa',
      themeMode: theme,
      defaultExport: export,
      defaultIntensity:
          _prefs.getDouble(_kIntensity) ?? AppLimits.defaultMotionIntensity,
      defaultPhotoDuration:
          _prefs.getDouble(_kDuration) ?? AppLimits.defaultPhotoDuration,
      hasSeenOnboarding: _prefs.getBool(_kOnboarding) ?? false,
    );
  }

  Future<void> save(AppPreferences prefs) async {
    await _prefs.setString(_kLocale, prefs.localeCode);
    await _prefs.setString(_kTheme, switch (prefs.themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    });
    await _prefs.setString(_kExport, prefs.defaultExport.encode());
    await _prefs.setDouble(_kIntensity, prefs.defaultIntensity);
    await _prefs.setDouble(_kDuration, prefs.defaultPhotoDuration);
    await _prefs.setBool(_kOnboarding, prefs.hasSeenOnboarding);
  }

  Future<void> markOnboardingSeen() async =>
      _prefs.setBool(_kOnboarding, true);
}
