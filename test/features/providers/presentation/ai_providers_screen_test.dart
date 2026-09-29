import 'dart:async';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/features/providers/presentation/screens/ai_providers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../support/provider_presentation_fakes.dart';

void main() {
  testWidgets('shows the local, secure empty provider state', (tester) async {
    final repository = MemoryProfileRepository(
      ProviderProfilesDocument(schemaVersion: 1, profiles: const []),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerPlatformBootstrapResultProvider.overrideWithValue(
            Success(
              ProviderPlatformBootstrapResult(
                FakeProviderRegistry(),
                repository: repository,
                credentials: MemoryCredentialStore(),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: ClipMindTheme.dark,
          home: const AiProvidersScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-providers-screen')), findsOneWidget);
    expect(
      find.text(
        'Profiles are local to ClipMind. Credentials use secure storage.',
      ),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('add-provider-profile')), findsOneWidget);
  });

  testWidgets(
    'renders the selected custom configuration surface without network work',
    (tester) async {
      final profile = ProviderProfile(
        id: 'custom-profile',
        providerId: 'custom',
        displayName: 'Studio relay',
        endpoint: Uri.parse('https://relay.example.test/v1'),
      );
      final repository = MemoryProfileRepository(
        ProviderProfilesDocument(
          schemaVersion: 1,
          profiles: [profile],
          activeProfileId: profile.id,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerPlatformBootstrapResultProvider.overrideWithValue(
              Success(
                ProviderPlatformBootstrapResult(
                  FakeProviderRegistry(),
                  profiles: [profile],
                  activeProfileId: profile.id,
                  repository: repository,
                  credentials: MemoryCredentialStore(),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: ClipMindTheme.dark,
            home: const AiProvidersScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('custom-provider-form')),
        findsOneWidget,
      );
      expect(find.text('Studio relay'), findsWidgets);
    },
  );

  testWidgets(
    'offers a back button that navigates to settings from a shallow route',
    (tester) async {
      final repository = MemoryProfileRepository(
        ProviderProfilesDocument(schemaVersion: 1, profiles: const []),
      );
      // Mirrors the app router's structure: /settings/providers is a
      // top-level GoRoute the app reaches via context.go(), which replaces
      // the stack — so no automatic back arrow appears.
      final router = GoRouter(
        navigatorKey: GlobalKey<NavigatorState>(),
        initialLocation: aiProvidersPath,
        routes: [
          GoRoute(
            path: settingsPath,
            builder: (context, state) => const _SettingsPlaceholder(),
          ),
          GoRoute(
            path: aiProvidersPath,
            builder: (context, state) => const AiProvidersScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerPlatformBootstrapResultProvider.overrideWithValue(
              Success(
                ProviderPlatformBootstrapResult(
                  FakeProviderRegistry(),
                  repository: repository,
                  credentials: MemoryCredentialStore(),
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: ClipMindTheme.dark,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-providers-back')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ai-providers-back')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-placeholder')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ai-providers-screen')), findsNothing);
    },
  );

  testWidgets(
    'pops back to settings when the providers route was pushed',
    (tester) async {
      final repository = MemoryProfileRepository(
        ProviderProfilesDocument(schemaVersion: 1, profiles: const []),
      );
      final router = GoRouter(
        navigatorKey: GlobalKey<NavigatorState>(),
        initialLocation: settingsPath,
        routes: [
          GoRoute(
            path: settingsPath,
            builder: (context, state) => const _SettingsPlaceholder(),
          ),
          GoRoute(
            path: aiProvidersPath,
            builder: (context, state) => const AiProvidersScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerPlatformBootstrapResultProvider.overrideWithValue(
              Success(
                ProviderPlatformBootstrapResult(
                  FakeProviderRegistry(),
                  repository: repository,
                  credentials: MemoryCredentialStore(),
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: ClipMindTheme.dark,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-placeholder')),
        findsOneWidget,
      );
      unawaited(router.push(aiProvidersPath));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-providers-back')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ai-providers-back')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-placeholder')),
        findsOneWidget,
      );
    },
  );
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();
  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('settings-placeholder'),
    appBar: AppBar(title: const Text('Settings')),
  );
}
