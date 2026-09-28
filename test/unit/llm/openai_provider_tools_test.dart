import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:clipmind/data/services/llm/openai_provider.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';

class _MockDio extends Mock implements Dio {}

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

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
    registerFallbackValue(Options());
  });

  group('OpenAiProvider.chatWithTools request shape', () {
    test('sends strict tools, no parallel calls, completion tokens', () async {
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
        return Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          statusCode: 200,
          data: {
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {'role': 'assistant', 'content': 'Done.'},
              },
            ],
          },
        );
      });

      final provider = OpenAiProvider(
        config: const OpenAiConfig(apiKey: 'test-key'),
        dio: dio,
      );
      final result = await provider.chatWithTools(_request());

      expect(result.text, equals('Done.'));
      expect(result.stopReason, equals(AgentTurnStopReason.stop));
      final tools = captured!['tools'] as List;
      expect(tools.single['type'], equals('function'));
      expect(tools.single['function']['strict'], isTrue);
      expect(tools.single['function']['name'], equals('trim_clip'));
      expect(captured!['parallel_tool_calls'], isFalse);
      expect(captured!['tool_choice'], equals({'type': 'auto'}));
      expect(captured!['max_completion_tokens'], equals(4096));
      expect(captured!.containsKey('max_tokens'), isFalse);
    });
  });

  group('OpenAiProvider.chatWithTools response parsing', () {
    test('parses tool_calls with JSON-string arguments', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: '/v1/chat/completions'),
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

      final provider = OpenAiProvider(
        config: const OpenAiConfig(apiKey: 'test-key'),
        dio: dio,
      );
      final result = await provider.chatWithTools(_request());

      expect(result.stopReason, equals(AgentTurnStopReason.toolCalls));
      expect(result.toolCalls, hasLength(1));
      expect(result.toolCalls.single.id, equals('call_1'));
      expect(result.toolCalls.single.name, equals('trim_clip'));
      expect(result.toolCalls.single.args['clip_id'], equals('clip_1'));
    });
  });

  group('OpenAiProvider.chatWithTools history mapping', () {
    test('assistant tool calls and tool results map to wire roles', () async {
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
        return Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          statusCode: 200,
          data: {
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {'role': 'assistant', 'content': 'All set.'},
              },
            ],
          },
        );
      });

      final provider = OpenAiProvider(
        config: const OpenAiConfig(apiKey: 'test-key'),
        dio: dio,
      );
      await provider.chatWithTools(_request(history: const [
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
  });

  group('OpenAiProvider empty userContent omission', () {
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
        return Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          statusCode: 200,
          data: {
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {'role': 'assistant', 'content': 'Done.'},
              },
            ],
          },
        );
      });

      final provider = OpenAiProvider(
        config: const OpenAiConfig(apiKey: 'test-key'),
        dio: dio,
      );
      await provider.chatWithTools(AgentTurnRequest(
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

  group('OpenAiProvider capability + registry', () {
    test('supports tool calling', () {
      final provider = OpenAiProvider(
        config: const OpenAiConfig(apiKey: 'test-key'),
      );
      expect(provider.supportsToolCalling, isTrue);
    });

    test('registry exposes exactly the 19 curated tools', () {
      expect(ToolRegistry.defaultDefinitions(), hasLength(19));
    });
  });
}
