/// MotionShot entry point.
///
/// Bootstraps storage, preferences and services before the first frame so no
/// screen ever has to deal with "not ready" states, then hands over to the app.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/services/media_picker_service.dart';
import 'core/services/thumbnail_service.dart';
import 'core/storage/app_settings_store.dart';
import 'core/storage/project_repository.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-first tool, but never lock the user out of landscape editing.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  FlutterError.onError = (FlutterErrorDetails details) {
    // Keep the raw trace in the log; screens show localized messages.
    debugPrint('FlutterError: ${details.exception}');
    debugPrint(details.stack.toString());
    FlutterError.presentError(details);
  };

  try {
    final docs = await getApplicationDocumentsDirectory();
    final cache = await getTemporaryDirectory();
    final appDir = Directory(p.join(docs.path, 'motionshot'));
    await appDir.create(recursive: true);

    final repository = await ProjectRepository.open(appDir: appDir);
    final settingsStore = await AppSettingsStore.open();
    final thumbs = ThumbnailService(
      cacheDir: Directory(p.join(cache.path, 'thumbs')),
      targetWidth: 640,
    );
    await thumbs.cacheDir.create(recursive: true);
    final picker = MediaPickerService(projectsDir: appDir);

    final prefs = settingsStore.load();
    final bootstrap = AppBootstrap(
      repository: repository,
      settingsStore: settingsStore,
      thumbs: thumbs,
      mediaPicker: picker,
      settingsController: SettingsController(settingsStore, prefs),
    );

    runApp(
      ProviderScope(
        overrides: <Override>[
          bootstrapProvider.overrideWithValue(bootstrap),
        ],
        child: const MotionShotApp(),
      ),
    );
  } catch (e, st) {
    debugPrint('startup failed: $e\n$st');
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text('MotionShot could not start',
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text(
                    'The local storage could not be opened. Restarting the app '
                    'usually fixes this.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SelectableText('$e',
                      style: const TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
