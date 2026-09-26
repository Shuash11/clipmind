import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/adapters/ollama_adapter.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/entities/model_tool_definition.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_adapter_fakes.dart';

void main() {
  test(
    'discovers tags and accepts string function arguments without an api key',
    () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
        Success<ProviderHttpResponse>(
          ProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{
              'models': <Object?>[
                <String, Object?>{'name': 'llama'},
              ],
            },
          ),
        ),
        Success<ProviderHttpResponse>(
          ProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{
              'message': <String, Object?>{
                'content': '',
                'tool_calls': <Object?>[
                  <String, Object?>{
                    'id': 'call',
                    'function': <String, Object?>{
                      'name': 'edit',
                      'arguments': '{"enabled":false,"amount":-1}',
                    },
                  },
                ],
              },
            },
          ),
        ),
      ]);
      final adapter = OllamaAdapter(
        transport: transport,
        credentials: MemoryCredentials(),
      );
      final profile = testProfile('ollama');

      await adapter.discoverModels(profile, CancellationController().token);
      final completed = await adapter.complete(
        ModelRequest(
          providerId: 'ollama',
          modelId: 'llama',
          messages: <Map<String, Object?>>[
            <String, Object?>{'role': 'user', 'content': 'hi'},
          ],
          tools: <ModelToolDefinition>[
            ModelToolDefinition(
              name: 'edit',
              description: 'edit',
              inputSchema: <String, Object?>{'type': 'object'},
            ),
          ],
        ),
        profile,
        CancellationController().token,
      );

      expect(transport.requests.first.uri.path, '/prefix/v1/api/tags');
      expect(transport.requests.last.uri.path, '/prefix/v1/api/chat');
      expect(transport.requests.last.method, ProviderHttpMethod.post);
      expect(
        transport.requests.last.headers['Content-Type'],
        'application/json',
      );
      expect(transport.requests.last.timeout, profile.timeout);
      final body = transport.requests.last.body! as Map<Object?, Object?>;
      final tool =
          (body['tools']! as List<Object?>).single as Map<Object?, Object?>;
      expect(
        (tool['function']! as Map<Object?, Object?>)['parameters'],
        <String, Object?>{'type': 'object'},
      );
      expect(
        (completed as Success).value.toolCalls.single.arguments['amount'],
        -1,
      );
    },
  );

  test(
    'pre-cancellation returns a typed failure before an Ollama request',
    () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[]);
      final cancelled = CancellationController()..cancel();
      final result = await OllamaAdapter(
        transport: transport,
        credentials: MemoryCredentials(),
      ).discoverModels(testProfile('ollama'), cancelled.token);
      expect((result as Failure).error, isA<ProviderCancellationFailure>());
      expect(transport.requests, isEmpty);
    },
  );
}
