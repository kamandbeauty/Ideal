import 'package:go_router/go_router.dart';

import '../features/editor/editor_screen.dart';
import '../features/effects/caption_gallery_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/projects/project_list_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/subtitles/subtitle_studio_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/video_import/video_import_screen.dart';

/// Routes. `/captions` is the caption look gallery: it pushes a `CaptionPreset`
/// back to the caller and is the only place a style is chosen, so the editor,
/// the gallery previews and (Phase 6) the native renderer all read one model.
/// Later phases add `/project/:id/transcript`, `/project/:id/subtitles`,
/// `/project/:id/export`.
final GoRouter subFlowRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/projects', builder: (_, __) => const ProjectListScreen()),
    GoRoute(path: '/import', builder: (_, __) => const VideoImportScreen()),
    GoRoute(
      path: '/project/:id',
      builder: (_, GoRouterState state) =>
          EditorScreen(projectId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/project/:id/subtitles',
      builder: (_, GoRouterState state) =>
          SubtitleStudioScreen(projectId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(path: '/captions', builder: (_, __) => const CaptionGalleryScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);
