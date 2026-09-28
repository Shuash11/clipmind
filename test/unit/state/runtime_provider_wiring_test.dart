import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/data/services/llm/openai_provider.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart'
    hide providerRegistryProvider;
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_profile_repository.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart'
    as genb;
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/state/agent_providers.dart';

class _FakeGenBRegistry implements genb.ProviderRegistry {
  @override
  Iterable<ProviderDefinition> get definitions => const [];

  @override
  ProviderDefinition? definitionFor(String providerId) => null;

  @override
  ModelProviderAdapter? adapterFor(String providerId) => null;
}

class _FakeRepository implements ProviderProfileRepository {
  _FakeRepository(this.document);

  final ProviderProfilesDocument document;

  @override
  Future<Result<ProviderProfilesDocument>> load() async =>
      Success(document);

  @override
  Future<Result<void>> save(ProviderProfilesDocument document) async =>
      const Success(null);

  @override
  Future<Result<void>> deleteProfile(
    String profileId,
    CredentialStore credentials,
  ) async => const Success(null);

  @override
  Future<Result<void>> resumePendingDeletions(
    CredentialStore credentials,
  ) async => const Success(null);
}

class _FakeCredentials implements CredentialStore {
  @override
  Future<Result<String?>> read(String credentialId) async =>
      const Success('key-123');

  @override
  Future<Result<void>> write(String credentialId, String secret) async =>
      const Success(null);

  @override
  Future<Result<void>> delete(String credentialId) async =>
      const Success(null);
}

void main() {
  group('runtime provider wiring (P0 regression)', () {
    test(
        'real provider graph resolves the active profile provider '
        'with the profile model', () async {
      final profile = ProviderProfile(
        id: 'profile-1',
        providerId: 'openai',
        displayName: 'Test OpenAI',
        endpoint: Uri.parse('https://api.openai.com'),
        credentialId: 'cred-1',
        selectedModelId: 'test-model',
      );
      final container = ProviderContainer(
        overrides: [
          providerPlatformBootstrapResultProvider.overrideWithValue(
            Success(
              ProviderPlatformBootstrapResult(
                _FakeGenBRegistry(),
                profiles: [profile],
                activeProfileId: profile.id,
                repository: _FakeRepository(
                  ProviderProfilesDocument(
                    schemaVersion: 1,
                    profiles: [profile],
                    activeProfileId: profile.id,
                  ),
                ),
                credentials: _FakeCredentials(),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = await container
          .read(providerRegistryProvider)
          .getActiveProvider();

      expect(provider, isNotNull);
      expect((provider as OpenAiProvider).modelName, equals('test-model'));
    });
  });
}
