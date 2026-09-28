import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/data/services/llm/nvidia_nim_provider.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';

class _MockDio extends Mock implements Dio {}

class _MockKeyStore extends Mock implements SecureKeyStore {}

AgentTurnRequest _request({List<AgentTurnMessage> history = const []}) {
  return AgentTurnRequest(
    systemPrompt: 'system',
    userContent: 'Trim the first 5 seconds',
    tools: [
      const ToolDefinition(
        name: 'trim_clip',
        description: 'Trim a clip.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'clip_id': {'type': 'string'},
          },
          'required': ['clip_id'],
          'additionalProperties': false,
        },
        category: ToolCategory.edit,
      ),
    ],
    history: history,
  );
}

NvidiaNimProvider _provider(_MockDio dio) {
  final keys = _MockKeyStore();
  when(() => keys.readApiKey(any())).thenAnswer((_) async => 'nim-key');
  return NvidiaNimProvider(
    config: const NvidiaNimConfig(),
    keyStore: keys,
    dio: dio,
  );
}

Response<Map<String, dynamic>> _textResponse(String text) {
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/v1/chat/completions'),
    statusCode: 200,
    data: {
      'choices': [
        {
          'finish_reason': 'stop',
          'message': {'role': 'assistant', 'content': text},
        },
      ],
    },
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
    registerFallbackValue(Options());
  });

  group('NvidiaNimProvider.chatWithTools request shape', () {
    test('hits integrate.api.nvidia.com with strict tools + max_tokens',
        () async {
      final dio = _MockDio();
      Map<String, dynamic>? captured;
      String? capturedPath;
      Options? capturedOptions;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        capturedPath = invocation.positionalArguments.first as String;
        captured = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        capturedOptions =
            invocation.namedArguments[#options] as Options?;
        return _textResponse('Done.');
      });

      final provider = _provider(dio);
      expect(provider.baseUrl, equals('https://integrate.api.nvidia.com'));
      expect(provider.supportsToolCalling, isTrue);

      final result = await provider.chatWithTools(_request());

      expect(result.text, equals('Done.'));
      expect(result.stopReason, equals(AgentTurnStopReason.stop));
      expect(capturedPath, equals('/v1/chat/completions'));
      // Bearer auth from the key store.
      expect(
        capturedOptions?.headers?['Authorization'],
        equals('Bearer nim-key'),
      );
      final tools = captured!['tools'] as List;
      expect(tools.single['type'], equals('function'));
      expect(tools.single['function']['strict'], isTrue);
      expect(tools.single['function']['name'], equals('trim_clip'));
      expect(captured!['tool_choice'], equals({'type': 'auto'}));
      // Conservative subset: legacy max_tokens, no unverified extras.
      expect(captured!['max_tokens'], equals(4096));
      expect(captured!.containsKey('max_completion_tokens'), isFalse);
      expect(captured!.containsKey('parallel_tool_calls'), isFalse);
    });
  });

  group('NvidiaNimProvider.chatWithTools response parsing', () {
    test('parses tool_calls with JSON-string arguments', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions:
                    RequestOptions(path: '/v1/chat/completions'),
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'finish_reason': 'tool_calls',
                      'message': {
                        'role': 'assistant',
                        'content': null,
                        'tool_calls': [
                          {
                            'id': 'call_1',
                            'type': 'function',
                            'function': {
                              'name': 'trim_clip',
                              'arguments': jsonEncode({
                                'clip_id': 'clip_1',
                                'start': '00:00:05.000',
                                'end': '00:00:15.000',
                              }),
                            },
                          },
                        ],
                      },
                    },
                  ],
                },
              ));

      final result = await _provider(dio).chatWithTools(_request());

      expect(result.stopReason, equals(AgentTurnStopReason.toolCalls));
      expect(result.toolCalls, hasLength(1));
      expect(result.toolCalls.single.id, equals('call_1'));
      expect(result.toolCalls.single.name, equals('trim_clip'));
      expect(result.toolCalls.single.args['clip_id'], equals('clip_1'));
    });
  });

  group('NvidiaNimProvider.chatWithTools history mapping', () {
    test('round-2 request omits the trailing user message', () async {
      final dio = _MockDio();
      Map<String, dynamic>? captured;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        captured = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        return _textResponse('Done.');
      });

      await _provider(dio).chatWithTools(AgentTurnRequest(
        systemPrompt: 'system',
        userContent: '',
        tools: _request().tools,
        history: const [
          AgentTurnMessage(
            role: AgentTurnRole.user,
            content: 'Trim the first 5 seconds',
          ),
          AgentTurnMessage(
            role: AgentTurnRole.assistant,
            toolCalls: [
              AgentToolCall(
                id: 'call_1',
                name: 'trim_clip',
                args: {'clip_id': 'clip_1'},
              ),
            ],
          ),
          AgentTurnMessage(
            role: AgentTurnRole.toolResult,
            content: '{"success":true}',
            toolCallId: 'call_1',
          ),
        ],
      ));

      final messages = captured!['messages'] as List;
      // system + original user + assistant + tool: no trailing user.
      expect(messages, hasLength(4));
      expect((messages[1] as Map)['role'], equals('user'));
      expect(
        (messages[1] as Map)['content'],
        contains('Trim the first 5 seconds'),
      );
      final last = messages.last as Map;
      expect(last['role'], equals('tool'));
      expect(last['tool_call_id'], equals('call_1'));
    });
  });

  group('NvidiaNimProvider.chatWithTools errors', () {
    test('401 maps to invalid API key', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
            requestOptions:
                RequestOptions(path: '/v1/chat/completions'),
            type: DioExceptionType.badResponse,
            response: Response<Map<String, dynamic>>(
              requestOptions:
                  RequestOptions(path: '/v1/chat/completions'),
              statusCode: 401,
            ),
          ));

      expect(
        () => _provider(dio).chatWithTools(_request()),
        throwsA(isA<ProviderFailure>().having(
          (f) => f.message,
          'message',
          contains('Invalid API key'),
        )),
      );
    });

    test('429 maps to rate-limited text', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
            requestOptions:
                RequestOptions(path: '/v1/chat/completions'),
            type: DioExceptionType.badResponse,
            response: Response<Map<String, dynamic>>(
              requestOptions:
                  RequestOptions(path: '/v1/chat/completions'),
              statusCode: 429,
            ),
          ));

      expect(
        () => _provider(dio).chatWithTools(_request()),
        throwsA(isA<ProviderFailure>().having(
          (f) => f.message,
          'message',
          contains('Rate limited'),
        )),
      );
    });

    test('connection failure names the NIM endpoint', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
            requestOptions:
                RequestOptions(path: '/v1/chat/completions'),
            type: DioExceptionType.connectionError,
          ));

      expect(
        () => _provider(dio).chatWithTools(_request()),
        throwsA(isA<ProviderFailure>().having(
          (f) => f.message,
          'message',
          contains('Cannot connect to NVIDIA NIM API'),
        )),
      );
    });
  });

  group('NvidiaNimProvider model catalog', () {
    test('default model is in the verified catalog', () async {
      final dio = _MockDio();
      final provider = _provider(dio);
      final models = await provider.availableModels();
      expect(
        provider.id,
        equals('nvidia_nim:meta/llama-3.3-70b-instruct'),
      );
      expect(models, contains('meta/llama-3.3-70b-instruct'));
    });

    test('no stale model IDs remain', () async {
      final dio = _MockDio();
      final models = await _provider(dio).availableModels();
      expect(models, isNot(contains('meta/llama-3.1-405b-instruct')));
      expect(models, isNot(contains('mistralai/mistral-large')));
      expect(models, isNot(contains('nvidia/llama-3.1-nv-70b-instruct')));
      expect(
        models,
        containsAll([
          'nvidia/llama-3.3-nemotron-super-49b-v1.5',
          'qwen/qwen3-next-80b-a3b-instruct',
          'openai/gpt-oss-120b',
          'moonshotai/kimi-k2-instruct',
          'meta/llama-3.1-8b-instruct',
        ]),
      );
    });
  });
}
