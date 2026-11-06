import 'package:go_router/go_router.dart';

import '../features/asr/asr_screen.dart';
import '../features/editor/editor_screen.dart';
import '../features/effects/caption_gallery_screen.dart';
import '../features/home/home_screen.dart';
import '../features/projects/project_list_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/subtitles/subtitle_studio_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/video_import/video_import_screen.dart';

/// Routes. `/captions` is the caption look gallery: it pushes a `CaptionPreset`
/// back to the caller and is the only place a style is chosen, so the editor,
/// the gallery previews and (Phase 6) the native renderer all read one model.
/// `/project/:id/asr` runs offline Whisper on the project's video,
/// `/project/:id/subtitles` is the editing studio.
final GoRouter subFlowRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    // Bottom-bar frame: projects, caption looks, settings. Every deeper screen
    // is pushed on top so tab state survives, which is how short-form editors
    // behave and why there is no welcome carousel in front of it.
    StatefulShellRoute.indexedStack(
      builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) =>
          AppShell(navigationShell: shell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[GoRoute(path: '/home', builder: (_, __) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/styles',
              builder: (_, __) => const CaptionGalleryScreen(embedded: true),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          ],
        ),
      ],
    ),
    GoRoute(path: '/projects', builder: (_, __) => const ProjectListScreen()),
    GoRoute(path: '/import', builder: (_, __) => const VideoImportScreen()),
    GoRoute(
      path: '/project/:id',
      builder: (_, GoRouterState state) =>
          EditorScreen(projectId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/project/:id/asr',
      builder: (_, GoRouterState state) =>
          AsrScreen(projectId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/project/:id/subtitles',
      builder: (_, GoRouterState state) =>
          SubtitleStudioScreen(projectId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(path: '/captions', builder: (_, __) => const CaptionGalleryScreen()),
  ],
);
