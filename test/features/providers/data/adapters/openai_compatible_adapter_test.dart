import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/adapters/openai_compatible_adapter.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/model_tool_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_adapter_fakes.dart';

void main() {
  test(
    'uses the profile prefix and preserves zero-valued function arguments',
    () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
        Success<ProviderHttpResponse>(
          ProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{
              'data': <Object?>[
                <String, Object?>{'id': 'chat'},
              ],
            },
          ),
        ),
        Success<ProviderHttpResponse>(
          ProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, Object?>{
                    'content': '',
                    'tool_calls': <Object?>[
                      <String, Object?>{
                        'id': 'call',
                        'function': <String, Object?>{
                          'name': 'brightness',
                          'arguments': '{"brightness":0}',
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
      final adapter = OpenAiCompatibleAdapter(
        transport: transport,
        credentials: MemoryCredentials(<String, String>{
          'clipmind_provider_profile_api_key': 'secret',
        }),
      );
      final profile = testProfile('openai');

      await adapter.discoverModels(profile, CancellationController().token);
      final result = await adapter.complete(
        ModelRequest(
          providerId: 'openai',
          modelId: 'chat',
          messages: <Map<String, Object?>>[
            <String, Object?>{'role': 'user', 'content': 'hi'},
          ],
          tools: <ModelToolDefinition>[
            ModelToolDefinition(
              name: 'brightness',
              description: 'set',
              inputSchema: <String, Object?>{'type': 'object'},
            ),
          ],
        ),
        profile,
        CancellationController().token,
      );

      expect(
        transport.requests.first.uri.toString(),
        'https://example.test/prefix/v1/models',
      );
      expect(transport.requests.last.headers['Authorization'], 'Bearer secret');
      expect(transport.requests.last.method, ProviderHttpMethod.post);
      expect(transport.requests.last.timeout, profile.timeout);
      final body = transport.requests.last.body! as Map<Object?, Object?>;
      final tool =
          (body['tools']! as List<Object?>).single as Map<Object?, Object?>;
      expect(
        (tool['function']! as Map<Object?, Object?>)['parameters'],
        <String, Object?>{'type': 'object'},
      );
      expect(
        (result as Success).value.toolCalls.single.arguments['brightness'],
        0,
      );
    },
  );

  test(
    'allows an uncredentialed local custom profile but protects built-in profiles',
    () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
        Success<ProviderHttpResponse>(
          ProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{
              'data': <Object?>[
                <String, Object?>{'id': 'local-model'},
              ],
            },
          ),
        ),
      ]);
      final adapter = OpenAiCompatibleAdapter(
        transport: transport,
        credentials: MemoryCredentials(),
      );
      final custom = ProviderProfile(
        id: 'local',
        providerId: customOpenAiCompatibleProviderId,
        displayName: 'Local',
        endpoint: Uri.parse('http://127.0.0.1:8080/v1'),
      );

      expect(
        await adapter.discoverModels(custom, CancellationController().token),
        isA<Success<List<ModelDescriptor>>>(),
      );
      expect(
        transport.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
      expect(
        await adapter.discoverModels(
          testProfile('openai'),
          CancellationController().token,
        ),
        isA<Failure<List<ModelDescriptor>>>(),
      );
      expect(transport.requests, hasLength(1));

      final securedTransport = RecordingTransport(
        <Result<ProviderHttpResponse>>[
          Success<ProviderHttpResponse>(
            ProviderHttpResponse(
              statusCode: 200,
              body: <String, Object?>{
                'data': <Object?>[
                  <String, Object?>{'id': 'secured-model'},
                ],
              },
            ),
          ),
        ],
      );
      final securedProfile = ProviderProfile(
        id: 'secured',
        providerId: customOpenAiCompatibleProviderId,
        displayName: 'Secured local',
        endpoint: Uri.parse('http://127.0.0.1:8080/v1'),
        credentialId: 'clipmind_provider_secured_api_key',
      );
      final securedAdapter = OpenAiCompatibleAdapter(
        transport: securedTransport,
        credentials: MemoryCredentials(<String, String>{
          'clipmind_provider_secured_api_key': 'local-secret',
        }),
      );
      await securedAdapter.discoverModels(
        securedProfile,
        CancellationController().token,
      );
      expect(
        securedTransport.requests.single.headers['Authorization'],
        'Bearer local-secret',
      );
    },
  );

  test(
    'returns typed validation and cancellation failures without transport work',
    () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[]);
      final adapter = OpenAiCompatibleAdapter(
        transport: transport,
        credentials: MemoryCredentials(<String, String>{
          'clipmind_provider_profile_api_key': 'secret',
        }),
      );
      final cancelled = CancellationController()..cancel();
      expect(
        await adapter.discoverModels(testProfile('openai'), cancelled.token),
        isA<Failure<List<ModelDescriptor>>>(),
      );
      expect(transport.requests, isEmpty);
      final malformed = await adapter.complete(
        ModelRequest(
          providerId: 'openai',
          modelId: 'model',
          messages: <Map<String, Object?>>[
            <String, Object?>{'role': 'user', 'content': 'hi'},
          ],
        ),
        testProfile('openai'),
        CancellationController().token,
      );
      expect((malformed as Failure).error, isA<ProviderTransportFailure>());
    },
  );
}
