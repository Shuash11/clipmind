import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/adapters/gemini_adapter.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/model_tool_definition.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_adapter_fakes.dart';

void main() {
  test('uses a query credential and avoids duplicate models path', () async {
    final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
      Success<ProviderHttpResponse>(
        ProviderHttpResponse(
          statusCode: 200,
          body: <String, Object?>{
            'models': <Object?>[
              <String, Object?>{'name': 'models/gemini-test'},
            ],
          },
        ),
      ),
      Success<ProviderHttpResponse>(
        ProviderHttpResponse(
          statusCode: 200,
          body: <String, Object?>{
            'candidates': <Object?>[
              <String, Object?>{
                'content': <String, Object?>{
                  'parts': <Object?>[
                    <String, Object?>{
                      'functionCall': <String, Object?>{
                        'name': 'edit',
                        'args': <String, Object?>{'value': 0},
                      },
                    },
                  ],
                },
              },
            ],
          },
        ),
      ),
    ]);
    final adapter = GeminiAdapter(
      transport: transport,
      credentials: MemoryCredentials(<String, String>{
        'clipmind_provider_profile_api_key': 'secret',
      }),
    );
    final profile = testProfile('gemini');

    await adapter.discoverModels(profile, CancellationController().token);
    final completed = await adapter.complete(
      ModelRequest(
        providerId: 'gemini',
        modelId: 'models/gemini-test',
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

    expect(
      transport.requests.last.uri.path,
      '/prefix/v1/models/gemini-test:generateContent',
    );
    expect(transport.requests.last.uri.queryParameters['key'], 'secret');
    expect(transport.requests.last.method, ProviderHttpMethod.post);
    expect(transport.requests.last.timeout, profile.timeout);
    final body = transport.requests.last.body! as Map<Object?, Object?>;
    final tools = body['tools']! as List<Object?>;
    final declarations =
        (tools.single as Map<Object?, Object?>)['functionDeclarations']!
            as List<Object?>;
    expect(
      (declarations.single as Map<Object?, Object?>)['parameters'],
      <String, Object?>{'type': 'object'},
    );
    expect((completed as Success).value.toolCalls.single.id, 'gemini-call-0');
  });

  test(
    'missing credentials and cancellation prevent Gemini transport work',
    () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[]);
      final adapter = GeminiAdapter(
        transport: transport,
        credentials: MemoryCredentials(),
      );
      expect(
        await adapter.discoverModels(
          testProfile('gemini'),
          CancellationController().token,
        ),
        isA<Failure<List<ModelDescriptor>>>(),
      );
      final cancelled = CancellationController()..cancel();
      final result = await adapter.complete(
        ModelRequest(
          providerId: 'gemini',
          modelId: 'gemini',
          messages: <Map<String, Object?>>[
            <String, Object?>{'role': 'user', 'content': 'hi'},
          ],
        ),
        testProfile('gemini'),
        cancelled.token,
      );
      expect((result as Failure).error, isA<ProviderCancellationFailure>());
      expect(transport.requests, isEmpty);
    },
  );
}
