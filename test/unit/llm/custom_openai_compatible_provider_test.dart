import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/services/llm/custom_openai_compatible_provider.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';

const _endpoint = 'https://openrouter.ai/api/v1';

/// Real Dio that never hits the network: captures the fully-resolved
/// request and answers from [respond].
Dio _interceptingDio({
  required void Function(RequestOptions options) capture,
  required Response<dynamic> Function(RequestOptions options) respond,
}) {
  // Trailing-slash base mirrors the provider's default Dio: Dio
  // concatenates a relative path with no separator inserted.
  final dio = Dio(BaseOptions(baseUrl: '$_endpoint/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        capture(options);
        handler.resolve(respond(options));
      },
    ),
  );
  return dio;
}

Response<dynamic> _toolCallsResponse() {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/'),
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
                  'arguments': jsonEncode({'clip_id': 'clip_1'}),
                },
              },
            ],
          },
        },
      ],
    },
  );
}

AgentTurnRequest _request() {
  return const AgentTurnRequest(
    systemPrompt: 'system',
    userContent: 'Trim the first 5 seconds',
    tools: [
      ToolDefinition(
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
  );
}

void main() {
  group('CustomOpenAiCompatibleProvider.chatWithTools', () {
    test('posts to {endpoint}/chat/completions (never /v1/v1/…)', () async {
      RequestOptions? captured;
      final dio = _interceptingDio(
        capture: (options) => captured = options,
        respond: (_) => _toolCallsResponse(),
      );
      final provider = CustomOpenAiCompatibleProvider(
        config: CustomOpenAiConfig(
          endpoint: Uri.parse(_endpoint),
          model: 'openai/gpt-oss-120b',
        ),
        dio: dio,
      );

      final result = await provider.chatWithTools(_request());

      // Dio joins the relative path onto the versioned base — the full
      // URL keeps the /api prefix a path-absolute post would drop.
      expect(
        captured!.uri.toString(),
        equals('https://openrouter.ai/api/v1/chat/completions'),
      );
      expect(result.toolCalls.single.name, equals('trim_clip'));
      expect(
        result.toolCalls.single.args,
        equals({'clip_id': 'clip_1'}),
      );
      expect(
        result.stopReason,
        equals(AgentTurnStopReason.toolCalls),
      );
      provider.dispose();
    });

    test('sends model, strict tools and conservative extras only', () async {
      Map<String, dynamic>? body;
      final dio = _interceptingDio(
        capture: (options) =>
            body = Map<String, dynamic>.from(options.data as Map),
        respond: (_) => _toolCallsResponse(),
      );
      final provider = CustomOpenAiCompatibleProvider(
        config: CustomOpenAiConfig(
          endpoint: Uri.parse(_endpoint),
          model: 'openai/gpt-oss-120b',
          apiKey: 'sk-test',
        ),
        dio: dio,
      );

      await provider.chatWithTools(_request());

      expect(body!['model'], equals('openai/gpt-oss-120b'));
      final tools = body!['tools'] as List;
      expect(tools.single['type'], equals('function'));
      expect(tools.single['function']['strict'], isTrue);
      expect(body!['max_tokens'], equals(4096));
      expect(body!.containsKey('max_completion_tokens'), isFalse);
      expect(body!.containsKey('parallel_tool_calls'), isFalse);
      provider.dispose();
    });

    test('no auth header when keyless', () async {
      RequestOptions? captured;
      final dio = _interceptingDio(
        capture: (options) => captured = options,
        respond: (_) => _toolCallsResponse(),
      );
      final provider = CustomOpenAiCompatibleProvider(
        config: CustomOpenAiConfig(
          endpoint: Uri.parse(_endpoint),
          model: 'm',
        ),
        dio: dio,
      );

      expect(await provider.resolveApiKey(), isNull);
      await provider.chatWithTools(_request());

      expect(
        captured!.headers.containsKey('Authorization'),
        isFalse,
      );
      provider.dispose();
    });

    test('default Dio base keeps one trailing slash', () async {
      final provider = CustomOpenAiCompatibleProvider(
        config: CustomOpenAiConfig(
          endpoint: Uri.parse('https://openrouter.ai/api/v1/'),
          model: 'm',
        ),
      );

      expect(
        provider.dio.options.baseUrl,
        equals('https://openrouter.ai/api/v1/'),
      );
      expect(provider.baseUrl, equals('https://openrouter.ai/api/v1/'));
      provider.dispose();
    });

    test('contract: id, models, timeout, capability', () async {
      final provider = CustomOpenAiCompatibleProvider(
        config: CustomOpenAiConfig(
          endpoint: Uri.parse(_endpoint),
          model: 'openai/gpt-oss-120b',
        ),
        dio: _interceptingDio(
          capture: (_) {},
          respond: (_) => _toolCallsResponse(),
        ),
      );

      expect(provider.id, equals('custom:openai/gpt-oss-120b'));
      expect(provider.modelName, equals('openai/gpt-oss-120b'));
      expect(provider.supportsToolCalling, isTrue);
      expect(provider.suggestedRoundTimeoutSeconds, equals(120));
      expect(
        await provider.availableModels(),
        equals(['openai/gpt-oss-120b']),
      );
      provider.dispose();
    });

    test('parseCommand is explicitly unavailable', () async {
      final provider = CustomOpenAiCompatibleProvider(
        config: CustomOpenAiConfig(
          endpoint: Uri.parse(_endpoint),
          model: 'm',
        ),
        dio: _interceptingDio(
          capture: (_) {},
          respond: (_) => _toolCallsResponse(),
        ),
      );

      expect(
        () => provider.parseCommand(
          const AgentRequest(
            systemPrompt: 's',
            userCommand: 'u',
            schemaJson: '{}',
            timeoutSeconds: 60,
          ),
        ),
        throwsA(
          isA<ProviderFailure>().having(
            (f) => f.message,
            'message',
            contains('Legacy one-shot planning is unavailable'),
          ),
        ),
      );
      provider.dispose();
    });
  });

  group('CustomOpenAiCompatibleProvider.watchConnection', () {
    test('any HTTP response counts as connected (even 404)', () async {
      final dio = Dio(BaseOptions(baseUrl: _endpoint));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 404,
              data: {'error': 'not found'},
            ),
          ),
        ),
      );
      final provider = CustomOpenAiCompatibleProvider(
        config: CustomOpenAiConfig(
          endpoint: Uri.parse(_endpoint),
          model: 'm',
        ),
        dio: dio,
      );

      final events = <ConnectionStatus>[];
      final sub = provider.watchConnection().listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      provider.dispose();

      expect(events, contains(ConnectionStatus.connected));
    });

    test('transport failure moves a live provider to disconnected',
        () async {
      final dio = Dio(BaseOptions(baseUrl: _endpoint));
      var fail = false;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (fail) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionTimeout,
                ),
              );
            } else {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': <dynamic>[],
                  },
                ),
              );
            }
          },
        ),
      );
      final provider = CustomOpenAiCompatibleProvider(
        config: CustomOpenAiConfig(
          endpoint: Uri.parse(_endpoint),
          model: 'm',
        ),
        dio: dio,
      );

      // Prime to connected, then fail the transport and re-check.
      final events = <ConnectionStatus>[];
      var sub = provider.watchConnection().listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(events, contains(ConnectionStatus.connected));

      fail = true;
      sub = provider.watchConnection().listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      provider.dispose();

      expect(events, contains(ConnectionStatus.disconnected));
    });
  });
}
