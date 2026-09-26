import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/adapters/provider_adapter_support.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/normalized_model_tool_call.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';

final class OpenAiCompatibleAdapter extends ProviderAdapterBase {
  OpenAiCompatibleAdapter({
    required super.transport,
    required super.credentials,
    super.providerIds = const <String>[
      'nvidia',
      'openai',
      'openrouter',
      'groq',
      'cerebras',
      'deepseek',
      'together',
      'fireworks',
      'xai',
      'mistral',
      customOpenAiCompatibleProviderId,
    ],
  });

  @override
  Future<Result<List<ModelDescriptor>>> discoverModels(
    ProviderProfile profile,
    CancellationToken token,
  ) async {
    final invalid = validateProfile<List<ModelDescriptor>>(profile);
    if (invalid != null) return invalid;
    if (token.isCancelled) return cancelled<List<ModelDescriptor>>();
    final headers = await headersFor(
      profile,
      needsApiKey: _needsApiKey(profile),
      apiHeader: 'Authorization',
      bearerApiKey: true,
    );
    if (headers is Failure<Map<String, String>>) {
      return Failure<List<ModelDescriptor>>(headers.error);
    }
    final sent = await send(
      ProviderHttpRequest(
        method: ProviderHttpMethod.get,
        uri: endpoint(profile, 'models'),
        headers: (headers as Success<Map<String, String>>).value,
        timeout: profile.timeout,
        isDiscovery: true,
      ),
      token,
    );
    if (sent is Failure<ProviderHttpResponse>) {
      return Failure<List<ModelDescriptor>>(sent.error);
    }
    final root = objectMap((sent as Success<ProviderHttpResponse>).value.body);
    final data = root?['data'];
    if (data is! List) {
      return validation<List<ModelDescriptor>>(
        'The provider model response is malformed.',
      );
    }
    final models = <ModelDescriptor>[];
    for (final item in data) {
      final model = objectMap(item);
      final id = model?['id'];
      if (id is! String || id.isEmpty) {
        return validation<List<ModelDescriptor>>(
          'The provider model response is malformed.',
        );
      }
      models.add(
        ModelDescriptor(
          id: id,
          providerId: profile.providerId,
          displayName: id,
        ),
      );
    }
    return Success<List<ModelDescriptor>>(models);
  }

  @override
  Future<Result<ModelResponse>> complete(
    ModelRequest request,
    ProviderProfile profile,
    CancellationToken token,
  ) async {
    final invalid = validateProfile<ModelResponse>(profile, request: request);
    if (invalid != null) return invalid;
    if (token.isCancelled) return cancelled<ModelResponse>();
    final headers = await headersFor(
      profile,
      needsApiKey: _needsApiKey(profile),
      apiHeader: 'Authorization',
      bearerApiKey: true,
      requiredHeaders: const <String, String>{
        'Content-Type': 'application/json',
      },
    );
    if (headers is Failure<Map<String, String>>) {
      return Failure<ModelResponse>(headers.error);
    }
    final tools = request.tools
        .map(
          (tool) => <String, Object?>{
            'type': 'function',
            'function': <String, Object?>{
              'name': tool.name,
              'description': tool.description,
              'parameters': tool.inputSchema,
            },
          },
        )
        .toList(growable: false);
    final sent = await send(
      ProviderHttpRequest(
        method: ProviderHttpMethod.post,
        uri: endpoint(profile, 'chat/completions'),
        headers: (headers as Success<Map<String, String>>).value,
        body: <String, Object?>{
          'model': request.modelId,
          'messages': request.messages,
          if (tools.isNotEmpty) 'tools': tools,
        },
        timeout: profile.timeout,
        idempotencyKey: request.idempotencyKey,
      ),
      token,
    );
    if (sent is Failure<ProviderHttpResponse>) {
      return Failure<ModelResponse>(sent.error);
    }
    final root = objectMap((sent as Success<ProviderHttpResponse>).value.body);
    final choices = root?['choices'];
    if (choices is! List || choices.isEmpty) {
      return validation<ModelResponse>(
        'The provider completion response is malformed.',
      );
    }
    final message = objectMap(objectMap(choices.first)?['message']);
    if (message == null) {
      return validation<ModelResponse>(
        'The provider completion response is malformed.',
      );
    }
    final content = message['content'];
    if (content != null && content is! String) {
      return validation<ModelResponse>(
        'The provider completion response is malformed.',
      );
    }
    final rawCalls = message['tool_calls'];
    if (rawCalls != null && rawCalls is! List) {
      return validation<ModelResponse>(
        'The provider completion response is malformed.',
      );
    }
    final calls = <NormalizedModelToolCall>[];
    final rawToolCalls = rawCalls == null
        ? const <Object?>[]
        : List<Object?>.from(rawCalls as List);
    for (final raw in rawToolCalls) {
      final call = objectMap(raw);
      final function = objectMap(call?['function']);
      final normalized = toolCall(
        id: call?['id'],
        name: function?['name'],
        input: function?['arguments'],
      );
      if (normalized == null) {
        return validation<ModelResponse>(
          'The provider tool call is malformed.',
        );
      }
      calls.add(normalized);
    }
    return Success<ModelResponse>(
      ModelResponse(
        modelId: request.modelId,
        content: content as String? ?? '',
        toolCalls: calls,
      ),
    );
  }

  bool _needsApiKey(ProviderProfile profile) =>
      profile.providerId != customOpenAiCompatibleProviderId ||
      profile.credentialId != null;
}
