import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/adapters/provider_adapter_support.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/normalized_model_tool_call.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';

final class GeminiAdapter extends ProviderAdapterBase {
  GeminiAdapter({required super.transport, required super.credentials})
    : super(providerIds: const <String>['gemini']);

  @override
  Future<Result<List<ModelDescriptor>>> discoverModels(
    ProviderProfile profile,
    CancellationToken token,
  ) async {
    final invalid = validateProfile<List<ModelDescriptor>>(profile);
    if (invalid != null) return invalid;
    if (token.isCancelled) return cancelled<List<ModelDescriptor>>();
    final prepared = await _uriAndHeaders(profile, 'models');
    if (prepared is Failure<_GeminiRequest>) {
      return Failure<List<ModelDescriptor>>(prepared.error);
    }
    final preparedValue = (prepared as Success<_GeminiRequest>).value;
    final sent = await send(
      ProviderHttpRequest(
        method: ProviderHttpMethod.get,
        uri: preparedValue.uri,
        headers: preparedValue.headers,
        timeout: profile.timeout,
        isDiscovery: true,
      ),
      token,
    );
    if (sent is Failure<ProviderHttpResponse>) {
      return Failure<List<ModelDescriptor>>(sent.error);
    }
    final root = objectMap((sent as Success<ProviderHttpResponse>).value.body);
    final models = root?['models'];
    if (models is! List) {
      return validation<List<ModelDescriptor>>(
        'The provider model response is malformed.',
      );
    }
    final results = <ModelDescriptor>[];
    for (final raw in models) {
      final model = objectMap(raw);
      final name = model?['name'];
      if (name is! String || name.isEmpty) {
        return validation<List<ModelDescriptor>>(
          'The provider model response is malformed.',
        );
      }
      final id = name.startsWith('models/')
          ? name.substring('models/'.length)
          : name;
      if (id.isEmpty) {
        return validation<List<ModelDescriptor>>(
          'The provider model response is malformed.',
        );
      }
      results.add(
        ModelDescriptor(
          id: id,
          providerId: profile.providerId,
          displayName: model?['displayName'] is String
              ? model!['displayName'] as String
              : id,
        ),
      );
    }
    return Success<List<ModelDescriptor>>(results);
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
    final model = request.modelId.startsWith('models/')
        ? request.modelId.substring('models/'.length)
        : request.modelId;
    if (model.isEmpty) {
      return validation<ModelResponse>('A model identifier is required.');
    }
    final prepared = await _uriAndHeaders(
      profile,
      'models/${Uri.encodeComponent(model)}:generateContent',
    );
    if (prepared is Failure<_GeminiRequest>) {
      return Failure<ModelResponse>(prepared.error);
    }
    final contents = <Map<String, Object?>>[];
    for (final message in request.messages) {
      final role = message['role'];
      final content = message['content'];
      if (role is! String || content is! String) {
        return validation<ModelResponse>('The provider message is malformed.');
      }
      contents.add(<String, Object?>{
        'role': role == 'assistant' ? 'model' : 'user',
        'parts': <Object?>[
          <String, Object?>{'text': content},
        ],
      });
    }
    final declarations = request.tools
        .map(
          (tool) => <String, Object?>{
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.inputSchema,
          },
        )
        .toList(growable: false);
    final preparedValue = (prepared as Success<_GeminiRequest>).value;
    final sent = await send(
      ProviderHttpRequest(
        method: ProviderHttpMethod.post,
        uri: preparedValue.uri,
        headers: preparedValue.headers,
        body: <String, Object?>{
          'contents': contents,
          if (declarations.isNotEmpty)
            'tools': <Object?>[
              <String, Object?>{'functionDeclarations': declarations},
            ],
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
    final candidates = root?['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return validation<ModelResponse>(
        'The provider completion response is malformed.',
      );
    }
    final candidateContent = objectMap(objectMap(candidates.first)?['content']);
    final parts = candidateContent?['parts'];
    if (parts is! List) {
      return validation<ModelResponse>(
        'The provider completion response is malformed.',
      );
    }
    final text = StringBuffer();
    final calls = <NormalizedModelToolCall>[];
    var callIndex = 0;
    for (final raw in parts) {
      final part = objectMap(raw);
      if (part?['text'] is String) text.write(part!['text']);
      final function = objectMap(part?['functionCall']);
      if (function != null) {
        final id =
            function['id'] is String && (function['id'] as String).isNotEmpty
            ? function['id'] as String
            : 'gemini-call-$callIndex';
        final call = toolCall(
          id: id,
          name: function['name'],
          input: function['args'] ?? const <String, Object?>{},
        );
        if (call == null) {
          return validation<ModelResponse>(
            'The provider tool call is malformed.',
          );
        }
        calls.add(call);
        callIndex++;
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

  Future<Result<_GeminiRequest>> _uriAndHeaders(
    ProviderProfile profile,
    String relative,
  ) async {
    final headers = await headersFor(
      profile,
      needsApiKey: false,
      requiredHeaders: const <String, String>{
        'Content-Type': 'application/json',
      },
    );
    if (headers is Failure<Map<String, String>>) {
      return Failure<_GeminiRequest>(headers.error);
    }
    final key = await apiKeyFor(profile);
    if (key is Failure<String>) {
      return Failure<_GeminiRequest>(key.error);
    }
    final resolved = endpoint(profile, relative);
    final uri = resolved.replace(
      queryParameters: <String, String>{
        ...resolved.queryParameters,
        'key': (key as Success<String>).value,
      },
    );
    return Success<_GeminiRequest>(
      _GeminiRequest(uri, (headers as Success<Map<String, String>>).value),
    );
  }
}

final class _GeminiRequest {
  const _GeminiRequest(this.uri, this.headers);
  final Uri uri;
  final Map<String, String> headers;
}
