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

  testWidgets(
    'hints to select a model for custom without a selection',
    (tester) async {
      final profile = ProviderProfile(
        id: 'custom-1',
        providerId: 'custom',
        displayName: 'Custom',
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

      // Custom has no class default: the label hints until a model is
      // chosen, and the Semantics label matches.
      expect(find.textContaining('· select a model'), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label ?? '').contains('Custom'),
        ),
      );
      expect(semantics.properties.label ?? '', contains('select a model'));
    },
  );

  testWidgets(
    'selected custom model clears the hint',
    (tester) async {
      final profile = ProviderProfile(
        id: 'custom-2',
        providerId: 'custom',
        displayName: 'Custom',
        endpoint: Uri.parse('https://example.test'),
        selectedModelId: 'my-model',
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

      expect(find.textContaining('· select a model'), findsNothing);
      expect(find.textContaining('my-model'), findsOneWidget);
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

  testWidgets(
    'auto-discovers models when the picker opens with an empty list',
    (tester) async {
      final profile = ProviderProfile(
        id: 'remote',
        providerId: 'openai',
        displayName: 'Remote',
        endpoint: Uri.parse('https://example.test'),
      );
      final repository = MemoryProfileRepository(
        ProviderProfilesDocument(
          schemaVersion: 1,
          profiles: [profile],
          activeProfileId: profile.id,
        ),
      );
      final adapter = CountingDiscoveryAdapter(<ModelDescriptor>[
        ModelDescriptor(
          id: 'meta/llama-3',
          providerId: 'openai',
          displayName: 'Llama 3',
        ),
        ModelDescriptor(
          id: 'z-ai/glm-4',
          providerId: 'openai',
          displayName: 'GLM 4',
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerPlatformBootstrapResultProvider.overrideWithValue(
              Success(
                ProviderPlatformBootstrapResult(
                  FakeProviderRegistry(
                    definitions: [_discoveringDefinition],
                    adapter: adapter,
                  ),
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
      expect(adapter.discoveryCalls, 0);
      await tester.tap(find.byKey(const ValueKey('dynamic-model-selector')));
      await tester.pumpAndSettle();
      // Bring the lower groups into the build range before asserting.
      final listScrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('GLM 4'),
        100,
        scrollable: listScrollable,
      );
      // The picker auto-fired discovery on open: models are listed without
      // tapping the manual "Discover models" button.
      expect(adapter.discoveryCalls, 1);
      expect(find.text('Llama 3', skipOffstage: false), findsOneWidget);
      expect(find.text('GLM 4', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets(
    'does not refire discovery when the picker reopens with populated models',
    (tester) async {
      final profile = ProviderProfile(
        id: 'remote',
        providerId: 'openai',
        displayName: 'Remote',
        endpoint: Uri.parse('https://example.test'),
      );
      final repository = MemoryProfileRepository(
        ProviderProfilesDocument(
          schemaVersion: 1,
          profiles: [profile],
          activeProfileId: profile.id,
        ),
      );
      final adapter = CountingDiscoveryAdapter(<ModelDescriptor>[
        ModelDescriptor(
          id: 'meta/llama-3',
          providerId: 'openai',
          displayName: 'Llama 3',
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerPlatformBootstrapResultProvider.overrideWithValue(
              Success(
                ProviderPlatformBootstrapResult(
                  FakeProviderRegistry(
                    definitions: [_discoveringDefinition],
                    adapter: adapter,
                  ),
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
      expect(adapter.discoveryCalls, 1);
      await tester.tap(find.byKey(const ValueKey('close-model-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dynamic-model-selector')));
      await tester.pumpAndSettle();
      // The populated discovered state is the debounce: reopening the picker
      // never refetches.
      expect(adapter.discoveryCalls, 1);
    },
  );

  testWidgets(
    'shows an inline loading state while auto-discovering on open',
    (tester) async {
      final profile = ProviderProfile(
        id: 'remote',
        providerId: 'openai',
        displayName: 'Remote',
        endpoint: Uri.parse('https://example.test'),
      );
      final repository = MemoryProfileRepository(
        ProviderProfilesDocument(
          schemaVersion: 1,
          profiles: [profile],
          activeProfileId: profile.id,
        ),
      );
      final adapter = CountingDiscoveryAdapter(
        <ModelDescriptor>[
          ModelDescriptor(
            id: 'meta/llama-3',
            providerId: 'openai',
            displayName: 'Llama 3',
          ),
        ],
        holdDiscovery: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerPlatformBootstrapResultProvider.overrideWithValue(
              Success(
                ProviderPlatformBootstrapResult(
                  FakeProviderRegistry(
                    definitions: [_discoveringDefinition],
                    adapter: adapter,
                  ),
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
      await tester.pump();
      await tester.pump();
      expect(find.text('Discovering models…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      adapter.releaseDiscovery();
      await tester.pumpAndSettle();
      expect(find.text('Discovering models…'), findsNothing);
      expect(find.text('Llama 3'), findsOneWidget);
    },
  );

  testWidgets(
    'renders discovered models under org group headers',
    (tester) async {
      final profile = ProviderProfile(
        id: 'remote',
        providerId: 'openai',
        displayName: 'Remote',
        endpoint: Uri.parse('https://example.test'),
      );
      final repository = MemoryProfileRepository(
        ProviderProfilesDocument(
          schemaVersion: 1,
          profiles: [profile],
          activeProfileId: profile.id,
        ),
      );
      // Models arrive via the on-open auto-discovery (D6b); bare IDs without
      // an org prefix fall into a trailing OTHER group.
      final adapter = CountingDiscoveryAdapter(<ModelDescriptor>[
        ModelDescriptor(
          id: 'meta/llama-3',
          providerId: 'openai',
          displayName: 'Llama 3',
        ),
        ModelDescriptor(
          id: 'z-ai/glm-4',
          providerId: 'openai',
          displayName: 'GLM 4',
        ),
        ModelDescriptor(
          id: 'nvidia/nemotron',
          providerId: 'openai',
          displayName: 'Nemotron',
        ),
        ModelDescriptor(
          id: 'standalone-model',
          providerId: 'openai',
          displayName: 'Bare model',
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerPlatformBootstrapResultProvider.overrideWithValue(
              Success(
                ProviderPlatformBootstrapResult(
                  FakeProviderRegistry(
                    definitions: [_discoveringDefinition],
                    adapter: adapter,
                  ),
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
      // The first group renders under its own header.
      expect(find.text('DISCOVERED'), findsOneWidget);
      expect(find.text('META'), findsOneWidget);
      expect(find.text('Llama 3'), findsOneWidget);
      // Scrolling to the bottom disposes off-range groups in the lazy list,
      // so the trailing OTHER group is asserted after the scroll.
      final listScrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Bare model'),
        100,
        scrollable: listScrollable,
      );
      // Scrolled-in list children stay built but offstage beyond the
      // viewport, so assertions use skipOffstage: false.
      expect(find.text('OTHER', skipOffstage: false), findsOneWidget);
      expect(find.text('Bare model', skipOffstage: false), findsOneWidget);
    },
  );

  test(
    'groups discovered models by org prefix with OTHER trailing',
    () {
      final groups = groupDiscoveredByOrg(<ModelDescriptor>[
        ModelDescriptor(
          id: 'meta/llama-3',
          providerId: 'openai',
          displayName: 'Llama 3',
        ),
        ModelDescriptor(
          id: 'z-ai/glm-4',
          providerId: 'openai',
          displayName: 'GLM 4',
        ),
        ModelDescriptor(
          id: 'nvidia/nemotron',
          providerId: 'openai',
          displayName: 'Nemotron',
        ),
        ModelDescriptor(
          id: 'standalone-model',
          providerId: 'openai',
          displayName: 'Bare model',
        ),
      ]);
      expect(groups.keys.toList(), <String>['meta', 'nvidia', 'z-ai', 'other']);
      expect(groups['meta']!.single.id, 'meta/llama-3');
      expect(groups['nvidia']!.single.id, 'nvidia/nemotron');
      expect(groups['z-ai']!.single.id, 'z-ai/glm-4');
      expect(groups['other']!.single.id, 'standalone-model');
    },
  );

  test(
    'groups multiple models per org in discovery order, case-insensitively',
    () {
      final groups = groupDiscoveredByOrg(<ModelDescriptor>[
        ModelDescriptor(
          id: 'meta/llama-2',
          providerId: 'openai',
          displayName: 'Llama 2',
        ),
        ModelDescriptor(
          id: 'Meta/llama-3',
          providerId: 'openai',
          displayName: 'Llama 3',
        ),
        ModelDescriptor(
          id: 'z-ai/glm-4',
          providerId: 'openai',
          displayName: 'GLM 4',
        ),
      ]);
      expect(groups.keys.toList(), <String>['meta', 'z-ai']);
      expect(groups['meta']!.map((model) => model.id).toList(), <String>[
        'meta/llama-2',
        'Meta/llama-3',
      ]);
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
