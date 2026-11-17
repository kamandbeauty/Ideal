import 'package:flutter/cupertino.dart' show GlobalCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/settings_providers.dart';
import '../core/theme/app_theme.dart';
import '../l10n/persian_material_localizations.dart';
import 'router.dart';

/// Root widget: Persian-only localisation, RTL text direction, Vazirmatn type
/// and the two brand themes.
class JavidApp extends ConsumerWidget {
  const JavidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'JavidAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      // GlobalMaterialLocalizations delegates are required as well: without them
      // any widget that needs Cupertino/Material strings logs a "locale not
      // supported by all delegates" warning, and the Persian class only has to
      // override what actually differs.
      localizationsDelegates: const [
        PersianMaterialLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Force a right-to-left layout regardless of the device locale.
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.4,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const AppShell(),
    );
  }
}
