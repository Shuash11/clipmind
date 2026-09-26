import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:clipmind/presentation/project_hub/project_hub_screen.dart';
import 'package:clipmind/presentation/editor/editor_screen.dart';
import 'package:clipmind/presentation/settings/settings_screen.dart';
import 'package:clipmind/features/providers/presentation/screens/ai_providers_screen.dart';

const String projectHubPath = '/';
const String editorPath = '/editor/:projectId';
const String settingsPath = '/settings';
const String aiProvidersPath = '/settings/providers';

final GlobalKey<NavigatorState> _rootNavigator = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigator,
  initialLocation: projectHubPath,
  routes: [
    GoRoute(
      path: projectHubPath,
      name: 'projectHub',
      builder: (context, state) => const ProjectHubScreen(),
    ),
    GoRoute(
      path: editorPath,
      name: 'editor',
      builder: (context, state) {
        final projectId = state.pathParameters['projectId'] ?? '';
        return EditorScreen(projectId: projectId);
      },
    ),
    GoRoute(
      path: settingsPath,
      name: 'settings',
      parentNavigatorKey: _rootNavigator,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: aiProvidersPath,
      name: 'aiProviders',
      parentNavigatorKey: _rootNavigator,
      builder: (context, state) => const AiProvidersScreen(),
    ),
  ],
);
