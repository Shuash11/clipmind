import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'llm_provider.dart';

class GeminiConfig {
  final String model;
  final String apiKey;

  const GeminiConfig({this.model = 'gemini-3.8-flash', this.apiKey = ''});
}

/// Gemini behind NATIVE `generateContent` function calling.
///
/// Live-verification gate: `FunctionDeclaration`/`FunctionCall` semantics
/// (lowercase JSON-Schema types passed as-is, multiple `FunctionCall`
/// parts per turn, `FunctionResponse` expected after every `FunctionCall`)
/// are doc-verified against the official Gemini Cookbook; the REST-level
/// details — the `tools: [{"functionDeclarations": [...]}]` wrapper shape,
/// the `functionResponse` body shape, and the native `systemInstruction`
/// field — are mock-verified only until a manual live test runs.
/// Conservative field set: `toolConfig` is omitted (AUTO is the documented
/// default with tools present — avoids 400-risk on an unverified field).
class GeminiProvider extends LlmProvider {
  static const _baseUrl = 'https://generativelanguage.googleapis.com';
  static const _models = [
    'gemini-3.8-flash',
    'gemini-3.1-pro-preview',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
    'gemini-2.5-pro',
  ];

  final GeminiConfig config;
  final SecureKeyStore _keyStore;
  late final Dio _dio;
  final StreamController<ConnectionStatus> _connectionCtrl =
      StreamController<ConnectionStatus>.broadcast();
  Timer? _healthTimer;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  String get id => 'gemini:${config.model}';

  /// Counts [chatWithTools] round trips for synthetic function-call ids
  /// (`functionCall` carries no id; ids stay internal to one run).
  int _toolCallTurns = 0;

  GeminiProvider({GeminiConfig? config, SecureKeyStore? keyStore, Dio? dio})
    : config = config ?? const GeminiConfig(),
      _keyStore = keyStore ?? SecureKeyStore() {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        );
  }

  Future<String> _resolveApiKey() async {
    if (config.apiKey.isNotEmpty) return config.apiKey;
    final stored = await _keyStore.readApiKey('gemini');
    if (stored == null || stored.isEmpty) {
      throw ProviderFailure(id, 'Gemini API key not configured');
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
        final responseSchema = _buildResponseSchema(request.schemaJson);

        final body = {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': '${request.systemPrompt}\n\n${request.userCommand}'},
              ],
            },
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'responseSchema': responseSchema,
            'temperature': 0.1,
          },
        };

        final response = await _dio.post<Map<String, dynamic>>(
          '/v1beta/models/${config.model}:generateContent',
          queryParameters: {'key': apiKey},
          data: body,
          options: Options(
            receiveTimeout: Duration(seconds: request.timeoutSeconds),
          ),
        );

        final data = response.data as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;

        if (candidates == null || candidates.isEmpty) {
          throw ProviderFailure(id, 'Empty response from model');
        }

        final candidate = candidates[0] as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;

        if (parts == null || parts.isEmpty) {
          throw ProviderFailure(id, 'No content parts in response');
        }

        final textPart = parts[0] as Map<String, dynamic>;
        final text = textPart['text'] as String?;

        if (text == null || text.trim().isEmpty) {
          throw ProviderFailure(id, 'Empty text in response');
        }

        final cleaned = _cleanJsonResponse(text);
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

  /// One native `generateContent` round trip with `functionDeclarations`
  /// (transport-only, no loop).
  ///
  /// Sends our tool schemas as-is (lowercase JSON-Schema types are
  /// cookbook-verified), `systemInstruction`, and a conservative
  /// `generationConfig` (no `toolConfig`: AUTO is the documented default).
  /// Parses `functionCall` parts into canonical [AgentToolCall]s with
  /// synthetic `fc_<turn>_<n>` ids; `functionResponse` turns are keyed by
  /// the provider-neutral [AgentTurnMessage.toolName].
  @override
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) async {
    const maxRetries = 2;
    var attempt = 0;

    while (true) {
      try {
        final apiKey = await _resolveApiKey();
        final body = {
          'systemInstruction': {
            'parts': [
              {'text': request.systemPrompt},
            ],
          },
          'contents': _toContents(request),
          'tools': [
            {
              'functionDeclarations': [
                for (final tool in request.tools)
                  {
                    'name': tool.name,
                    'description': tool.description,
                    'parameters': tool.inputSchema,
                  },
              ],
            },
          ],
          'generationConfig': {
            'temperature': request.temperature,
            'maxOutputTokens': 4096,
          },
        };

        final response = await _dio.post<Map<String, dynamic>>(
          '/v1beta/models/${config.model}:generateContent',
          queryParameters: {'key': apiKey},
          data: body,
          options: Options(
            receiveTimeout: Duration(seconds: request.timeoutSeconds),
          ),
        );

        _toolCallTurns++;
        return _parseTurnResponse(response.data);
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

  List<Map<String, dynamic>> _toContents(AgentTurnRequest request) {
    final contents = <Map<String, dynamic>>[];
    for (final turn in request.history) {
      contents.add(_turnToContent(turn));
    }
    // Rounds 2+ send empty userContent (the original user turn already
    // lives in history). Valid: round 2+ contents then end with the `user`
    // functionResponse parts, which the protocol requires after calls.
    if (request.userContent.trim().isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': request.userContent},
        ],
      });
    }
    return contents;
  }

  Map<String, dynamic> _turnToContent(AgentTurnMessage turn) {
    switch (turn.role) {
      case AgentTurnRole.user:
        return {
          'role': 'user',
          'parts': [
            {'text': turn.content ?? ''},
          ],
        };
      case AgentTurnRole.assistant:
        final parts = <Map<String, dynamic>>[];
        if (turn.content != null && turn.content!.isNotEmpty) {
          parts.add({'text': turn.content});
        }
        for (final call in turn.toolCalls) {
          parts.add({
            'functionCall': {
              'name': call.name,
              // Args stay objects on the wire (no JSON-string encoding).
              'args': call.args,
            },
          });
        }
        return {
          'role': 'model',
          'parts': parts.isEmpty ? [{'text': ''}] : parts,
        };
      case AgentTurnRole.toolResult:
        return {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                // Keyed by function NAME (functionCall carries no id).
                'name': turn.toolName ?? '',
                'response': _decodeResultPayload(turn.content),
              },
            },
          ],
        };
    }
  }

  /// The agent stores tool results as a JSON object string
  /// (`{success, summary, data, error?}`); pass it back as an object.
  /// Non-JSON content is wrapped so the shape stays an object.
  Map<String, dynamic> _decodeResultPayload(String? content) {
    final raw = content ?? '';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Fall through to the text wrapper below.
    }
    return {'text': raw};
  }

  AgentTurnResult _parseTurnResponse(Map<String, dynamic>? data) {
    final candidates = data?['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw ProviderFailure(id, 'Empty response from model');
    }
    final content =
        (candidates[0] as Map<String, dynamic>)['content']
            as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw ProviderFailure(id, 'No content parts in response');
    }

    final text = StringBuffer();
    final calls = <AgentToolCall>[];
    for (final part in parts) {
      final entry = part as Map<String, dynamic>;
      if (entry.containsKey('functionCall')) {
        final fn =
            entry['functionCall'] as Map<String, dynamic>? ?? {};
        final args = fn['args'];
        if (args != null && args is! Map) {
          throw ProviderFailure(
            id,
            'Invalid function args for "${fn['name']}".',
          );
        }
        calls.add(AgentToolCall(
          id: 'fc_${_toolCallTurns}_${calls.length + 1}',
          name: fn['name'] as String? ?? '',
          args: args == null
              ? const {}
              : Map<String, dynamic>.from(args as Map),
        ));
      } else if (entry['text'] is String) {
        text.writeln(entry['text']);
      }
    }

    return AgentTurnResult(
      text: text.toString().trim(),
      toolCalls: calls,
      stopReason: calls.isNotEmpty
          ? AgentTurnStopReason.toolCalls
          : AgentTurnStopReason.stop,
    );
  }

  Map<String, dynamic> _buildResponseSchema(String schemaJson) {
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
        if (status == 400) return 'Bad request: ${e.response?.data}';
        if (status == 403) return 'API key not authorized';
        if (status == 429) return 'Rate limited. Please try again.';
        return 'Server error: $status';
      case DioExceptionType.connectionError:
        return 'Cannot connect to Gemini API';
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
        '/v1beta/models/${config.model}:generateContent',
        queryParameters: {'key': apiKey},
        data: {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': 'test'},
              ],
            },
          ],
          'generationConfig': {'maxOutputTokens': 1},
        },
        options: Options(receiveTimeout: const Duration(seconds: 5)),
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

