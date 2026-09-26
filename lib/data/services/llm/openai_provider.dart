import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'llm_provider.dart';

class OpenAiConfig {
  final String model;
  final String apiKey;

  const OpenAiConfig({this.model = 'gpt-4o', this.apiKey = ''});
}

class OpenAiProvider extends LlmProvider {
  static const _baseUrl = 'https://api.openai.com';
  static const _models = [
    'gpt-5.5',
    'gpt-5.4',
    'gpt-5.4-mini',
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
  ];

  final OpenAiConfig config;
  final SecureKeyStore _keyStore;
  late final Dio _dio;
  final StreamController<ConnectionStatus> _connectionCtrl =
      StreamController<ConnectionStatus>.broadcast();
  Timer? _healthTimer;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  String get id => 'openai:${config.model}';

  OpenAiProvider({OpenAiConfig? config, SecureKeyStore? keyStore, Dio? dio})
    : config = config ?? const OpenAiConfig(),
      _keyStore = keyStore ?? SecureKeyStore() {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config?.apiKey ?? ''}',
            },
          ),
        );
  }

  Future<String> _resolveApiKey() async {
    if (config.apiKey.isNotEmpty) return config.apiKey;
    final stored = await _keyStore.readApiKey('openai');
    if (stored == null || stored.isEmpty) {
      throw ProviderFailure(id, 'OpenAI API key not configured');
    }
    return stored;
  }

  @override
  Future<List<String>> availableModels() async {
    return _models;
  }

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) async {
    const maxRetries = 2;
    var attempt = 0;

    while (true) {
      try {
        final apiKey = await _resolveApiKey();
        final schema = _buildStructuredOutputSchema(request.schemaJson);

        final messages = [
          {'role': 'system', 'content': request.systemPrompt},
          {'role': 'user', 'content': request.userCommand},
        ];

        final body = {
          'model': config.model,
          'messages': messages,
          'response_format': {
            'type': 'json_schema',
            'json_schema': {'name': 'clipmind_ops', 'schema': schema},
          },
          'temperature': 0.1,
        };

        final response = await _dio.post<Map<String, dynamic>>(
          '/v1/chat/completions',
          data: body,
          options: Options(
            receiveTimeout: Duration(seconds: request.timeoutSeconds),
            headers: {'Authorization': 'Bearer $apiKey'},
          ),
        );

        final data = response.data as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;

        if (choices == null || choices.isEmpty) {
          throw ProviderFailure(id, 'Empty response from model');
        }

        final message = choices[0] as Map<String, dynamic>;
        final content = message['message']?['content'] as String?;

        if (content == null || content.trim().isEmpty) {
          throw ProviderFailure(id, 'Empty content in response');
        }

        final cleaned = _cleanJsonResponse(content);
        final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
        return EditOperationSet.fromJson(parsed);
      } on DioException catch (e) {
        if (_isTransientError(e) && attempt < maxRetries) {
          attempt++;
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        throw ProviderFailure(id, _formatDioError(e), e);
      } on FormatException catch (e) {
        throw ProviderFailure(id, 'Failed to parse response: ${e.message}');
      } on ProviderFailure {
        rethrow;
      } catch (e) {
        throw ProviderFailure(id, 'Unexpected error: $e');
      }
    }
  }

  @override
  bool get supportsToolCalling => true;

  /// One Chat Completions round trip with tools (transport-only, D1).
  ///
  /// Sends `strict: true` function tools with `tool_choice: auto`,
  /// `parallel_tool_calls: false` and `max_completion_tokens`. Parses
  /// `tool_calls` (JSON-string `arguments`) into canonical [AgentToolCall]s.
  @override
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) async {
    try {
      final apiKey = await _resolveApiKey();
      final body = {
        'model': config.model,
        'messages': _toWireMessages(request),
        'tools': [
          for (final tool in request.tools)
            {
              'type': 'function',
              'function': {
                'name': tool.name,
                'description': tool.description,
                'parameters': tool.inputSchema,
                'strict': true,
              },
            },
        ],
        'tool_choice': {'type': 'auto'},
        'parallel_tool_calls': false,
        'max_completion_tokens': 4096,
        'temperature': request.temperature,
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/chat/completions',
        data: body,
        options: Options(
          receiveTimeout: Duration(seconds: request.timeoutSeconds),
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      return _parseTurnResponse(response.data);
    } on DioException catch (e) {
      throw ProviderFailure(id, _formatDioError(e), e);
    } on FormatException catch (e) {
      throw ProviderFailure(id, 'Failed to parse response: ${e.message}');
    } on ProviderFailure {
      rethrow;
    } catch (e) {
      throw ProviderFailure(id, 'Unexpected error: $e');
    }
  }

  List<Map<String, dynamic>> _toWireMessages(AgentTurnRequest request) {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': request.systemPrompt},
    ];
    for (final turn in request.history) {
      messages.add(_turnToWire(turn));
    }
    // Rounds 2+ send empty userContent (the original user turn already
    // lives in history). Omitting keeps the trailing `tool` message last,
    // which the protocol requires after tool calls.
    if (request.userContent.trim().isNotEmpty) {
      messages.add({'role': 'user', 'content': request.userContent});
    }
    return messages;
  }

  Map<String, dynamic> _turnToWire(AgentTurnMessage turn) {
    switch (turn.role) {
      case AgentTurnRole.user:
        return {'role': 'user', 'content': turn.content ?? ''};
      case AgentTurnRole.assistant:
        return {
          'role': 'assistant',
          'content': turn.content,
          if (turn.toolCalls.isNotEmpty)
            'tool_calls': [
              for (final call in turn.toolCalls)
                {
                  'id': call.id,
                  'type': 'function',
                  'function': {
                    'name': call.name,
                    // jsonEncode handles Windows backslashes and quotes.
                    'arguments': jsonEncode(call.args),
                  },
                },
            ],
        };
      case AgentTurnRole.toolResult:
        return {
          'role': 'tool',
          'tool_call_id': turn.toolCallId ?? '',
          // jsonEncode keeps model-provided strings intact on the wire.
          'content': turn.content ?? '',
        };
    }
  }

  AgentTurnResult _parseTurnResponse(Map<String, dynamic>? data) {
    final choices = data?['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw ProviderFailure(id, 'Empty response from model');
    }
    final message = (choices[0] as Map<String, dynamic>)['message']
        as Map<String, dynamic>?;
    if (message == null) {
      throw ProviderFailure(id, 'Empty message in response');
    }
    final finishReason =
        (choices[0] as Map<String, dynamic>)['finish_reason'] as String?;

    final calls = <AgentToolCall>[];
    final rawCalls = message['tool_calls'] as List<dynamic>?;
    if (rawCalls != null) {
      for (final raw in rawCalls) {
        final entry = raw as Map<String, dynamic>;
        final function = entry['function'] as Map<String, dynamic>? ?? {};
        final argsJson = function['arguments'] as String? ?? '{}';
        Map<String, dynamic> args;
        try {
          args = Map<String, dynamic>.from(
            jsonDecode(argsJson) as Map,
          );
        } on FormatException {
          throw ProviderFailure(
            id,
            'Invalid tool arguments JSON for "${function['name']}".',
          );
        }
        calls.add(AgentToolCall(
          id: entry['id'] as String? ?? '',
          name: function['name'] as String? ?? '',
          args: args,
        ));
      }
    }

    return AgentTurnResult(
      text: message['content'] as String? ?? '',
      toolCalls: calls,
      stopReason: finishReason == 'tool_calls'
          ? AgentTurnStopReason.toolCalls
          : AgentTurnStopReason.stop,
    );
  }

  Map<String, dynamic> _buildStructuredOutputSchema(String schemaJson) {
    try {
      final parsed = jsonDecode(schemaJson) as Map<String, dynamic>;
      return {
        'type': 'object',
        'properties': {
          'operations': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': parsed,
              'required': ['id', 'type', 'target_clip_id', 'params'],
            },
          },
          'summary': {'type': 'string'},
          'clarification_needed': {
            'type': 'string',
            'description': 'Set to a question if clarification is needed',
          },
        },
        'required': ['operations', 'summary'],
        'additionalProperties': false,
      };
    } catch (_) {
      return {
        'type': 'object',
        'properties': {
          'operations': {
            'type': 'array',
            'items': {'type': 'object'},
          },
          'summary': {'type': 'string'},
        },
        'required': ['operations', 'summary'],
        'additionalProperties': false,
      };
    }
  }

  String _cleanJsonResponse(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }

  bool _isTransientError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        return code == 429 || code >= 500;
      default:
        return false;
    }
  }

  String _formatDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 401) return 'Invalid API key';
        if (status == 429) return 'Rate limited. Please try again.';
        return 'Server error: $status';
      case DioExceptionType.connectionError:
        return 'Cannot connect to OpenAI API';
      default:
        return 'Network error: ${e.message}';
    }
  }

  @override
  Stream<ConnectionStatus> watchConnection() {
    _checkHealth();
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkHealth(),
    );
    return _connectionCtrl.stream;
  }

  Future<void> _checkHealth() async {
    _connectionCtrl.add(ConnectionStatus.connecting);
    try {
      final apiKey = await _resolveApiKey();
      await _dio.get<Map<String, dynamic>>(
        '/v1/models',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );
      if (_status != ConnectionStatus.connected) {
        _status = ConnectionStatus.connected;
        _connectionCtrl.add(ConnectionStatus.connected);
      }
    } catch (_) {
      if (_status != ConnectionStatus.disconnected) {
        _status = ConnectionStatus.disconnected;
        _connectionCtrl.add(ConnectionStatus.disconnected);
      }
    }
  }

  void dispose() {
    _healthTimer?.cancel();
    _connectionCtrl.close();
  }
}

