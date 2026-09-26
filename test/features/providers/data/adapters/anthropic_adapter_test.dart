import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/adapters/anthropic_adapter.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/model_tool_definition.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_adapter_fakes.dart';

void main() {
  test(
    'uses manual discovery without a request and parses content blocks',
    () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
        Success<ProviderHttpResponse>(
          ProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{
              'content': <Object?>[
                <String, Object?>{'type': 'text', 'text': 'hello'},
                <String, Object?>{
                  'type': 'tool_use',
                  'id': 'use-1',
                  'name': 'edit',
                  'input': <String, Object?>{'amount': 0},
                },
              ],
            },
          ),
        ),
      ]);
      final adapter = AnthropicAdapter(
        transport: transport,
        credentials: MemoryCredentials(<String, String>{
          'clipmind_provider_profile_api_key': 'secret',
        }),
      );
      final profile = testProfile('anthropic', manual: <String>['claude']);

      final discovered = await adapter.discoverModels(
        profile,
        CancellationController().token,
      );
      final completed = await adapter.complete(
        ModelRequest(
          providerId: 'anthropic',
          modelId: 'claude',
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

      expect((discovered as Success).value.single.id, 'claude');
      expect(transport.requests.single.uri.path, '/prefix/v1/messages');
      expect(transport.requests.single.method, ProviderHttpMethod.post);
      expect(transport.requests.single.headers['x-api-key'], 'secret');
      expect(
        transport.requests.single.headers['anthropic-version'],
        '2023-06-01',
      );
      expect(transport.requests.single.timeout, profile.timeout);
      final body = transport.requests.single.body! as Map<Object?, Object?>;
      final tool =
          (body['tools']! as List<Object?>).single as Map<Object?, Object?>;
      expect(tool['input_schema'], <String, Object?>{'type': 'object'});
      expect(
        (completed as Success).value.toolCalls.single.arguments['amount'],
        0,
      );
    },
  );

  test(
    'connection testing requires a manual model and cancellation does no work',
    () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[]);
      final adapter = AnthropicAdapter(
        transport: transport,
        credentials: MemoryCredentials(),
      );
      final cancelled = CancellationController()..cancel();
      expect(
        await adapter.discoverModels(testProfile('anthropic'), cancelled.token),
        isA<Failure<List<ModelDescriptor>>>(),
      );
      final connection = await adapter.testConnection(
        testProfile('anthropic'),
        CancellationController().token,
      );
      expect((connection as Failure).error, isA<ProviderValidationFailure>());
      expect(transport.requests, isEmpty);
    },
  );
}
