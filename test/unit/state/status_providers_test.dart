import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/llm/openai_provider.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
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
import 'package:clipmind/state/status_providers.dart';

class _ScriptProvider extends LlmProvider {
  final StreamController<ConnectionStatus> health =
      StreamController<ConnectionStatus>.broadcast();

  @override
  String get id => 'script';

  @override
  Future<List<String>> availableModels() async => ['script'];

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) =>
      throw UnimplementedError();

  @override
  Stream<ConnectionStatus> watchConnection() => health.stream;
}

class _FakeRegistry extends ProviderRegistry {
  final LlmProvider? active;
  _FakeRegistry(this.active);

  @override
  Future<LlmProvider?> getActiveProvider() async => active;
}

class _FakeGenBRegistry implements genb.ProviderRegistry {
  @override
  Iterable<ProviderDefinition> get definitions => const [];

  @override
  ProviderDefinition? definitionFor(String providerId) => null;

  @override
  ModelProviderAdapter? adapterFor(String providerId) => null;
}

class _FakeProfileRepository implements ProviderProfileRepository {
  _FakeProfileRepository(this.document);

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

class _StubResolver extends FfmpegBinaryResolver {
  final String? value;
  final bool throws;
  _StubResolver({this.value, this.throws = false});

  @override
  String? resolveFfmpeg({String? settingsPath}) {
    if (throws) throw StateError('no resolver here');
    return value;
  }
}

void main() {
  group('providerHealthProvider', () {
    test('emits the active provider connection status', () async {
      final provider = _ScriptProvider();
      addTearDown(provider.health.close);
      final container = ProviderContainer(
        overrides: [
          providerRegistryProvider.overrideWithValue(
            _FakeRegistry(provider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final events = <ConnectionStatus>[];
      final sub = container.listen<AsyncValue<ConnectionStatus>>(
        providerHealthProvider,
        (previous, next) {
          final value = next.value;
          if (value != null) events.add(value);
        },
      );
      // Let the provider resolve the registry and subscribe first:
      // broadcast events sent earlier would be lost.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      provider.health.add(ConnectionStatus.connecting);
      provider.health.add(ConnectionStatus.connected);
      for (var i = 0; i < 50 && events.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      sub.close();

      expect(events, contains(ConnectionStatus.connecting));
      expect(events.last, equals(ConnectionStatus.connected));
    });

    test('null provider yields disconnected without throwing', () async {
      final container = ProviderContainer(
        overrides: [
          providerRegistryProvider.overrideWithValue(_FakeRegistry(null)),
        ],
      );
      addTearDown(container.dispose);

      // Riverpod 3 only subscribes a StreamProvider while it has a
      // listener; `.future` alone no longer activates the stream.
      final sub = container.listen<AsyncValue<ConnectionStatus>>(
        providerHealthProvider,
        (_, _) {},
      );
      final first = await container.read(providerHealthProvider.future);
      sub.close();
      expect(first, equals(ConnectionStatus.disconnected));
      expect(
        container.read(providerHealthProvider).value,
        equals(ConnectionStatus.disconnected),
      );
    });
  });

  group('resolvedModelNameProvider', () {
    test('returns the active OpenAI-compatible model name', () async {
      final container = ProviderContainer(
        overrides: [
          providerRegistryProvider.overrideWithValue(
            _FakeRegistry(
              OpenAiProvider(
                config: const OpenAiConfig(
                  apiKey: 'test-key',
                  model: 'test-model',
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(resolvedModelNameProvider.future),
        equals('test-model'),
      );
    });

    test('null when there is no active provider', () async {
      final container = ProviderContainer(
        overrides: [
          providerRegistryProvider.overrideWithValue(_FakeRegistry(null)),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(resolvedModelNameProvider.future),
        isNull,
      );
    });

    test('rebuilds when the selected model changes', () async {
      final profile = ProviderProfile(
        id: 'profile-1',
        providerId: 'openai',
        displayName: 'Test OpenAI',
        endpoint: Uri.parse('https://api.openai.com'),
        credentialId: 'cred-1',
        manualModelIds: const ['m1', 'm2'],
        selectedModelId: 'm1',
      );
      final container = ProviderContainer(
        overrides: [
          providerPlatformBootstrapResultProvider.overrideWithValue(
            Success(
              ProviderPlatformBootstrapResult(
                _FakeGenBRegistry(),
                profiles: [profile],
                activeProfileId: profile.id,
                repository: _FakeProfileRepository(
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

      expect(
        await container.read(resolvedModelNameProvider.future),
        equals('m1'),
      );
      await container
          .read(providerProfileNotifierProvider.notifier)
          .selectModel(profile.id, 'm2');
      expect(
        await container.read(resolvedModelNameProvider.future),
        equals('m2'),
      );
    });
  });

  group('ffmpegBinaryAvailableProvider', () {
    test('true when the resolver finds a binary', () async {
      final container = ProviderContainer(
        overrides: [
          ffmpegBinaryResolverProvider.overrideWithValue(
            _StubResolver(value: '/usr/bin/ffmpeg'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(ffmpegBinaryAvailableProvider.future),
        isTrue,
      );
    });

    test('false when no binary is found', () async {
      final container = ProviderContainer(
        overrides: [
          ffmpegBinaryResolverProvider.overrideWithValue(
            _StubResolver(value: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(ffmpegBinaryAvailableProvider.future),
        isFalse,
      );
    });

    test('resolver failure reads as unavailable, never throws', () async {
      final container = ProviderContainer(
        overrides: [
          ffmpegBinaryResolverProvider.overrideWithValue(
            _StubResolver(throws: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(ffmpegBinaryAvailableProvider.future),
        isFalse,
      );
    });
  });
}
