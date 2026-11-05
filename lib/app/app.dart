/// The root widget: localization, theming and routing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/export_settings.dart';
import '../core/storage/app_settings_store.dart';
import 'l10n/strings.dart';
import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class MotionShotApp extends ConsumerStatefulWidget {
  const MotionShotApp({super.key});

  @override
  ConsumerState<MotionShotApp> createState() => _MotionShotAppState();
}

class _MotionShotAppState extends ConsumerState<MotionShotApp> {
  late final GoRouter _router = ref.read(routerProvider);

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(settingsProvider);
    final localeCode = ref.watch(appLocaleProvider);
    return MaterialApp.router(
      title: 'MotionShot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: prefs.themeMode,
      locale: Locale(localeCode),
      supportedLocales: const <Locale>[Locale('fa'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      builder: (BuildContext context, Widget? child) {
        // Persian needs right-to-left layout; Flutter's localization delegate
        // handles that via the locale, this keeps text direction consistent
        // even in nested overlays.
        return Directionality(
          textDirection:
              L10n(localeCode).isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Re-exported so `main.dart` needs a single import.
typedef BootstrapSettings = AppPreferences;

/// Helper used by main to build the initial preferences object.
AppPreferences defaultPreferences() => const AppPreferences(
      localeCode: 'fa',
      themeMode: ThemeMode.dark,
      defaultExport: ExportSettings(),
      defaultIntensity: 0.6,
      defaultPhotoDuration: 5.0,
      hasSeenOnboarding: false,
    );
