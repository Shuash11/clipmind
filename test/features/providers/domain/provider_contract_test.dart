import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/immutable_value.dart';
import 'package:clipmind/features/providers/domain/entities/model_tool_definition.dart';
import 'package:clipmind/features/providers/domain/entities/normalized_model_tool_call.dart';
import 'package:clipmind/features/providers/domain/entities/provider_connection_result.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_test_data.dart';

void main() {
  test('provider-owned values defensively copy exposed maps and lists', () {
    final schema = <String, Object?>{'type': 'object'};
    final arguments = <String, Object?>{'clip': 'one'};
    final messages = <Map<String, Object?>>[
      <String, Object?>{'role': 'user', 'content': 'hello'},
    ];
    final headers = <String, String>{'X-Provider': 'test'};
    final tool = ModelToolDefinition(
      name: 'edit',
      description: 'Edit a clip.',
      inputSchema: schema,
    );
    final call = NormalizedModelToolCall(
      id: 'call-1',
      name: 'edit',
      arguments: arguments,
    );
    final request = ModelRequest(
      providerId: 'openai',
      modelId: 'a-model',
      messages: messages,
      tools: <ModelToolDefinition>[tool],
    );
    final response = ModelResponse(
      modelId: 'a-model',
      content: '',
      toolCalls: <NormalizedModelToolCall>[call],
    );
    final profile = ProviderProfile(
      id: 'profile-1',
      providerId: 'openai',
      displayName: 'Work',
      endpoint: Uri.parse('https://example.test/v1'),
      headers: headers,
    );

    schema.clear();
    arguments.clear();
    messages.clear();
    headers.clear();

    expect(tool.inputSchema, containsPair('type', 'object'));
    expect(call.arguments, containsPair('clip', 'one'));
    expect(request.messages, hasLength(1));
    expect(response.toolCalls, hasLength(1));
    expect(profile.headers, containsPair('X-Provider', 'test'));
    expect(
      () => request.messages.add(<String, Object?>{}),
      throwsUnsupportedError,
    );
    expect(() => profile.headers['new'] = 'value', throwsUnsupportedError);
  });

  test('strict provider JSON values preserve safe scalars and deep copies', () {
    final nested = <String, Object?>{'value': 'before'};
    final source = <String, Object?>{
      'zero': 0,
      'negative': -1,
      'doubleZero': 0.0,
      'false': false,
      'nested': <Object?>[nested],
    };
    final copied = immutableObjectMap(source);
    source['zero'] = 9;
    (source['nested']! as List<Object?>).clear();
    nested['value'] = 'after';

    expect(copied['zero'], 0);
    expect(copied['negative'], -1);
    expect(copied['doubleZero'], 0.0);
    expect(copied['false'], isFalse);
    expect(
      ((copied['nested']! as List<Object?>).single
          as Map<String, Object?>)['value'],
      'before',
    );
    expect(() => copied['new'] = true, throwsUnsupportedError);
    expect(() {
      final nestedCopy =
          (copied['nested']! as List<Object?>).single as Map<String, Object?>;
      nestedCopy['value'] = 'changed';
    }, throwsUnsupportedError);
  });

  test(
    'provider JSON rejects local values non-string keys cycles and deep nesting',
    () {
      final payload = _payload();
      final listCycle = <Object?>[];
      listCycle.add(listCycle);
      final mapCycle = <String, Object?>{};
      mapCycle['self'] = mapCycle;
      Object? deep = 0;
      for (var index = 0; index < 65; index++) {
        deep = <Object?>[deep];
      }

      for (final invalid in <Object?>[
        <Object?>{'set'},
        Uri.parse('https://provider.example/secret'),
        DateTime.utc(2026),
        payload,
        <Object?, Object?>{1: 'not a string key'},
        double.nan,
        double.infinity,
        listCycle,
        mapCycle,
        deep,
      ]) {
        expect(() => immutableValue(invalid), throwsArgumentError);
      }
    },
  );

  test('provider request response and tool values reject local payloads', () {
    final payload = _payload();

    expect(
      () => ModelRequest(
        providerId: 'provider',
        modelId: 'model',
        messages: <Map<String, Object?>>[
          <String, Object?>{'payload': payload},
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => ModelToolDefinition(
        name: 'tool',
        description: 'description',
        inputSchema: <String, Object?>{'payload': payload},
      ),
      throwsArgumentError,
    );
    expect(
      () => NormalizedModelToolCall(
        id: 'call',
        name: 'tool',
        arguments: <String, Object?>{'payload': payload},
      ),
      throwsArgumentError,
    );
    expect(
      () => ModelResponse(
        modelId: 'model',
        content: '',
        metadata: <String, Object?>{'payload': payload},
      ),
      throwsArgumentError,
    );
    expect(
      () => ProviderHttpRequest(
        method: ProviderHttpMethod.post,
        uri: Uri.parse('https://provider.example/v1'),
        body: payload,
      ),
      throwsArgumentError,
    );
    expect(
      () => ProviderHttpResponse(statusCode: 200, body: payload),
      throwsArgumentError,
    );
  });

  test(
    'adapter and bootstrap contracts are profile-scoped and network-aware',
    () async {
      final profile = ProviderProfile(
        id: 'profile-1',
        providerId: 'openai',
        displayName: 'Work',
        endpoint: Uri.parse('https://example.test/v1'),
      );
      final request = ModelRequest(
        providerId: 'openai',
        modelId: 'model-a',
        messages: const <Map<String, Object?>>[],
      );
      final token = CancellationController().token;
      final adapter = _ProfileScopedAdapter();
      final bootstrap = _NetworkAwareBootstrap();

      expect(
        await adapter.complete(request, profile, token),
        isA<Success<ModelResponse>>(),
      );
      expect(
        await bootstrap.initialize(networkEnabled: false),
        isA<Success<ProviderPlatformBootstrapResult>>(),
      );
      expect(bootstrap.networkEnabled, isFalse);
    },
  );
}

ValidatedPlanPayload _payload() => ValidatedPlanPayload(
  commands: const [],
  candidateState: stateWithOneClip(),
  summaries: const [],
);

final class _ProfileScopedAdapter implements ModelProviderAdapter {
  @override
  Future<Result<ModelResponse>> complete(
    ModelRequest request,
    ProviderProfile profile,
    CancellationToken token,
  ) => Future<Result<ModelResponse>>.value(
    Success<ModelResponse>(
      ModelResponse(modelId: request.modelId, content: profile.id),
    ),
  );

  @override
  Future<Result<List<ModelDescriptor>>> discoverModels(
    ProviderProfile profile,
    CancellationToken token,
  ) => Future<Result<List<ModelDescriptor>>>.value(
    const Success<List<ModelDescriptor>>(<ModelDescriptor>[]),
  );

  @override
  Future<Result<ProviderConnectionResult>> testConnection(
    ProviderProfile profile,
    CancellationToken token,
  ) => Future<Result<ProviderConnectionResult>>.value(
    const Success<ProviderConnectionResult>(
      ProviderConnectionResult(isConnected: true),
    ),
  );
}

final class _NetworkAwareBootstrap implements ProviderPlatformBootstrap {
  bool? networkEnabled;

  @override
  Future<Result<ProviderPlatformBootstrapResult>> initialize({
    required bool networkEnabled,
  }) {
    this.networkEnabled = networkEnabled;
    return Future<Result<ProviderPlatformBootstrapResult>>.value(
      Success<ProviderPlatformBootstrapResult>(
        ProviderPlatformBootstrapResult(_EmptyRegistry()),
      ),
    );
  }
}

final class _EmptyRegistry implements ProviderRegistry {
  @override
  ModelProviderAdapter? adapterFor(String providerId) => null;

  @override
  ProviderDefinition? definitionFor(String providerId) => null;

  @override
  Iterable<ProviderDefinition> get definitions => const <ProviderDefinition>[];
}
