import 'package:go_router/go_router.dart';

import '../features/editor/editor_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/projects/project_list_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/video_import/video_import_screen.dart';

/// Routes for Phase 1. Later phases add `/project/:id/transcript`,
/// `/project/:id/subtitles`, `/project/:id/effects`, `/project/:id/export`.
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
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);
