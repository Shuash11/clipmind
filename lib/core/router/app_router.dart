import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:clipmind/presentation/project_hub/project_hub_screen.dart';
import 'package:clipmind/presentation/editor/editor_screen.dart';

const String projectHubPath = '/';
const String editorPath = '/editor/:projectId';
const String settingsPath = '/settings';

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
  ],
);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings - Coming soon')),
    );
  }
}
