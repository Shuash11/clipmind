import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'llm_provider.dart';

class AnthropicConfig {
  final String model;
  final String apiKey;

  const AnthropicConfig({
    this.model = 'claude-sonnet-5',
    this.apiKey = '',
  });
}

class AnthropicProvider extends LlmProvider {
  static const _baseUrl = 'https://api.anthropic.com';
  static const _apiVersion = '2023-06-01';
  static const _models = [
    'claude-sonnet-5',
    'claude-opus-5',
    'claude-haiku-4-5',
  ];

  final AnthropicConfig config;
  final SecureKeyStore _keyStore;
  late final Dio _dio;
  final StreamController<ConnectionStatus> _connectionCtrl =
      StreamController<ConnectionStatus>.broadcast();
  Timer? _healthTimer;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  String get id => 'anthropic:${config.model}';

  AnthropicProvider({AnthropicConfig? config, SecureKeyStore? keyStore, Dio? dio})
    : config = config ?? const AnthropicConfig(),
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
              'x-api-key': config?.apiKey ?? '',
              'anthropic-version': _apiVersion,
            },
          ),
        );
  }

  Future<String> _resolveApiKey() async {
    if (config.apiKey.isNotEmpty) return config.apiKey;
    final stored = await _keyStore.readApiKey('anthropic');
    if (stored == null || stored.isEmpty) {
      throw ProviderFailure(id, 'Anthropic API key not configured');
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
        final schema = _buildSchema(request.schemaJson);

        final messages = [
          {
            'role': 'user',
            'content': '${request.systemPrompt}\n\n${request.userCommand}',
          },
        ];

        final body = {
          'model': config.model,
          'max_tokens': 4096,
          'messages': messages,
          'tools': [
            {
              'name': 'output',
              'description': 'Structured edit operations output',
              'input_schema': schema,
            },
          ],
          'tool_choice': {'type': 'tool', 'name': 'output'},
        };

        final response = await _dio.post<Map<String, dynamic>>(
          '/v1/messages',
          data: body,
          options: Options(
            receiveTimeout: Duration(seconds: request.timeoutSeconds),
            headers: {'x-api-key': apiKey},
          ),
        );

        final data = response.data as Map<String, dynamic>;
        final content = data['content'] as List<dynamic>?;

        if (content == null || content.isEmpty) {
          throw ProviderFailure(id, 'Empty response from model');
        }

        Map<String, dynamic>? parsedOutput;

        for (final block in content) {
          final blockMap = block as Map<String, dynamic>;
          if (blockMap['type'] == 'tool_use' && blockMap['name'] == 'output') {
            parsedOutput = blockMap['input'] as Map<String, dynamic>?;
            break;
          }
        }

        if (parsedOutput == null) {
          final textContent = content
              .where((b) => (b as Map<String, dynamic>)['type'] == 'text')
              .map((b) => (b as Map<String, dynamic>)['text'] as String? ?? '')
              .join('\n');
          if (textContent.trim().isNotEmpty) {
            final cleaned = _cleanJsonResponse(textContent);
            parsedOutput = jsonDecode(cleaned) as Map<String, dynamic>;
          }
        }

        if (parsedOutput == null) {
          throw ProviderFailure(id, 'No valid output found in response');
        }

        return EditOperationSet.fromJson(parsedOutput);
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

  /// One Messages API round trip with tools (transport-only, D1).
  ///
  /// Sends `strict: true` tool definitions (top-level, per the strict
  /// tool use docs) with `tool_choice: {auto, disable_parallel_tool_use}`.
  /// Parses `tool_use` blocks (`input` is already-parsed JSON) and maps
  /// history including `tool_result` / `is_error`.
  @override
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) async {
    try {
      final apiKey = await _resolveApiKey();
      final body = {
        'model': config.model,
        'max_tokens': 4096,
        'system': request.systemPrompt,
        'messages': _toWireMessages(request),
        'tools': [
          for (final tool in request.tools)
            {
              'name': tool.name,
              'description': tool.description,
              'input_schema': tool.inputSchema,
              'strict': true,
            },
        ],
        'tool_choice': {
          'type': 'auto',
          'disable_parallel_tool_use': true,
        },
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/messages',
        data: body,
        options: Options(
          receiveTimeout: Duration(seconds: request.timeoutSeconds),
          headers: {'x-api-key': apiKey},
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
    final messages = <Map<String, dynamic>>[];
    for (final turn in request.history) {
      messages.add(_turnToWire(turn));
    }
    // Rounds 2+ send empty userContent (the original user turn already
    // lives in history). Omitting keeps the trailing `tool_result`
    // user message last, which the protocol requires after tool calls.
    if (request.userContent.trim().isNotEmpty) {
      messages.add({
        'role': 'user',
        'content': request.userContent,
      });
    }
    return messages;
  }

  Map<String, dynamic> _turnToWire(AgentTurnMessage turn) {
    switch (turn.role) {
      case AgentTurnRole.user:
        return {'role': 'user', 'content': turn.content ?? ''};
      case AgentTurnRole.assistant:
        if (turn.toolCalls.isEmpty) {
          return {'role': 'assistant', 'content': turn.content ?? ''};
        }
        return {
          'role': 'assistant',
          'content': [
            if (turn.content != null && turn.content!.isNotEmpty)
              {'type': 'text', 'text': turn.content},
            for (final call in turn.toolCalls)
              {
                'type': 'tool_use',
                'id': call.id,
                'name': call.name,
                'input': call.args,
              },
          ],
        };
      case AgentTurnRole.toolResult:
        return {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': turn.toolCallId ?? '',
              // String content keeps Windows paths intact on the wire.
              'content': turn.content ?? '',
              'is_error': turn.toolError,
            },
          ],
        };
    }
  }

  AgentTurnResult _parseTurnResponse(Map<String, dynamic>? data) {
    final content = data?['content'] as List<dynamic>?;
    if (content == null || content.isEmpty) {
      throw ProviderFailure(id, 'Empty response from model');
    }
    final stopReason = data?['stop_reason'] as String?;

    final text = StringBuffer();
    final calls = <AgentToolCall>[];
    for (final block in content) {
      final entry = block as Map<String, dynamic>;
      switch (entry['type']) {
        case 'text':
          text.writeln(entry['text'] as String? ?? '');
          break;
        case 'tool_use':
          final input = entry['input'];
          if (input is! Map) {
            throw ProviderFailure(
              id,
              'Invalid tool input for "${entry['name']}".',
            );
          }
          calls.add(AgentToolCall(
            id: entry['id'] as String? ?? '',
            name: entry['name'] as String? ?? '',
            args: Map<String, dynamic>.from(input),
          ));
          break;
        default:
          break;
      }
    }

    return AgentTurnResult(
      text: text.toString().trim(),
      toolCalls: calls,
      stopReason: stopReason == 'tool_use' && calls.isNotEmpty
          ? AgentTurnStopReason.toolCalls
          : AgentTurnStopReason.stop,
    );
  }

  Map<String, dynamic> _buildSchema(String schemaJson) {
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
          'clarification_needed': {'type': 'string'},
        },
        'required': ['operations', 'summary'],
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
          'clarification_needed': {'type': 'string'},
        },
        'required': ['operations', 'summary'],
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
        if (status == 400) return 'Bad request: ${e.response?.data}';
        return 'Server error: $status';
      case DioExceptionType.connectionError:
        return 'Cannot connect to Anthropic API';
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
      await _dio.post<Map<String, dynamic>>(
        '/v1/messages',
        data: {
          'model': config.model,
          'max_tokens': 1,
          'messages': [
            {'role': 'user', 'content': 'test'},
          ],
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          headers: {'x-api-key': apiKey},
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

