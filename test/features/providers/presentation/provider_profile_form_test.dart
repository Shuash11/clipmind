import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_capabilities.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/features/providers/domain/provider_credential_reference.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/presentation/providers/provider_profile_notifier.dart';
import 'package:clipmind/features/providers/presentation/widgets/provider_profile_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/provider_presentation_fakes.dart';

void main() {
  testWidgets('blocks unsafe endpoints before saving a profile', (
    tester,
  ) async {
    final repository = MemoryProfileRepository(
      ProviderProfilesDocument(schemaVersion: 1, profiles: const []),
    );
    final definition = ProviderDefinition(
      id: 'openai',
      displayName: 'OpenAI',
      baseUri: Uri.parse('https://example.test/v1'),
      protocol: ProviderProtocol.compatible,
      capabilities: const ProviderCapabilities(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerPlatformBootstrapResultProvider.overrideWithValue(
            Success(
              ProviderPlatformBootstrapResult(
                FakeProviderRegistry(definitions: [definition]),
                repository: repository,
                credentials: MemoryCredentialStore(),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: ClipMindTheme.dark,
          home: const Scaffold(body: ProviderProfileForm()),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('provider-display-name')),
      'Unsafe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('provider-endpoint')),
      'http://example.test',
    );
    final saveButton = find.byKey(const ValueKey('save-provider-profile'));
    final formScrollable = find
        .descendant(
          of: find.byKey(const ValueKey('provider-profile-form')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: formScrollable,
    );
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('provider-endpoint')),
      -300,
      scrollable: formScrollable,
    );
    await tester.pump();
    expect(find.text('The provider endpoint is not allowed.'), findsOneWidget);
    expect(repository.document.profiles, isEmpty);
  });

  testWidgets('initializes a new preset endpoint and warns for local HTTP', (
    tester,
  ) async {
    final definition = ProviderDefinition(
      id: 'openai',
      displayName: 'OpenAI',
      baseUri: Uri.parse('https://example.test/v1'),
      protocol: ProviderProtocol.compatible,
      capabilities: const ProviderCapabilities(),
    );
    final repository = MemoryProfileRepository(
      ProviderProfilesDocument(schemaVersion: 1, profiles: const []),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerPlatformBootstrapResultProvider.overrideWithValue(
            Success(
              ProviderPlatformBootstrapResult(
                FakeProviderRegistry(definitions: [definition]),
                repository: repository,
                credentials: MemoryCredentialStore(),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: ClipMindTheme.dark,
          home: const Scaffold(body: ProviderProfileForm()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('provider-endpoint')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('provider-endpoint')),
          )
          .controller!
          .text,
      'https://api.openai.com/v1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('provider-endpoint')),
      'http://127.0.0.1:11434',
    );
    await tester.pump();
    expect(find.text('Local HTTP is not encrypted.'), findsOneWidget);
  });

  test('keeps completed migration state through metadata mutations', () async {
    final profile = ProviderProfile(
      id: 'profile',
      providerId: 'openai',
      displayName: 'Profile',
      endpoint: Uri.parse('https://example.test/v1'),
      manualModelIds: const ['model-a'],
    );
    final repository = MemoryProfileRepository(
      ProviderProfilesDocument(
        schemaVersion: 1,
        profiles: [profile],
        activeProfileId: profile.id,
        legacyMigrationState: LegacyMigrationState.completed,
      ),
    );
    final notifier = ProviderProfileNotifier(
      repository: repository,
      credentials: MemoryCredentialStore(),
      registry: FakeProviderRegistry(definitions: [_definition]),
      cancellationControllerFactory: () => CancellationController(),
      idFactory: () => 'new-profile',
    );
    await notifier.load();
    await notifier.addManualModel(profile.id, 'model-b');
    expect(
      repository.document.legacyMigrationState,
      LegacyMigrationState.completed,
    );
    await notifier.activateProfile(profile.id);
    expect(
      repository.document.legacyMigrationState,
      LegacyMigrationState.completed,
    );
    await notifier.deleteProfile(profile.id);
    expect(
      repository.document.legacyMigrationState,
      LegacyMigrationState.completed,
    );
  });

  test(
    'secret write and cleanup failures never claim metadata success',
    () async {
      final profile = ProviderProfile(
        id: 'profile',
        providerId: 'openai',
        displayName: 'Profile',
        endpoint: Uri.parse('https://example.test/v1'),
        secretHeaderNames: const ['X-Existing'],
        secretHeaderCredentialIds: const {
          'X-Existing': 'clipmind_provider_profile_header_782d6578697374696e67',
        },
      );
      final repository = MemoryProfileRepository(
        ProviderProfilesDocument(schemaVersion: 1, profiles: [profile]),
      );
      final credentials = MemoryCredentialStore();
      final notifier = ProviderProfileNotifier(
        repository: repository,
        credentials: credentials,
        registry: FakeProviderRegistry(definitions: [_definition]),
        cancellationControllerFactory: () => CancellationController(),
        idFactory: () => 'new-profile',
      );
      await notifier.load();
      await notifier.saveProfile(_draft(profile));
      expect(
        repository
            .document
            .profiles
            .single
            .secretHeaderCredentialIds['X-Existing'],
        ProviderCredentialReference.secretHeader('profile', 'X-Existing'),
      );
      credentials.writeFailure = const ProviderCredentialFailure(
        'Credential write failed.',
      );
      await notifier.saveProfile(
        _draft(
          profile,
          secretNames: const ['X-Existing', 'X-New'],
          secretValues: const {'X-New': 'secret'},
        ),
      );
      expect(repository.document.profiles.single.secretHeaderNames, const [
        'X-Existing',
      ]);
      expect(notifier.state.failure, isA<ProviderCredentialFailure>());
      credentials.writeFailure = null;
      credentials.deleteFailure = const ProviderCredentialFailure(
        'Credential cleanup failed.',
      );
      await notifier.saveProfile(
        _draft(profile, secretNames: const <String>[]),
      );
      expect(repository.document.profiles.single.secretHeaderNames, isEmpty);
      expect(notifier.state.failure, isA<ProviderCredentialFailure>());
      expect(
        credentials.deletes,
        contains(
          ProviderCredentialReference.secretHeader('profile', 'X-Existing'),
        ),
      );
    },
  );

  test(
    'compensates newly written secrets when metadata persistence fails',
    () async {
      final repository =
          MemoryProfileRepository(
              ProviderProfilesDocument(schemaVersion: 1, profiles: const []),
            )
            ..saveFailure = const ProviderPersistenceFailure(
              'Metadata save failed.',
            );
      final credentials = MemoryCredentialStore();
      final notifier = ProviderProfileNotifier(
        repository: repository,
        credentials: credentials,
        registry: FakeProviderRegistry(definitions: [_definition]),
        cancellationControllerFactory: () => CancellationController(),
        idFactory: () => 'new-profile',
      );
      await notifier.load();
      await notifier.saveProfile(
        const ProviderProfileDraft(
          providerId: 'openai',
          displayName: 'New',
          endpoint: 'https://example.test/v1',
          enabled: true,
          timeout: Duration(seconds: 30),
          secretHeaderNames: ['X-New'],
          secretHeaderValues: {'X-New': 'transient-secret'},
        ),
      );
      final reference = ProviderCredentialReference.secretHeader(
        'new-profile',
        'X-New',
      );
      expect(credentials.writes, contains(reference));
      expect(credentials.deletes, contains(reference));
      expect(credentials.values, isEmpty);
      expect(notifier.state.failure, isA<ProviderPersistenceFailure>());
    },
  );
}

final ProviderDefinition _definition = ProviderDefinition(
  id: 'openai',
  displayName: 'OpenAI',
  baseUri: Uri.parse('https://example.test/v1'),
  protocol: ProviderProtocol.compatible,
  capabilities: const ProviderCapabilities(supportsModelDiscovery: true),
  modelDiscoveryRelativePath: 'models',
);

ProviderProfileDraft _draft(
  ProviderProfile profile, {
  List<String>? secretNames,
  Map<String, String>? secretValues,
}) => ProviderProfileDraft(
  id: profile.id,
  providerId: profile.providerId,
  displayName: profile.displayName,
  endpoint: profile.endpoint.toString(),
  enabled: profile.enabled,
  timeout: profile.timeout,
  secretHeaderNames: secretNames ?? profile.secretHeaderNames,
  secretHeaderValues: secretValues ?? const <String, String>{},
  manualModelIds: profile.manualModelIds,
  selectedModelId: profile.selectedModelId,
);
