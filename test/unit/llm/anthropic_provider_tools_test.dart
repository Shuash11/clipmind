import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:clipmind/data/services/llm/anthropic_provider.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';

class _MockDio extends Mock implements Dio {}

AgentTurnRequest _request({List<AgentTurnMessage> history = const []}) {
  return AgentTurnRequest(
    systemPrompt: 'system',
    userContent: 'Trim then mute',
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

  group('AnthropicProvider.chatWithTools request shape', () {
    test('sends strict tools with auto tool_choice, no parallel use',
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
        return Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/messages'),
          statusCode: 200,
          data: {
            'stop_reason': 'end_turn',
            'content': [
              {'type': 'text', 'text': 'Done.'},
            ],
          },
        );
      });

      final provider = AnthropicProvider(
        config: const AnthropicConfig(apiKey: 'test-key'),
        dio: dio,
      );
      final result = await provider.chatWithTools(_request());

      expect(result.text, equals('Done.'));
      expect(result.stopReason, equals(AgentTurnStopReason.stop));
      final tools = captured!['tools'] as List;
      final tool = tools.single as Map;
      // Verified: strict is a top-level tool property.
      expect(tool['strict'], isTrue);
      expect(tool['name'], equals('trim_clip'));
      expect(tool['input_schema'], isNotNull);
      expect(
        captured!['tool_choice'],
        equals({'type': 'auto', 'disable_parallel_tool_use': true}),
      );
      expect(captured!['max_tokens'], equals(4096));
      expect(captured!['system'], equals('system'));
    });
  });

  group('AnthropicProvider.chatWithTools response parsing', () {
    test('parses tool_use blocks with already-parsed input', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: '/v1/messages'),
                statusCode: 200,
                data: {
                  'stop_reason': 'tool_use',
                  'content': [
                    {'type': 'text', 'text': 'Trimming now.'},
                    {
                      'type': 'tool_use',
                      'id': 'toolu_1',
                      'name': 'trim_clip',
                      'input': {
                        'clip_id': 'clip_1',
                        'start': '00:00:05.000',
                        'end': '00:00:15.000',
                      },
                    },
                  ],
                },
              ));

      final provider = AnthropicProvider(
        config: const AnthropicConfig(apiKey: 'test-key'),
        dio: dio,
      );
      final result = await provider.chatWithTools(_request());

      expect(result.stopReason, equals(AgentTurnStopReason.toolCalls));
      expect(result.text, contains('Trimming now.'));
      expect(result.toolCalls, hasLength(1));
      expect(result.toolCalls.single.id, equals('toolu_1'));
      expect(result.toolCalls.single.args['clip_id'], equals('clip_1'));
    });
  });

  group('AnthropicProvider.chatWithTools history mapping', () {
    test('tool results map to tool_result blocks with is_error', () async {
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
          requestOptions: RequestOptions(path: '/v1/messages'),
          statusCode: 200,
          data: {
            'stop_reason': 'end_turn',
            'content': [
              {'type': 'text', 'text': 'All set.'},
            ],
          },
        );
      });

      final provider = AnthropicProvider(
        config: const AnthropicConfig(apiKey: 'test-key'),
        dio: dio,
      );
      await provider.chatWithTools(_request(history: const [
        AgentTurnMessage(
          role: AgentTurnRole.assistant,
          toolCalls: [
            AgentToolCall(
              id: 'toolu_1',
              name: 'trim_clip',
              args: {'clip_id': 'clip_1'},
            ),
          ],
        ),
        AgentTurnMessage(
          role: AgentTurnRole.toolResult,
          content: '{"output_path":"C:\\out\\op.mp4"}',
          toolCallId: 'toolu_1',
        ),
        AgentTurnMessage(
          role: AgentTurnRole.toolResult,
          content: 'Unknown clip ID "ghost".',
          toolCallId: 'toolu_2',
          toolError: true,
        ),
      ]));

      final messages = captured!['messages'] as List;
      // assistant + 2 tool results + final user
      expect(messages, hasLength(4));
      final assistant = messages[0] as Map;
      expect(assistant['role'], equals('assistant'));
      final blocks = assistant['content'] as List;
      expect(blocks.single['type'], equals('tool_use'));
      final okResult = (messages[1] as Map)['content'] as List;
      expect(okResult.single['type'], equals('tool_result'));
      expect(okResult.single['tool_use_id'], equals('toolu_1'));
      expect(okResult.single['is_error'], isFalse);
      final errResult = (messages[2] as Map)['content'] as List;
      expect(errResult.single['is_error'], isTrue);
      expect(messages.last['role'], equals('user'));
    });
  });

  group('AnthropicProvider capability', () {
    test('supports tool calling', () {
      final provider = AnthropicProvider(
        config: const AnthropicConfig(apiKey: 'test-key'),
      );
      expect(provider.supportsToolCalling, isTrue);
    });

    test('default model is a verified current ID', () {
      expect(const AnthropicConfig().model, equals('claude-sonnet-5'));
    });
  });
}
