import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/adapters/provider_adapter_support.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/normalized_model_tool_call.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_connection_result.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';

final class AnthropicAdapter extends ProviderAdapterBase {
  AnthropicAdapter({required super.transport, required super.credentials})
    : super(providerIds: const <String>['anthropic']);

  static const int _discoveryPageLimit = 1000;
  static const int _maxDiscoveryPages = 5;

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
      needsApiKey: true,
      apiHeader: 'x-api-key',
      requiredHeaders: const <String, String>{
        'anthropic-version': '2023-06-01',
      },
    );
    if (headers is Failure<Map<String, String>>) {
      return Failure<List<ModelDescriptor>>(headers.error);
    }
    final models = <ModelDescriptor>[];
    String? afterId;
    for (var page = 0; page < _maxDiscoveryPages; page++) {
      final sent = await send(
        ProviderHttpRequest(
          method: ProviderHttpMethod.get,
          uri: _modelsUri(profile, afterId: afterId),
          headers: (headers as Success<Map<String, String>>).value,
          timeout: profile.timeout,
          isDiscovery: true,
        ),
        token,
      );
      if (sent is Failure<ProviderHttpResponse>) {
        return Failure<List<ModelDescriptor>>(sent.error);
      }
      final root = objectMap(
        (sent as Success<ProviderHttpResponse>).value.body,
      );
      final data = root?['data'];
      if (data is! List) {
        return validation<List<ModelDescriptor>>(
          'The provider model response is malformed.',
        );
      }
      for (final item in data) {
        final model = objectMap(item);
        final id = model?['id'];
        if (id is! String || id.isEmpty) {
          return validation<List<ModelDescriptor>>(
            'The provider model response is malformed.',
          );
        }
        final displayName = model?['display_name'];
        models.add(
          ModelDescriptor(
            id: id,
            providerId: profile.providerId,
            displayName: displayName is String ? displayName : id,
          ),
        );
      }
      if (root?['has_more'] != true) break;
      final lastId = root?['last_id'];
      if (lastId is! String || lastId.isEmpty) {
        return validation<List<ModelDescriptor>>(
          'The provider model response is malformed.',
        );
      }
      afterId = lastId;
    }
    return Success<List<ModelDescriptor>>(models);
  }

  Uri _modelsUri(ProviderProfile profile, {String? afterId}) {
    final resolved = endpoint(profile, 'models');
    return resolved.replace(
      queryParameters: <String, String>{
        ...resolved.queryParameters,
        'limit': '$_discoveryPageLimit',
        'after_id': ?afterId,
      },
    );
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
      needsApiKey: true,
      apiHeader: 'x-api-key',
      requiredHeaders: const <String, String>{
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
    );
    if (headers is Failure<Map<String, String>>) {
      return Failure<ModelResponse>(headers.error);
    }
    final tools = request.tools
        .map(
          (tool) => <String, Object?>{
            'name': tool.name,
            'description': tool.description,
            'input_schema': tool.inputSchema,
          },
        )
        .toList(growable: false);
    final sent = await send(
      ProviderHttpRequest(
        method: ProviderHttpMethod.post,
        uri: endpoint(profile, 'messages'),
        headers: (headers as Success<Map<String, String>>).value,
        body: <String, Object?>{
          'model': request.modelId,
          'messages': request.messages,
          'max_tokens': 4096,
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
    final content = root?['content'];
    if (content is! List) {
      return validation<ModelResponse>(
        'The provider completion response is malformed.',
      );
    }
    final text = StringBuffer();
    final calls = <NormalizedModelToolCall>[];
    for (final raw in content) {
      final block = objectMap(raw);
      final type = block?['type'];
      if (type == 'text') {
        if (block?['text'] is! String) {
          return validation<ModelResponse>(
            'The provider completion response is malformed.',
          );
        }
        text.write(block!['text']);
      } else if (type == 'tool_use') {
        final call = toolCall(
          id: block?['id'],
          name: block?['name'],
          input: block?['input'],
        );
        if (call == null) {
          return validation<ModelResponse>(
            'The provider tool call is malformed.',
          );
        }
        calls.add(call);
      }
    }
    return Success<ModelResponse>(
      ModelResponse(
        modelId: request.modelId,
        content: text.toString(),
        toolCalls: calls,
      ),
    );
  }

  @override
  Future<Result<ProviderConnectionResult>> testConnection(
    ProviderProfile profile,
    CancellationToken token,
  ) async {
    final invalid = validateProfile<ProviderConnectionResult>(profile);
    if (invalid != null) return invalid;
    if (token.isCancelled) return cancelled<ProviderConnectionResult>();
    final models = manualModels(profile);
    if (models.isEmpty) {
      return validation<ProviderConnectionResult>(
        'Anthropic connection testing requires a manual model identifier.',
      );
    }
    final completed = await complete(
      ModelRequest(
        providerId: profile.providerId,
        modelId: models.first.id,
        messages: const <Map<String, Object?>>[
          <String, Object?>{'role': 'user', 'content': 'Connection test.'},
        ],
      ),
      profile,
      token,
    );
    if (completed is Failure<ModelResponse>) {
      return Failure<ProviderConnectionResult>(completed.error);
    }
    return const Success<ProviderConnectionResult>(
      ProviderConnectionResult(isConnected: true),
    );
  }
}
