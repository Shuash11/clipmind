import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/runtime/local_smoke_launch_configuration.dart';
import 'core/theme/clipmind_theme.dart';
import 'features/projects/presentation/local_smoke_screen.dart';
import 'features/providers/data/provider_platform_riverpod.dart';

class ClipMindApp extends ConsumerWidget {
  const ClipMindApp({super.key, this.localSmokeConfiguration});

  final LocalSmokeLaunchConfiguration? localSmokeConfiguration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configuration = localSmokeConfiguration;
    if (configuration != null) {
      final providerInitialization = ref.watch(
        providerPlatformBootstrapResultProvider,
      );
      return MaterialApp(
        title: 'ClipMind',
        debugShowCheckedModeBanner: false,
        theme: ClipMindTheme.dark,
        home: LocalSmokeScreen.forConfiguration(
          configuration: configuration,
          providerInitialization: providerInitialization,
        ),
      );
    }
    return MaterialApp.router(
      title: 'ClipMind',
      debugShowCheckedModeBanner: false,
      theme: ClipMindTheme.dark,
      routerConfig: appRouter,
    );
  }
}
