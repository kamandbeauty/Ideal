/// GoRouter configuration. All routes are plain paths so deep links from a
/// saved project or a notification tap land in the right place.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/audio/audio_sheet.dart';
import '../features/editor/editor_screen.dart';
import '../features/export/export_screen.dart';
import '../features/export/export_progress_screen.dart';
import '../features/gallery/gallery_screen.dart';
import '../features/home/home_screen.dart';
import '../features/motion/motion_editor_screen.dart';
import '../features/motion/path_editor_screen.dart';
import '../features/preview/preview_screen.dart';
import '../features/settings/settings_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const String home = '/';
  static const String gallery = '/gallery';
  static const String editor = '/editor';
  static const String motionEditor = '/editor/motion';
  static const String pathEditor = '/editor/motion/path';
  static const String preview = '/preview';
  static const String export = '/export';
  static const String exportProgress = '/export/progress';
  static const String settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.gallery,
        builder: (BuildContext context, GoRouterState state) =>
            const GalleryScreen(),
      ),
      GoRoute(
        path: AppRoutes.editor,
        builder: (BuildContext context, GoRouterState state) =>
            const EditorScreen(),
      ),
      GoRoute(
        path: AppRoutes.motionEditor,
        builder: (BuildContext context, GoRouterState state) {
          final photoId = state.uri.queryParameters['photo'];
          return MotionEditorScreen(photoId: photoId);
        },
      ),
      GoRoute(
        path: AppRoutes.pathEditor,
        builder: (BuildContext context, GoRouterState state) {
          final photoId = state.uri.queryParameters['photo'];
          return PathEditorScreen(photoId: photoId);
        },
      ),
      GoRoute(
        path: AppRoutes.preview,
        builder: (BuildContext context, GoRouterState state) =>
            const PreviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.export,
        builder: (BuildContext context, GoRouterState state) =>
            const ExportScreen(),
      ),
      GoRoute(
        path: AppRoutes.exportProgress,
        builder: (BuildContext context, GoRouterState state) =>
            const ExportProgressScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.link_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text('Route not found: ${state.uri}'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
