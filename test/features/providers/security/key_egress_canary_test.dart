import 'dart:convert';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/data/models/app_settings.dart';
import 'package:clipmind/data/repositories/settings_repository.dart';
import 'package:clipmind/data/services/llm/anthropic_provider.dart';
import 'package:clipmind/data/services/llm/custom_openai_compatible_provider.dart';
import 'package:clipmind/data/services/llm/gemini_provider.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/llm/nvidia_nim_provider.dart';
import 'package:clipmind/data/services/llm/openai_provider.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/features/providers/data/adapters/anthropic_adapter.dart';
import 'package:clipmind/features/providers/data/adapters/openai_compatible_adapter.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/data/migration/legacy_provider_settings_migration.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_codec.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_storage.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/data/provider_profile_repository_impl.dart';
import 'package:clipmind/features/providers/data/security/provider_redactor.dart';
import 'package:clipmind/features/providers/data/security/secure_credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/entities/provider_capabilities.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_credential_reference.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/features/providers/presentation/providers/provider_profile_notifier.dart';
import 'package:clipmind/features/providers/presentation/widgets/provider_profile_form.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/status_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/provider_adapter_fakes.dart';
import '../support/provider_presentation_fakes.dart';

/// Canary sentinel: obviously fake test data, never a real credential.
///
/// Every assertion in this suite is about *presence*: the sentinel must appear
/// exactly at its intended egress point (the provider request header/query)
/// and nowhere else — not in persisted metadata, failures, logs, or `toString`
/// output. A regression that echoes a key anywhere fails loudly here.
const String canary = 'CANARY-SECRET-4f2a9c1d58e7';

const String _profileId = 'canary-profile';
final String _apiRef = ProviderCredentialReference.apiKey(_profileId);
final String _headerRef = ProviderCredentialReference.secretHeader(
  _profileId,
  'X-Custom-Secret',
);

final ProviderDefinition _openAiDefinition = ProviderDefinition(
  id: 'openai',
  displayName: 'OpenAI',
  baseUri: Uri.parse('https://example.test/v1'),
  protocol: ProviderProtocol.compatible,
  capabilities: const ProviderCapabilities(),
);

bool _containsCanary(Object? value) => '$value'.contains(canary);

ProviderProfile _metadataProfile({
  String providerId = 'openai',
  Map<String, String> headers = const <String, String>{},
  Iterable<String> secretHeaderNames = const <String>[],
  Map<String, String> secretHeaderCredentialIds = const <String, String>{},
}) => ProviderProfile(
  id: _profileId,
  providerId: providerId,
  displayName: 'Canary',
  endpoint: Uri.parse('https://example.test/v1'),
  credentialId: _apiRef,
  headers: headers,
  secretHeaderNames: secretHeaderNames,
  secretHeaderCredentialIds: secretHeaderCredentialIds,
);

AgentTurnRequest _turnRequest() => const AgentTurnRequest(
  systemPrompt: 'system',
  userContent: 'do the thing',
);

DioException _requestContextFailure({
  Map<String, String> headers = const <String, String>{},
  String? query,
}) {
  final options = RequestOptions(
    path: '/v1/test',
    baseUrl: 'https://example.test',
    queryParameters: query == null ? null : <String, String>{'key': query},
    headers: headers,
  );
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(requestOptions: options, statusCode: 401),
  );
}

/// Stubs the exact `post` shape each Gen A provider uses (Gemini passes
/// `queryParameters`, the others do not) so the failure reaches the provider's
/// `on DioException` handler rather than mocktail's missing-stub error.
void _stubPostFailure(Dio dio, Object error, {bool withQueryParameters = false}) {
  if (withQueryParameters) {
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(error);
  } else {
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(error);
  }
}

final class _GenAErrorCase {
  const _GenAErrorCase({
    required this.build,
    required this.failure,
    this.withQueryParameters = false,
  });

  final LlmProvider Function(Dio dio) build;
  final DioException Function() failure;
  final bool withQueryParameters;
}

final class _MockDio extends Mock implements Dio {}

final class _StubSettingsRepository extends SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();
  @override
  Future<void> save(AppSettings settings) async {}
}

/// Resolves the canary through the legacy Gen A `SecureKeyStore` seam without
/// touching platform secure storage.
final class _CanaryKeyStore extends SecureKeyStore {
  @override
  Future<String?> readApiKey(String provider) async => canary;
}

final class _MemorySecureBackend implements SecureStorageBackend {
  final Map<String, String> values = <String, String>{};
  @override
  Future<void> delete({required String key}) async => values.remove(key);
  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

/// Fails with the secret embedded in the backend error so the store's failure
/// values are provably sanitized.
final class _FailingSecureBackend implements SecureStorageBackend {
  @override
  Future<void> delete({required String key}) async => throw StateError('fail');
  @override
  Future<String?> read({required String key}) async => throw StateError('fail');
  @override
  Future<void> write({required String key, required String value}) async =>
      throw StateError('backend refused $value');
}

final class _MemoryProfileStorage implements ProviderProfilesStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String contents) async => value = contents;
}

final class _FixedLegacySettings implements LegacyProviderSettingsSource {
  _FixedLegacySettings(this.value);
  final LegacyProviderSettings value;
  @override
  Future<Result<LegacyProviderSettings?>> load() async =>
      Success<LegacyProviderSettings?>(value);
}

final class _MapLegacyCredentials implements LegacyProviderCredentialSource {
  _MapLegacyCredentials(this.values);
  final Map<String, String> values;
  @override
  Future<Result<void>> deleteApiKey(String providerId) async {
    values.remove(providerId);
    return const Success<void>(null);
  }

  @override
  Future<Result<String?>> readApiKey(String providerId) async =>
      Success<String?>(values[providerId]);
}

final class _MapCredentialStore implements CredentialStore {
  final Map<String, String> values = <String, String>{};
  bool failWrite = false;
  @override
  Future<Result<void>> delete(String credentialId) async {
    values.remove(credentialId);
    return const Success<void>(null);
  }

  @override
  Future<Result<String?>> read(String credentialId) async =>
      Success<String?>(values[credentialId]);
  @override
  Future<Result<void>> write(String credentialId, String secret) async {
    if (failWrite) {
      return const Failure<void>(ProviderCredentialFailure('write failed'));
    }
    values[credentialId] = secret;
    return const Success<void>(null);
  }
}

final class _ScriptedClient implements ProviderHttpClient {
  _ScriptedClient(this._results);
  final List<Object> _results;
  @override
  Future<ProviderHttpResponse> send(ProviderHttpRequest request) {
    final next = _results.removeAt(0);
    if (next is ProviderHttpResponse) {
      return Future<ProviderHttpResponse>.value(next);
    }
    throw next;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
    registerFallbackValue(Options());
  });

  group('redactor', () {
    test(
      'redacts the canary as an explicit secret and inside bearer, URLs, JSON, and headers',
      () {
        final redactor = ProviderRedactor(secretValues: const <String>[canary]);
        final text = redactor.redact(
          'Authorization: Bearer $canary '
          'https://user:$canary@example.test/v1?key=$canary '
          '{"api_key":"$canary"} trailing key=$canary',
        );
        expect(text, isNot(contains(canary)));
        expect(text, contains('[REDACTED]'));

        final headers = redactor.redactHeaders(<String, String>{
          'Authorization': 'Bearer $canary',
          'x-api-key': canary,
          'X-Custom-Secret': canary,
          'X-Client': 'clipmind',
        });
        expect(headers['Authorization'], '[REDACTED]');
        expect(headers['x-api-key'], '[REDACTED]');
        expect(headers['X-Custom-Secret'], '[REDACTED]');
        expect(headers['X-Client'], 'clipmind');

        final uri = redactor.redactUri(
          Uri.parse('https://example.test/v1?key=$canary&limit=5'),
        );
        expect(uri.toString(), isNot(contains(canary)));
        expect(uri.queryParameters['key'], '[REDACTED]');
        expect(uri.queryParameters['limit'], '5');
      },
    );
  });

  group('Gen B credential storage', () {
    test(
      'credential store keeps the canary in secure storage and out of failures',
      () async {
        final backend = _MemorySecureBackend();
        final store = SecureCredentialStore(backend: backend);
        expect(
          await store.writeApiKey(_profileId, canary),
          isA<Success<void>>(),
        );
        expect(
          await store.writeSecretHeader(_profileId, 'X-Custom-Secret', canary),
          isA<Success<void>>(),
        );
        expect(backend.values.keys, <String>[_apiRef, _headerRef]);
        expect(
          (await store.readApiKey(_profileId) as Success<String?>).value,
          canary,
        );
        expect(
          (await store.readSecretHeader(_profileId, 'X-Custom-Secret')
                  as Success<String?>)
              .value,
          canary,
        );

        final failing = SecureCredentialStore(backend: _FailingSecureBackend());
        final writeFailure = await failing.writeApiKey(_profileId, canary);
        expect(writeFailure, isA<Failure<void>>());
        expect(
          _containsCanary((writeFailure as Failure<void>).error.toString()),
          isFalse,
        );
        final readFailure = await failing.readApiKey(_profileId);
        expect(readFailure, isA<Failure<String?>>());
        expect(
          _containsCanary((readFailure as Failure<String?>).error.toString()),
          isFalse,
        );
      },
    );

    test(
      'profile save persists metadata only; the canary never reaches the document',
      () async {
        final repository = MemoryProfileRepository(
          ProviderProfilesDocument(
            schemaVersion: ProviderProfilesCodec.currentSchemaVersion,
            profiles: const <ProviderProfile>[],
          ),
        );
        final credentials = MemoryCredentialStore();
        final notifier = ProviderProfileNotifier(
          repository: repository,
          credentials: credentials,
          registry: FakeProviderRegistry(
            definitions: <ProviderDefinition>[_openAiDefinition],
          ),
          cancellationControllerFactory: CancellationController.new,
          idFactory: () => _profileId,
        );

        await notifier.saveProfile(
          const ProviderProfileDraft(
            providerId: 'openai',
            displayName: 'Canary',
            endpoint: 'https://example.test/v1',
            enabled: true,
            timeout: Duration(seconds: 30),
            apiKey: canary,
            secretHeaderNames: <String>['X-Custom-Secret'],
            secretHeaderValues: <String, String>{
              'X-Custom-Secret': canary,
            },
          ),
        );

        expect(notifier.state.failureMessage, isNull);
        expect(credentials.writes, <String>[_apiRef, _headerRef]);
        expect(credentials.values, <String, String>{
          _apiRef: canary,
          _headerRef: canary,
        });
        final encoded = ProviderProfilesCodec().encode(repository.document);
        expect(encoded, isA<Success<String>>());
        expect(_containsCanary((encoded as Success<String>).value), isFalse);
        expect(_containsCanary(repository.document.toString()), isFalse);
        final profile = notifier.state.profiles.single;
        expect(_containsCanary(profile.toString()), isFalse);
        expect(profile.credentialId, _apiRef);
        expect(profile.secretHeaderNames, <String>['X-Custom-Secret']);
      },
    );
  });

  group('Gen B metadata codec', () {
    test('rejects and drops metadata that would carry the canary', () {
      final codec = ProviderProfilesCodec();
      final overlap = _metadataProfile(
        headers: const <String, String>{'x-custom-secret': canary},
        secretHeaderNames: const <String>['X-Custom-Secret'],
        secretHeaderCredentialIds: <String, String>{
          'X-Custom-Secret': _headerRef,
        },
      );
      final overlapResult = codec.encode(
        ProviderProfilesDocument(
          schemaVersion: ProviderProfilesCodec.currentSchemaVersion,
          profiles: <ProviderProfile>[overlap],
        ),
      );
      expect(overlapResult, isA<Failure<String>>());
      expect(
        _containsCanary((overlapResult as Failure<String>).error.toString()),
        isFalse,
      );

      final authorization = _metadataProfile(
        headers: const <String, String>{'Authorization': canary},
      );
      expect(
        codec.encode(
          ProviderProfilesDocument(
            schemaVersion: ProviderProfilesCodec.currentSchemaVersion,
            profiles: <ProviderProfile>[authorization],
          ),
        ),
        isA<Failure<String>>(),
      );

      final queryEndpoint = _metadataProfile().copyWith(
        endpoint: Uri.parse('https://example.test/v1?api_key=$canary'),
      );
      final queryResult = codec.encode(
        ProviderProfilesDocument(
          schemaVersion: ProviderProfilesCodec.currentSchemaVersion,
          profiles: <ProviderProfile>[queryEndpoint],
        ),
      );
      expect(queryResult, isA<Failure<String>>());
      expect(
        _containsCanary((queryResult as Failure<String>).error.toString()),
        isFalse,
      );

      // Unknown secret-bearing fields are dropped at the codec boundary.
      final raw = jsonEncode(<String, Object?>{
        'schemaVersion': ProviderProfilesCodec.currentSchemaVersion,
        'activeProfileId': null,
        'legacyMigrationState': 'notStarted',
        'profiles': <Map<String, Object?>>[
          <String, Object?>{
            'id': _profileId,
            'providerId': 'openai',
            'displayName': 'Canary',
            'endpoint': 'https://example.test/v1',
            'credentialId': _apiRef,
            'headers': <String, String>{'X-Client': 'clipmind'},
            'secretHeaderNames': <String>[],
            'secretHeaderCredentialIds': <String, String>{},
            'manualModelIds': <String>[],
            'selectedModelId': null,
            'enabled': true,
            'timeoutMilliseconds': 30000,
            'deletionPending': false,
            'apiKey': canary,
          },
        ],
      });
      final decoded = codec.decode(raw);
      expect(decoded, isA<Success<ProviderProfilesDocument>>());
      final reencoded = codec.encode(
        (decoded as Success<ProviderProfilesDocument>).value,
      );
      expect(reencoded, isA<Success<String>>());
      expect(_containsCanary((reencoded as Success<String>).value), isFalse);
    });
  });

  group('Gen B legacy migration', () {
    test(
      'legacy migration moves the canary into scoped storage without metadata echo',
      () async {
        final storage = _MemoryProfileStorage();
        final legacy = _MapLegacyCredentials(<String, String>{'openai': canary});
        final credentials = _MapCredentialStore();
        final migration = LegacyProviderSettingsMigration(
          repository: ProviderProfileRepositoryImpl(storage: storage),
          settings: _FixedLegacySettings(
            const LegacyProviderSettings(
              activeProviderId: 'openai',
              activeModel: 'canary-model',
              ollamaEndpoint: 'http://localhost:11434',
            ),
          ),
          legacyCredentials: legacy,
          credentials: credentials,
        );

        expect(await migration.migrate(), isA<Success<void>>());
        final migratedRef = ProviderCredentialReference.apiKey('legacy-openai');
        expect(credentials.values, containsPair(migratedRef, canary));
        expect(legacy.values, isEmpty);
        expect(_containsCanary(storage.value), isFalse);

        final retryStorage = _MemoryProfileStorage();
        final retryLegacy = _MapLegacyCredentials(<String, String>{
          'openai': canary,
        });
        final failingCredentials = _MapCredentialStore()..failWrite = true;
        final retry = LegacyProviderSettingsMigration(
          repository: ProviderProfileRepositoryImpl(storage: retryStorage),
          settings: _FixedLegacySettings(
            const LegacyProviderSettings(
              activeProviderId: 'openai',
              activeModel: '',
              ollamaEndpoint: 'http://localhost:11434',
            ),
          ),
          legacyCredentials: retryLegacy,
          credentials: failingCredentials,
        );
        final failed = await retry.migrate();
        expect(failed, isA<Failure<void>>());
        expect(
          _containsCanary((failed as Failure<void>).error.toString()),
          isFalse,
        );
        expect(retryLegacy.values, containsPair('openai', canary));
        expect(_containsCanary(retryStorage.value), isFalse);
      },
    );
  });

  group('Gen B egress', () {
    test('headersFor carries the canary only in the designated header', () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[]);
      final adapter = AnthropicAdapter(
        transport: transport,
        credentials: MemoryCredentials(<String, String>{_apiRef: canary}),
      );
      final profile = _metadataProfile(
        providerId: 'anthropic',
        headers: const <String, String>{'X-Client': 'clipmind'},
      );
      final headers = await adapter.headersFor(
        profile,
        needsApiKey: true,
        apiHeader: 'x-api-key',
      );
      final values = (headers as Success<Map<String, String>>).value;
      expect(values['x-api-key'], canary);
      expect(values['X-Client'], 'clipmind');
      expect(values.values.where(_containsCanary), hasLength(1));

      final compatible = OpenAiCompatibleAdapter(
        transport: transport,
        credentials: MemoryCredentials(<String, String>{_apiRef: canary}),
      );
      final bearer = await compatible.headersFor(
        _metadataProfile(),
        needsApiKey: true,
        apiHeader: 'Authorization',
        bearerApiKey: true,
      );
      expect(
        (bearer as Success<Map<String, String>>).value['Authorization'],
        'Bearer $canary',
      );

      final missing = AnthropicAdapter(
        transport: transport,
        credentials: MemoryCredentials(),
      );
      final missingResult = await missing.headersFor(
        profile,
        needsApiKey: true,
        apiHeader: 'x-api-key',
      );
      expect(missingResult, isA<Failure<Map<String, String>>>());
      expect(
        _containsCanary(
          (missingResult as Failure<Map<String, String>>).error.toString(),
        ),
        isFalse,
      );
    });

    test(
      'transport failures and request/response toStrings never carry the canary',
      () async {
        final request = ProviderHttpRequest(
          method: ProviderHttpMethod.get,
          uri: Uri.parse('https://example.test/v1/models?api_key=$canary'),
          headers: const <String, String>{
            'Authorization': 'Bearer $canary',
          },
        );
        final statusResult = await RetryingProviderHttpTransport(
          client: _ScriptedClient(<Object>[
            ProviderHttpResponse(statusCode: 401),
          ]),
          retryDelay: (_) async {},
          redactor: ProviderRedactor(secretValues: const <String>[canary]),
        ).send(request);
        final statusFailure =
            (statusResult as Failure<ProviderHttpResponse>).error;
        expect(statusFailure, isA<ProviderTransportFailure>());
        expect(statusFailure.toString(), isNot(contains(canary)));
        expect(statusFailure.message, isNot(contains(canary)));
        expect('$request', isNot(contains(canary)));
        expect('${ProviderHttpResponse(statusCode: 200)}', isNot(contains(canary)));

        final exceptionResult = await RetryingProviderHttpTransport(
          client: _ScriptedClient(<Object>[
            const ProviderHttpException(
              ProviderHttpExceptionKind.connectionReset,
            ),
          ]),
          retryDelay: (_) async {},
          maxRetries: 0,
        ).send(request);
        final exceptionFailure =
            (exceptionResult as Failure<ProviderHttpResponse>).error;
        expect(exceptionFailure.toString(), isNot(contains(canary)));

        final dioResult = await RetryingProviderHttpTransport(
          client: _ScriptedClient(<Object>[
            DioException(
              requestOptions: RequestOptions(
                path: '/v1/models',
                headers: <String, String>{'Authorization': 'Bearer $canary'},
              ),
              type: DioExceptionType.connectionError,
            ),
          ]),
          retryDelay: (_) async {},
          maxRetries: 0,
        ).send(request);
        final dioFailure = (dioResult as Failure<ProviderHttpResponse>).error;
        expect(dioFailure.toString(), isNot(contains(canary)));
      },
    );
  });

  group('Gen A resolver bridge', () {
    test(
      'the Gen B profile credential reaches the Gen A provider config only',
      () async {
        final profile = ProviderProfile(
          id: _profileId,
          providerId: 'openai',
          displayName: 'Canary',
          endpoint: Uri.parse('https://api.openai.com'),
          credentialId: _apiRef,
          selectedModelId: 'canary-model',
        );
        final container = ProviderContainer.test(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(
              _StubSettingsRepository(),
            ),
            providerPlatformBootstrapResultProvider.overrideWithValue(
              Success(
                ProviderPlatformBootstrapResult(
                  FakeProviderRegistry(),
                  profiles: <ProviderProfile>[profile],
                  activeProfileId: profile.id,
                  repository: MemoryProfileRepository(
                    ProviderProfilesDocument(
                      schemaVersion: 1,
                      profiles: <ProviderProfile>[profile],
                      activeProfileId: profile.id,
                    ),
                  ),
                  credentials: MemoryCredentialStore()..values[_apiRef] = canary,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final provider = await container
            .read(providerRegistryProvider)
            .getActiveProvider();
        expect(provider, isA<OpenAiProvider>());
        final openAi = provider! as OpenAiProvider;
        expect(openAi.config.apiKey, canary);
        expect(_containsCanary(openAi.toString()), isFalse);
        expect(_containsCanary(openAi.id), isFalse);
        expect(
          _containsCanary(container.read(providerProfileNotifierProvider)),
          isFalse,
        );

        final model = await container.read(resolvedModelNameProvider.future);
        expect(model, 'canary-model');
        expect(_containsCanary(model), isFalse);

        const config = ActiveLlmConfig(
          providerId: 'openai',
          apiKey: canary,
          model: 'canary-model',
        );
        expect(_containsCanary(config.toString()), isFalse);
      },
    );
  });

  group('Gen A legacy fallback and error surfaces', () {
    test(
      'SecureKeyStore fallback resolves the canary into the auth header only',
      () async {
        final registry = ProviderRegistry(
          keyStore: _CanaryKeyStore(),
          activeProfileResolver: () async =>
              const ActiveLlmConfig(providerId: 'openai', apiKey: ''),
          settingsRepository: _StubSettingsRepository(),
        );
        final provider = await registry.getActiveProvider();
        expect(provider, isA<OpenAiProvider>());
        final openAi = provider! as OpenAiProvider;
        final resolved = await openAi.resolveApiKey();
        expect(resolved, canary);
        expect(openAi.authHeaders(resolved), <String, String>{
          'Authorization': 'Bearer $canary',
        });
        expect(_containsCanary(openAi.toString()), isFalse);
        expect(_containsCanary(openAi.id), isFalse);
      },
    );

    test('provider error paths never echo the canary from request context', () async {
      final cases = <String, _GenAErrorCase>{
        'openai': _GenAErrorCase(
          build: (dio) => OpenAiProvider(
            config: const OpenAiConfig(apiKey: canary),
            dio: dio,
          ),
          failure: () => _requestContextFailure(
            headers: const <String, String>{'Authorization': 'Bearer $canary'},
          ),
        ),
        'anthropic': _GenAErrorCase(
          build: (dio) => AnthropicProvider(
            config: const AnthropicConfig(apiKey: canary),
            dio: dio,
          ),
          failure: () => _requestContextFailure(
            headers: const <String, String>{'x-api-key': canary},
          ),
        ),
        'gemini': _GenAErrorCase(
          build: (dio) => GeminiProvider(
            config: const GeminiConfig(apiKey: canary),
            dio: dio,
          ),
          failure: () => _requestContextFailure(query: canary),
          withQueryParameters: true,
        ),
        'nvidia_nim': _GenAErrorCase(
          build: (dio) => NvidiaNimProvider(
            config: const NvidiaNimConfig(apiKey: canary),
            dio: dio,
          ),
          failure: () => _requestContextFailure(
            headers: const <String, String>{'Authorization': 'Bearer $canary'},
          ),
        ),
        'custom': _GenAErrorCase(
          build: (dio) => CustomOpenAiCompatibleProvider(
            config: CustomOpenAiConfig(
              endpoint: Uri.parse('https://example.test/api/v1'),
              model: 'canary-model',
              apiKey: canary,
            ),
            dio: dio,
          ),
          failure: () => _requestContextFailure(
            headers: const <String, String>{'Authorization': 'Bearer $canary'},
          ),
        ),
      };

      for (final entry in cases.entries) {
        final dio = _MockDio();
        final contextFailure = entry.value.failure();
        _stubPostFailure(
          dio,
          contextFailure,
          withQueryParameters: entry.value.withQueryParameters,
        );
        final provider = entry.value.build(dio);

        ProviderFailure? failure;
        try {
          await provider.chatWithTools(_turnRequest());
        } on ProviderFailure catch (error) {
          failure = error;
        }

        expect(failure, isNotNull, reason: entry.key);
        final requestContext =
            '${contextFailure.requestOptions.uri} '
            '${contextFailure.requestOptions.headers}';
        expect(
          requestContext,
          contains(canary),
          reason: '${entry.key}: harness must place the canary in the request context',
        );
        expect(failure!.message, isNot(contains(canary)), reason: entry.key);
        expect(_containsCanary(failure.toString()), isFalse, reason: entry.key);
        expect(
          _containsCanary('LLM error: $failure'),
          isFalse,
          reason: entry.key,
        );
      }
    });

    test('provider 400 messages redact a canary echoed in the response body', () async {
      final cases = <String, _GenAErrorCase>{
        'anthropic': _GenAErrorCase(
          build: (dio) => AnthropicProvider(
            config: const AnthropicConfig(apiKey: canary),
            dio: dio,
          ),
          failure: () => _requestContextFailure(
            headers: const <String, String>{'x-api-key': canary},
          ),
        ),
        'gemini': _GenAErrorCase(
          build: (dio) => GeminiProvider(
            config: const GeminiConfig(apiKey: canary),
            dio: dio,
          ),
          failure: () => _requestContextFailure(query: canary),
          withQueryParameters: true,
        ),
      };

      for (final entry in cases.entries) {
        final dio = _MockDio();
        final options = RequestOptions(
          path: '/v1/test',
          baseUrl: 'https://example.test',
          headers: <String, String>{'x-api-key': canary},
        );
        final echoed = <String, Object?>{
          'error': <String, Object?>{'message': 'invalid key $canary'},
        };
        _stubPostFailure(
          dio,
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: 400,
              data: echoed,
            ),
          ),
          withQueryParameters: entry.value.withQueryParameters,
        );
        final provider = entry.value.build(dio);

        ProviderFailure? failure;
        try {
          await provider.chatWithTools(_turnRequest());
        } on ProviderFailure catch (error) {
          failure = error;
        }

        expect(
          _containsCanary(echoed),
          isTrue,
          reason: '${entry.key}: response must echo the canary to keep this meaningful',
        );
        expect(failure, isNotNull, reason: entry.key);
        expect(failure!.message, isNot(contains(canary)), reason: entry.key);
        expect(_containsCanary(failure.toString()), isFalse, reason: entry.key);
      }
    });

    test('connection status streams emit typed states only', () async {
      final dio = _MockDio();
      Map<String, dynamic>? sentHeaders;
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        sentHeaders = (invocation.namedArguments[#options] as Options).headers;
        return Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/messages'),
          statusCode: 200,
          data: <String, dynamic>{'content': <Object?>[]},
        );
      });
      final provider = AnthropicProvider(
        config: const AnthropicConfig(apiKey: canary),
        dio: dio,
      );
      addTearDown(provider.dispose);

      final events = await provider.watchConnection().take(1).toList();
      expect(
        sentHeaders!['x-api-key'],
        canary,
        reason: 'harness must place the canary in the health-check request',
      );
      expect(events, <ConnectionStatus>[ConnectionStatus.connected]);
      expect(events.where(_containsCanary), isEmpty);
    });
  });

  group('UI masking', () {
    testWidgets(
      'API key and secret header values are obscured and never rendered',
      (tester) async {
        final profile = ProviderProfile(
          id: _profileId,
          providerId: 'openai',
          displayName: 'Canary',
          endpoint: Uri.parse('https://example.test/v1'),
          credentialId: _apiRef,
          secretHeaderNames: const <String>['X-Custom-Secret'],
          secretHeaderCredentialIds: <String, String>{
            'X-Custom-Secret': _headerRef,
          },
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              providerPlatformBootstrapResultProvider.overrideWithValue(
                Success(
                  ProviderPlatformBootstrapResult(
                    FakeProviderRegistry(
                      definitions: <ProviderDefinition>[_openAiDefinition],
                    ),
                    profiles: <ProviderProfile>[profile],
                    activeProfileId: profile.id,
                    repository: MemoryProfileRepository(
                      ProviderProfilesDocument(
                        schemaVersion: 1,
                        profiles: <ProviderProfile>[profile],
                        activeProfileId: profile.id,
                      ),
                    ),
                    credentials: MemoryCredentialStore()
                      ..values[_apiRef] = canary
                      ..values[_headerRef] = canary,
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ProviderProfileForm(profile: profile)),
            ),
          ),
        );
        await tester.pump();

        final formScrollable = find
            .descendant(
              of: find.byKey(const ValueKey('provider-profile-form')),
              matching: find.byType(Scrollable),
            )
            .first;

        final keyField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('provider-api-key')),
            matching: find.byType(TextField),
          ),
        );
        expect(keyField.obscureText, isTrue);
        expect(keyField.controller!.text, isEmpty);

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('secret-header-value-0')),
          300,
          scrollable: formScrollable,
        );
        final secretValueField = tester.widget<TextField>(
          find.byKey(const ValueKey('secret-header-value-0')),
        );
        expect(secretValueField.obscureText, isTrue);
        expect(secretValueField.controller!.text, isEmpty);

        expect(find.textContaining(canary), findsNothing);
      },
    );
  });
}
