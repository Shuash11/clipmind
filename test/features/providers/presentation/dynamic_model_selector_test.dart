import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_codec.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_capabilities.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/features/providers/presentation/providers/provider_profile_notifier.dart';
import 'package:clipmind/features/providers/presentation/widgets/dynamic_model_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/provider_presentation_fakes.dart';

void main() {
  testWidgets(
    'persists a manually entered model when discovery is unavailable',
    (tester) async {
      final profile = ProviderProfile(
        id: 'local',
        providerId: 'missing',
        displayName: 'Local',
        endpoint: Uri.parse('https://example.test'),
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
            home: const Scaffold(body: DynamicModelSelector()),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dynamic-model-selector')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('manual-model-id')),
        'local-model',
      );
      await tester.tap(find.text('Use model'));
      await tester.pump();
      expect(
        repository.document.profiles.single.manualModelIds,
        contains('local-model'),
      );
      expect(
        repository.document.profiles.single.selectedModelId,
        'local-model',
      );
    },
  );

  test(
    'retains manual models and exposes the exact discovery fallback',
    () async {
      final profile = ProviderProfile(
        id: 'local',
        providerId: 'manual',
        displayName: 'Local',
        endpoint: Uri.parse('https://example.test'),
        manualModelIds: const ['manual-model'],
      );
      final repository = MemoryProfileRepository(
        ProviderProfilesDocument(
          schemaVersion: 1,
          profiles: [profile],
          activeProfileId: profile.id,
        ),
      );
      final notifier = ProviderProfileNotifier(
        repository: repository,
        credentials: MemoryCredentialStore(),
        registry: FakeProviderRegistry(definitions: [_manualDefinition]),
        cancellationControllerFactory: () => CancellationController(),
        idFactory: () => 'next',
      );
      await notifier.load();
      await notifier.discoverModels(profile.id);
      expect(
        notifier.state.failureMessage,
        'Discovery unavailable; enter a model ID.',
      );
      expect(notifier.state.manualModels, contains('manual-model'));
      await notifier.addManualModel(profile.id, 'manual-two');
      expect(repository.document.profiles.single.selectedModelId, 'manual-two');
    },
  );

  test(
    'deduplicates discovery and persists the selected discovered model',
    () async {
      final profile = ProviderProfile(
        id: 'remote',
        providerId: 'openai',
        displayName: 'Remote',
        endpoint: Uri.parse('https://example.test'),
        manualModelIds: const ['duplicate'],
      );
      final repository = MemoryProfileRepository(
        ProviderProfilesDocument(
          schemaVersion: 1,
          profiles: [profile],
          activeProfileId: profile.id,
        ),
      );
      final notifier = ProviderProfileNotifier(
        repository: repository,
        credentials: MemoryCredentialStore(),
        registry: FakeProviderRegistry(
          definitions: [_discoveringDefinition],
          adapter: DiscoveringAdapter(<ModelDescriptor>[
            ModelDescriptor(
              id: 'duplicate',
              providerId: 'openai',
              displayName: 'Duplicate',
            ),
            ModelDescriptor(
              id: 'remote-model',
              providerId: 'openai',
              displayName: 'Remote model',
            ),
            ModelDescriptor(
              id: 'remote-model',
              providerId: 'openai',
              displayName: 'Repeated',
            ),
          ]),
        ),
        cancellationControllerFactory: () => CancellationController(),
        idFactory: () => 'next',
      );
      await notifier.load();
      await notifier.discoverModels(profile.id);
      expect(notifier.state.discoveredModels[profile.id], hasLength(2));
      await notifier.selectModel(profile.id, 'remote-model');
      expect(
        repository.document.profiles.single.selectedModelId,
        'remote-model',
      );
    },
  );

  test('selected model survives provider metadata codec restart', () {
    final document = ProviderProfilesDocument(
      schemaVersion: ProviderProfilesCodec.currentSchemaVersion,
      profiles: <ProviderProfile>[
        ProviderProfile(
          id: 'restart',
          providerId: 'openai',
          displayName: 'Restart',
          endpoint: Uri.parse('https://example.test'),
          manualModelIds: const ['saved-model'],
          selectedModelId: 'saved-model',
        ),
      ],
    );
    final codec = ProviderProfilesCodec();
    final encoded = codec.encode(document);
    expect(encoded, isA<Success<String>>());
    final decoded = codec.decode((encoded as Success<String>).value);
    expect(
      (decoded as Success<ProviderProfilesDocument>)
          .value
          .profiles
          .single
          .selectedModelId,
      'saved-model',
    );
  });
}

final ProviderDefinition _manualDefinition = ProviderDefinition(
  id: 'manual',
  displayName: 'Manual',
  baseUri: Uri.parse('https://example.test'),
  protocol: ProviderProtocol.anthropic,
  capabilities: const ProviderCapabilities(),
);

final ProviderDefinition _discoveringDefinition = ProviderDefinition(
  id: 'openai',
  displayName: 'OpenAI',
  baseUri: Uri.parse('https://example.test'),
  protocol: ProviderProtocol.compatible,
  capabilities: const ProviderCapabilities(supportsModelDiscovery: true),
  modelDiscoveryRelativePath: 'models',
);
