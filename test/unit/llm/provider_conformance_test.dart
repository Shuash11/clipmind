import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/data/services/llm/anthropic_provider.dart';
import 'package:clipmind/data/services/llm/custom_openai_compatible_provider.dart';
import 'package:clipmind/data/services/llm/gemini_provider.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/llm/nvidia_nim_provider.dart';
import 'package:clipmind/data/services/llm/ollama_provider.dart';
import 'package:clipmind/data/services/llm/openai_provider.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';

/// Cross-provider drift guard: every tool-capable provider runs the same
/// agentic turn contract, and every OpenAI-compatible transport speaks
/// the same wire shape.
///
/// The per-provider files (`*_provider_tools_test.dart`) hold
/// provider-specific depth and stay untouched; this suite only pins the
/// shared surface so a change to one provider cannot silently drift.

class _MockDio extends Mock implements Dio {}

class _MockKeyStore extends Mock implements SecureKeyStore {}

class _Captured {
  String? path;
  Map<String, dynamic>? body;
  Map<String, dynamic>? headers;
}

_MockKeyStore _nullKeys() {
  final keys = _MockKeyStore();
  when(() => keys.readApiKey(any())).thenAnswer((_) async => null);
  return keys;
}

_MockDio _scriptedDio(_Captured cap, Map<String, dynamic> response) {
  final dio = _MockDio();
  // Both arities: compat posts (path/data/options) and Gemini posts
  // (path/data/queryParameters/options). Unmatched arities miss the stub
  // and surface as harness errors, never silent wrong-path passes.
  when(() => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenAnswer(
      (invocation) async => _answer(invocation, cap, response));
  when(() => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      )).thenAnswer(
      (invocation) async => _answer(invocation, cap, response));
  return dio;
}

Response<Map<String, dynamic>> _answer(
  Invocation invocation,
  _Captured cap,
  Map<String, dynamic> response,
) {
  cap.path = invocation.positionalArguments.first as String;
  cap.body = Map<String, dynamic>.from(
    invocation.namedArguments[#data] as Map,
  );
  final options = invocation.namedArguments[#options] as Options?;
  cap.headers = Map<String, dynamic>.from(options?.headers ?? {});
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: cap.path!),
    statusCode: 200,
    data: response,
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

Map<String, dynamic> _openAiToolResponse() => {
      'choices': [
        {
          'finish_reason': 'tool_calls',
          'message': {
            'role': 'assistant',
            'content': 'Working.',
            'tool_calls': [
              {
                'id': 'call_1',
                'type': 'function',
                'function': {
                  'name': 'trim_clip',
                  'arguments': '{"clip_id":"clip_1"}',
                },
              },
            ],
          },
        },
      ],
    };

Map<String, dynamic> _anthropicToolResponse() => {
      'stop_reason': 'tool_use',
      'content': [
        {'type': 'text', 'text': 'Working.'},
        {
          'type': 'tool_use',
          'id': 'call_1',
          'name': 'trim_clip',
          'input': {'clip_id': 'clip_1'},
        },
      ],
    };

Map<String, dynamic> _geminiToolResponse() => {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': 'Working.'},
              {
                'functionCall': {
                  'name': 'trim_clip',
                  'args': {'clip_id': 'clip_1'},
                },
              },
            ],
          },
        },
      ],
    };

class _TransportSpec {
  const _TransportSpec({
    required this.path,
    this.auth,
    required this.extras,
    this.absent = const [],
  });

  final String path;
  final String? auth;
  final Map<String, dynamic> extras;
  final List<String> absent;
}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
    registerFallbackValue(Options());
  });

  group('tool-surface conformance (all 6 providers)', () {
    final factories = <String, LlmProvider Function(_MockDio)>{
      'openai': (dio) => OpenAiProvider(
            config: const OpenAiConfig(apiKey: 'k'),
            dio: dio,
          ),
      'anthropic': (dio) => AnthropicProvider(
            config: const AnthropicConfig(apiKey: 'k'),
            dio: dio,
          ),
      'gemini': (dio) => GeminiProvider(
            config: const GeminiConfig(apiKey: 'k'),
            dio: dio,
          ),
      'nvidia_nim': (dio) => NvidiaNimProvider(
            config: const NvidiaNimConfig(apiKey: 'k'),
            dio: dio,
          ),
      'ollama': (dio) => OllamaProvider(
            config: const OllamaConfig(model: 'llama3.1'),
            keyStore: _nullKeys(),
            dio: dio,
          ),
      'custom': (dio) => CustomOpenAiCompatibleProvider(
            config: CustomOpenAiConfig(
              endpoint: Uri.parse('https://example.com/api/v1'),
              model: 'm',
            ),
            dio: dio,
          ),
    };
    final responses = <String, Map<String, dynamic> Function()>{
      'openai': _openAiToolResponse,
      'nvidia_nim': _openAiToolResponse,
      'ollama': _openAiToolResponse,
      'custom': _openAiToolResponse,
      'anthropic': _anthropicToolResponse,
      'gemini': _geminiToolResponse,
    };

    for (final name in factories.keys) {
      test('$name runs one tool turn', () async {
        final cap = _Captured();
        final provider = factories[name]!(
          _scriptedDio(cap, responses[name]!()),
        );

        expect(provider.supportsToolCalling, isTrue,
            reason: name);
        final result = await provider.chatWithTools(_request());

        expect(result.stopReason, equals(AgentTurnStopReason.toolCalls),
            reason: name);
        expect(result.text, contains('Working'), reason: name);
        expect(result.toolCalls, hasLength(1), reason: name);
        expect(result.toolCalls.single.name, equals('trim_clip'),
            reason: name);
        expect(result.toolCalls.single.args['clip_id'], equals('clip_1'),
            reason: name);
      });
    }
  });

  group('OpenAI-compatible transport conformance', () {
    final factories = <String, LlmProvider Function(_MockDio)>{
      'openai': (dio) => OpenAiProvider(
            config: const OpenAiConfig(apiKey: 'k'),
            dio: dio,
          ),
      'nvidia_nim': (dio) => NvidiaNimProvider(
            config: const NvidiaNimConfig(apiKey: 'k'),
            dio: dio,
          ),
      'nvidia': (dio) => NvidiaNimProvider(
            config: const NvidiaNimConfig(apiKey: 'k'),
            dio: dio,
          ),
      'ollama': (dio) => OllamaProvider(
            config: const OllamaConfig(model: 'llama3.1'),
            keyStore: _nullKeys(),
            dio: dio,
          ),
      'custom': (dio) => CustomOpenAiCompatibleProvider(
            config: CustomOpenAiConfig(
              endpoint: Uri.parse('https://example.com/api/v1'),
              model: 'm',
              apiKey: 'k',
            ),
            dio: dio,
          ),
    };
    const specs = {
      'openai': _TransportSpec(
        path: '/v1/chat/completions',
        auth: 'Bearer k',
        extras: {'max_completion_tokens': 4096, 'parallel_tool_calls': false},
      ),
      'nvidia_nim': _TransportSpec(
        path: '/v1/chat/completions',
        auth: 'Bearer k',
        extras: {'max_tokens': 4096},
        absent: ['max_completion_tokens', 'parallel_tool_calls'],
      ),
      'nvidia': _TransportSpec(
        path: '/v1/chat/completions',
        auth: 'Bearer k',
        extras: {'max_tokens': 4096},
        absent: ['max_completion_tokens', 'parallel_tool_calls'],
      ),
      'ollama': _TransportSpec(
        path: '/v1/chat/completions',
        extras: {'max_tokens': 4096},
        absent: ['max_completion_tokens', 'parallel_tool_calls'],
      ),
      'custom': _TransportSpec(
        path: 'chat/completions',
        auth: 'Bearer k',
        extras: {'max_tokens': 4096},
        absent: ['max_completion_tokens', 'parallel_tool_calls'],
      ),
    };

    for (final name in factories.keys) {
      test('$name posts strict tools with provider extras', () async {
        final cap = _Captured();
        final provider = factories[name]!(
          _scriptedDio(cap, _openAiToolResponse()),
        );
        final spec = specs[name]!;

        await provider.chatWithTools(_request());

        expect(cap.path, equals(spec.path), reason: name);
        if (spec.auth == null) {
          expect(cap.headers!.containsKey('Authorization'), isFalse,
              reason: name);
        } else {
          expect(cap.headers!['Authorization'], equals(spec.auth),
              reason: name);
        }
        final tools = cap.body!['tools'] as List;
        expect(tools.single['type'], equals('function'), reason: name);
        expect(tools.single['function']['strict'], isTrue, reason: name);
        expect(cap.body!['tool_choice'], equals({'type': 'auto'}),
            reason: name);
        for (final entry in spec.extras.entries) {
          expect(cap.body![entry.key], equals(entry.value), reason: name);
        }
        for (final key in spec.absent) {
          expect(cap.body!.containsKey(key), isFalse, reason: name);
        }
      });
    }
  });
}
