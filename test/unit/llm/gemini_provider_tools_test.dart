import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/data/services/llm/gemini_provider.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';

class _MockDio extends Mock implements Dio {}

class _MockKeyStore extends Mock implements SecureKeyStore {}

const _schema = {
  'type': 'object',
  'properties': {
    'clip_id': {'type': 'string'},
  },
  'required': ['clip_id'],
  'additionalProperties': false,
};

AgentTurnRequest _request({List<AgentTurnMessage> history = const []}) {
  return AgentTurnRequest(
    systemPrompt: 'system',
    userContent: 'Trim the first 5 seconds',
    tools: [
      const ToolDefinition(
        name: 'trim_clip',
        description: 'Trim a clip.',
        inputSchema: _schema,
        category: ToolCategory.edit,
      ),
    ],
    history: history,
  );
}

GeminiProvider _provider(_MockDio dio) {
  final keys = _MockKeyStore();
  when(() => keys.readApiKey(any())).thenAnswer((_) async => 'gem-key');
  return GeminiProvider(
    config: const GeminiConfig(),
    keyStore: keys,
    dio: dio,
  );
}

Response<Map<String, dynamic>> _partsResponse(
  List<Map<String, dynamic>> parts,
) {
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/v1beta/models'),
    statusCode: 200,
    data: {
      'candidates': [
        {
          'finishReason': 'STOP',
          'content': {'role': 'model', 'parts': parts},
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

  group('GeminiProvider.chatWithTools request shape', () {
    test('hits generateContent with ?key= and native body', () async {
      final dio = _MockDio();
      Map<String, dynamic>? captured;
      String? capturedPath;
      Map<String, dynamic>? capturedQuery;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        capturedPath = invocation.positionalArguments.first as String;
        captured = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        capturedQuery = Map<String, dynamic>.from(
          invocation.namedArguments[#queryParameters] as Map,
        );
        return _partsResponse([
          {'text': 'Done.'},
        ]);
      });

      final provider = _provider(dio);
      expect(provider.supportsToolCalling, isTrue);

      final result = await provider.chatWithTools(_request());

      expect(result.text, equals('Done.'));
      expect(result.stopReason, equals(AgentTurnStopReason.stop));
      expect(
        capturedPath,
        equals('/v1beta/models/gemini-3.8-flash:generateContent'),
      );
      expect(capturedQuery?['key'], equals('gem-key'));
      // Native system instruction.
      final instruction =
          captured!['systemInstruction'] as Map<String, dynamic>;
      expect(
        (instruction['parts'] as List).single['text'],
        equals('system'),
      );
      // Function declarations carry our schema as-is (lowercase types).
      final tools = captured!['tools'] as List;
      final decls =
          (tools.single as Map)['functionDeclarations'] as List;
      expect((decls.single as Map)['name'], equals('trim_clip'));
      expect(
        (decls.single as Map)['parameters'],
        equals(_schema),
      );
      // Conservative field set: no toolConfig (AUTO is the default).
      expect(captured!.containsKey('toolConfig'), isFalse);
      final generationConfig =
          captured!['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['temperature'], equals(0.1));
      expect(generationConfig['maxOutputTokens'], equals(4096));
      // Round 1 contents: single user turn.
      final contents = captured!['contents'] as List;
      expect(contents, hasLength(1));
      expect((contents.single as Map)['role'], equals('user'));
    });
  });

  group('GeminiProvider.chatWithTools contents mapping', () {
    test('model functionCall uses object args; response keyed by name',
        () async {
      final dio = _MockDio();
      Map<String, dynamic>? captured;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        captured = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        return _partsResponse([
          {'text': 'All set.'},
        ]);
      });

      await _provider(dio).chatWithTools(_request(history: const [
        AgentTurnMessage(
          role: AgentTurnRole.assistant,
          toolCalls: [
            AgentToolCall(
              id: 'fc_1_1',
              name: 'trim_clip',
              args: {'clip_id': 'clip_1'},
            ),
          ],
        ),
        AgentTurnMessage(
          role: AgentTurnRole.toolResult,
          content: '{"success":true,"summary":"ok","data":{}}',
          toolCallId: 'fc_1_1',
          toolName: 'trim_clip',
        ),
      ]));

      final contents = captured!['contents'] as List;
      // system lives in systemInstruction; contents: model + user + user.
      expect(contents, hasLength(3));
      final model = contents[0] as Map;
      expect(model['role'], equals('model'));
      final modelParts = model['parts'] as List;
      final fnCall =
          (modelParts.single as Map)['functionCall'] as Map;
      expect(fnCall['name'], equals('trim_clip'));
      // Args stay objects on the wire (no JSON-string encoding).
      expect(fnCall['args'], equals({'clip_id': 'clip_1'}));
      final response = contents[1] as Map;
      expect(response['role'], equals('user'));
      final fnResponse =
          ((response['parts'] as List).single as Map)['functionResponse']
              as Map;
      expect(fnResponse['name'], equals('trim_clip'));
      expect(
        fnResponse['response'],
        equals(<String, dynamic>{
          'success': true,
          'summary': 'ok',
          'data': <String, dynamic>{},
        }),
      );
      expect((contents[2] as Map)['role'], equals('user'));
    });

    test('round-2 request omits the trailing user message', () async {
      final dio = _MockDio();
      Map<String, dynamic>? captured;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        captured = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        return _partsResponse([
          {'text': 'Done.'},
        ]);
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
                id: 'fc_1_1',
                name: 'trim_clip',
                args: {'clip_id': 'clip_1'},
              ),
            ],
          ),
          AgentTurnMessage(
            role: AgentTurnRole.toolResult,
            content: '{"success":true}',
            toolCallId: 'fc_1_1',
            toolName: 'trim_clip',
          ),
        ],
      ));

      final contents = captured!['contents'] as List;
      // user + model + user(functionResponse): no trailing user text.
      expect(contents, hasLength(3));
      expect((contents[0] as Map)['role'], equals('user'));
      expect(
        ((contents[0] as Map)['parts'] as List).single['text'],
        contains('Trim the first 5 seconds'),
      );
      final last = contents.last as Map;
      expect(last['role'], equals('user'));
      expect(
        ((last['parts'] as List).single as Map).containsKey(
          'functionResponse',
        ),
        isTrue,
      );
    });
  });

  group('GeminiProvider.chatWithTools response parsing', () {
    test('functionCall parts become calls with synthetic ids', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _partsResponse([
                {'text': 'Trimming now.'},
                {
                  'functionCall': {
                    'name': 'trim_clip',
                    'args': {'clip_id': 'clip_1'},
                  },
                },
                {
                  'functionCall': {
                    'name': 'mute_clip',
                    'args': {'clip_id': 'clip_1'},
                  },
                },
              ]));

      final result = await _provider(dio).chatWithTools(_request());

      expect(result.stopReason, equals(AgentTurnStopReason.toolCalls));
      expect(result.text, equals('Trimming now.'));
      expect(result.toolCalls, hasLength(2));
      expect(result.toolCalls[0].id, equals('fc_1_1'));
      expect(result.toolCalls[1].id, equals('fc_1_2'));
      expect(result.toolCalls[0].name, equals('trim_clip'));
      expect(
        result.toolCalls[0].args,
        equals({'clip_id': 'clip_1'}),
      );
      expect(result.toolCalls[1].name, equals('mute_clip'));
    });

    test('no function calls means a text turn', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _partsResponse([
                {'text': 'Nothing to do.'},
              ]));

      final result = await _provider(dio).chatWithTools(_request());

      expect(result.stopReason, equals(AgentTurnStopReason.stop));
      expect(result.toolCalls, isEmpty);
      expect(result.text, equals('Nothing to do.'));
    });

    test('invalid function args fail actionably', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _partsResponse([
                {
                  'functionCall': {
                    'name': 'trim_clip',
                    'args': 'not-an-object',
                  },
                },
              ]));

      expect(
        () => _provider(dio).chatWithTools(_request()),
        throwsA(isA<ProviderFailure>().having(
          (f) => f.message,
          'message',
          contains('Invalid function args'),
        )),
      );
    });
  });

  group('GeminiProvider.chatWithTools errors', () {
    test('403 maps to unauthorized key', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
            requestOptions: RequestOptions(path: '/v1beta/models'),
            type: DioExceptionType.badResponse,
            response: Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: '/v1beta/models'),
              statusCode: 403,
            ),
          ));

      expect(
        () => _provider(dio).chatWithTools(_request()),
        throwsA(isA<ProviderFailure>().having(
          (f) => f.message,
          'message',
          contains('API key not authorized'),
        )),
      );
    });

    test('429 maps to rate-limited text', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
            requestOptions: RequestOptions(path: '/v1beta/models'),
            type: DioExceptionType.badResponse,
            response: Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: '/v1beta/models'),
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

    test('connection failure names the Gemini endpoint', () async {
      final dio = _MockDio();
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
            requestOptions: RequestOptions(path: '/v1beta/models'),
            type: DioExceptionType.connectionError,
          ));

      expect(
        () => _provider(dio).chatWithTools(_request()),
        throwsA(isA<ProviderFailure>().having(
          (f) => f.message,
          'message',
          contains('Cannot connect to Gemini API'),
        )),
      );
    });
  });

  group('GeminiProvider model catalog', () {
    test('default model is in the verified catalog', () async {
      final dio = _MockDio();
      final provider = _provider(dio);
      final models = await provider.availableModels();
      expect(provider.id, equals('gemini:gemini-3.8-flash'));
      expect(models, contains('gemini-3.8-flash'));
    });

    test('no stale model IDs remain', () async {
      final dio = _MockDio();
      final models = await _provider(dio).availableModels();
      expect(models, isNot(contains('gemini-2.0-flash')));
      expect(models, isNot(contains('gemini-2.0-flash-lite')));
      expect(models, isNot(contains('gemini-1.5-pro')));
      expect(
        models,
        containsAll([
          'gemini-3.1-pro-preview',
          'gemini-3.7-flash',
          'gemini-3.6-flash',
          'gemini-3.5-flash-lite',
          'gemini-2.5-pro',
        ]),
      );
    });
  });
}
