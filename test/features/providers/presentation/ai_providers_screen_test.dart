import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/features/providers/presentation/screens/ai_providers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
