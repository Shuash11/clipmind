import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/data/network_disabled_provider_http_transport.dart';
import 'package:clipmind/features/providers/data/provider_platform_bootstrap_impl.dart';
import 'package:clipmind/features/providers/data/provider_registry_impl.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_profile_repository.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'initializes in lifecycle order, refreshes state, and installs offline transport',
    () async {
      final events = <String>[];
      final profiles = _Profiles(events);
      final credentials = _Credentials();
      final transport = _Transport();
      final activeTransports = <ProviderHttpTransport>[];
      final bootstrap = ProviderPlatformBootstrapImpl(
        profiles: profiles,
        credentials: credentials,
        migrate: () async {
          events.add('migrate');
          return const Success<void>(null);
        },
        transport: transport,
        registryFactory: (activeTransport) {
          events.add('registry');
          activeTransports.add(activeTransport);
          return ProviderRegistryImpl.standard(
            transport: activeTransport,
            credentials: credentials,
          );
        },
      );

      final initialized = await bootstrap.initialize(networkEnabled: false);
      profiles.document = _document('next');
      final repeated = await bootstrap.initialize(networkEnabled: false);
      final online = await bootstrap.initialize(networkEnabled: true);

      expect(initialized, isA<Success<ProviderPlatformBootstrapResult>>());
      expect(identical(initialized, repeated), isFalse);
      expect(events, <String>[
        'load',
        'resume',
        'migrate',
        'registry',
        'load',
        'load',
        'resume',
        'load',
        'load',
        'resume',
        'registry',
        'load',
      ]);
      final registry = (initialized as Success).value.registry;
      expect(registry.adapterFor('gpt-any'), isNull);
      expect(
        registry.adapterFor('openai'),
        same(registry.adapterFor('nvidia')),
      );
      expect(
        registry.adapterFor(customOpenAiCompatibleProviderId),
        same(registry.adapterFor('openai')),
      );
      expect(registry.definitionFor(customOpenAiCompatibleProviderId), isNull);
      expect((repeated as Success).value.activeProfileId, 'next');
      expect(
        activeTransports.first,
        isA<NetworkDisabledProviderHttpTransport>(),
      );
      expect(activeTransports.last, same(transport));
      expect(online, isA<Success<ProviderPlatformBootstrapResult>>());

      final offline = await registry
          .adapterFor('ollama')!
          .complete(
            ModelRequest(
              providerId: 'ollama',
              modelId: 'local',
              messages: const <Map<String, Object?>>[
                <String, Object?>{'role': 'user', 'content': 'offline'},
              ],
            ),
            _ollamaProfile,
            CancellationController().token,
          );
      expect((offline as Failure).error, isA<ProviderNetworkDisabledFailure>());
      expect(transport.calls, 0);
    },
  );

  test(
    'propagates pending deletion and migration failures without registry creation',
    () async {
      final events = <String>[];
      final profiles = _Profiles(events)
        ..resumeFailure = const ProviderDeletionPendingFailure();
      final deletionFailure = ProviderPlatformBootstrapImpl(
        profiles: profiles,
        credentials: _Credentials(),
        migrate: () async => const Success<void>(null),
        transport: _Transport(),
      );

      final deleted = await deletionFailure.initialize(networkEnabled: false);
      expect((deleted as Failure).error, isA<ProviderDeletionPendingFailure>());

      final migrationFailure = ProviderPlatformBootstrapImpl(
        profiles: _Profiles(<String>[]),
        credentials: _Credentials(),
        migrate: () async => const Failure<void>(ProviderMigrationFailure()),
        transport: _Transport(),
      );
      final migrated = await migrationFailure.initialize(networkEnabled: true);
      expect((migrated as Failure).error, isA<ProviderMigrationFailure>());
    },
  );

  test(
    'offline guard preserves pre-cancellation without delegating transport',
    () async {
      final cancelled = CancellationController()..cancel();
      final result = await const NetworkDisabledProviderHttpTransport().send(
        ProviderHttpRequest(
          method: ProviderHttpMethod.get,
          uri: Uri.parse('https://example.test/models'),
        ),
        token: cancelled.token,
      );
      expect((result as Failure).error.code, 'provider_cancelled');
    },
  );
}

final ProviderProfile _ollamaProfile = ProviderProfile(
  id: 'local',
  providerId: 'ollama',
  displayName: 'Local',
  endpoint: Uri.parse('http://127.0.0.1:11434'),
);

final class _Profiles implements ProviderProfileRepository {
  _Profiles(this.events);
  final List<String> events;
  ProviderProfilesDocument document = _document('local');
  AppFailure? resumeFailure;

  @override
  Future<Result<void>> deleteProfile(
    String profileId,
    CredentialStore credentials,
  ) async => const Success<void>(null);

  @override
  Future<Result<ProviderProfilesDocument>> load() async {
    events.add('load');
    return Success<ProviderProfilesDocument>(document);
  }

  @override
  Future<Result<void>> resumePendingDeletions(
    CredentialStore credentials,
  ) async {
    events.add('resume');
    if (resumeFailure != null) return Failure<void>(resumeFailure!);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> save(ProviderProfilesDocument document) async =>
      const Success<void>(null);
}

ProviderProfilesDocument _document(String activeProfileId) =>
    ProviderProfilesDocument(
      schemaVersion: 1,
      profiles: <ProviderProfile>[
        _ollamaProfile,
        ProviderProfile(
          id: 'next',
          providerId: 'ollama',
          displayName: 'Next',
          endpoint: Uri.parse('http://127.0.0.1:11434'),
        ),
      ],
      activeProfileId: activeProfileId,
      legacyMigrationState: LegacyMigrationState.completed,
    );

final class _Credentials implements CredentialStore {
  @override
  Future<Result<void>> delete(String credentialId) async =>
      const Success<void>(null);
  @override
  Future<Result<String?>> read(String credentialId) async =>
      const Success<String?>(null);
  @override
  Future<Result<void>> write(String credentialId, String secret) async =>
      const Success<void>(null);
}

final class _Transport implements ProviderHttpTransport {
  int calls = 0;
  @override
  Future<Result<ProviderHttpResponse>> send(
    ProviderHttpRequest request, {
    CancellationToken? token,
  }) async {
    calls++;
    return const Failure<ProviderHttpResponse>(ProviderTransportFailure());
  }
}
