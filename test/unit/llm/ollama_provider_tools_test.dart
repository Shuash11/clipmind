import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/data/services/llm/ollama_provider.dart';
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

OllamaProvider _provider(_MockDio dio, {String apiKey = ''}) {
  final keys = _MockKeyStore();
  when(() => keys.readApiKey(any())).thenAnswer((_) async => null);
  return OllamaProvider(
    config: OllamaConfig(
      host: 'localhost',
      port: 11434,
      model: 'llama3.1',
      apiKey: apiKey,
    ),
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

  group('OllamaProvider.chatWithTools request shape', () {
    test('hits /v1/chat/completions with strict tools + max_tokens', () async {
      final dio = _MockDio();
      Map<String, dynamic>? captured;
      String? capturedPath;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        capturedPath = invocation.positionalArguments.first as String;
        captured = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        return _textResponse('Done.');
      });

      final provider = _provider(dio);
      expect(provider.baseUrl, equals('http://localhost:11434/v1'));
      expect(provider.supportsToolCalling, isTrue);

      final result = await provider.chatWithTools(_request());

      expect(result.text, equals('Done.'));
      expect(result.stopReason, equals(AgentTurnStopReason.stop));
      // Compat endpoint path.
      expect(capturedPath, equals('/v1/chat/completions'));
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

    test('sends no auth header when unconfigured', () async {
      final dio = _MockDio();
      Options? capturedOptions;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        capturedOptions =
            invocation.namedArguments[#options] as Options?;
        return _textResponse('Done.');
      });

      await _provider(dio).chatWithTools(_request());

      final headers = capturedOptions?.headers ?? {};
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('sends Bearer header when a key is configured', () async {
      final dio = _MockDio();
      Options? capturedOptions;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        capturedOptions =
            invocation.namedArguments[#options] as Options?;
        return _textResponse('Done.');
      });

      await _provider(dio, apiKey: 'user-key').chatWithTools(_request());

      expect(
        capturedOptions?.headers?['Authorization'],
        equals('Bearer user-key'),
      );
    });
  });

  group('OllamaProvider.chatWithTools response parsing', () {
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

  group('OllamaProvider.chatWithTools history mapping', () {
    test('assistant tool calls and tool results map to wire roles',
        () async {
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
        return _textResponse('All set.');
      });

      await _provider(dio).chatWithTools(_request(history: const [
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
          content: '{"output_path":"C:\\\\out\\\\op.mp4"}',
          toolCallId: 'call_1',
        ),
      ]));

      final messages = captured!['messages'] as List;
      // system + assistant + tool + user
      expect(messages, hasLength(4));
      final assistant = messages[1] as Map;
      expect(assistant['role'], equals('assistant'));
      final wireCalls = assistant['tool_calls'] as List;
      expect(wireCalls.single['id'], equals('call_1'));
      final toolMsg = messages[2] as Map;
      expect(toolMsg['role'], equals('tool'));
      expect(toolMsg['tool_call_id'], equals('call_1'));
      expect(messages.last['role'], equals('user'));
    });

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

  group('OllamaProvider.chatWithTools errors', () {
    test('non-tools model failure names the fix', () async {
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
              statusCode: 400,
              data: {
                'error': 'model does not support tools',
              },
            ),
          ));

      expect(
        () => _provider(dio).chatWithTools(_request()),
        throwsA(isA<ProviderFailure>().having(
          (f) => f.message,
          'message',
          contains('tools-capable model (e.g. llama3.1)'),
        )),
      );
    });

    test('connection failure names the endpoint', () async {
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
          contains('Is Ollama running?'),
        )),
      );
    });
  });
}
