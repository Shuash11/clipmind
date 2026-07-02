import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/clipmind_theme.dart';

class ClipMindApp extends ConsumerWidget {
  const ClipMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'ClipMind',
      debugShowCheckedModeBanner: false,
      theme: ClipMindTheme.dark,
      routerConfig: appRouter,
    );
  }
}
