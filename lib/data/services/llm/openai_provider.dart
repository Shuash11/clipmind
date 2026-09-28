import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'llm_provider.dart';
import 'openai_compatible_provider.dart';

class OpenAiConfig {
  final String model;
  final String apiKey;

  const OpenAiConfig({this.model = 'gpt-4o', this.apiKey = ''});
}

class OpenAiProvider extends OpenAiCompatibleLlmProvider {
  static const _base = 'https://api.openai.com';
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

  @override
  String get baseUrl => _base;

  @override
  String get modelName => config.model;

  @override
  Dio get dio => _dio;

  OpenAiProvider({OpenAiConfig? config, SecureKeyStore? keyStore, Dio? dio})
    : config = config ?? const OpenAiConfig(),
      _keyStore = keyStore ?? SecureKeyStore() {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: _base,
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

  @override
  Future<String?> resolveApiKey() async {
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
        final apiKey = await resolveApiKey();
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
        throw ProviderFailure(id, formatDioError(e), e);
      } on FormatException catch (e) {
        throw ProviderFailure(id, 'Failed to parse response: ${e.message}');
      } on ProviderFailure {
        rethrow;
      } catch (e) {
        throw ProviderFailure(id, 'Unexpected error: $e');
      }
    }
  }

  /// Tool-calling transport lives in [OpenAiCompatibleLlmProvider]:
  /// strict tools, `tool_choice: auto`, `parallel_tool_calls: false`,
  /// `max_completion_tokens: 4096`, JSON-string `arguments` decode with
  /// validation, `role: tool` history mapping, empty-`userContent`
  /// omission, retry/backoff. This override only documents the contract.
  @override
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) =>
      super.chatWithTools(request);

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
      final apiKey = await resolveApiKey();
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
