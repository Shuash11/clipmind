import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'llm_provider.dart';

class OllamaConfig {
  final String host;
  final int port;
  final String model;

  const OllamaConfig({
    this.host = 'localhost',
    this.port = 11434,
    this.model = 'llama3.1',
  });

  String get baseUrl => 'http://$host:$port';
}

class OllamaProvider implements LlmProvider {
  final OllamaConfig config;
  late final Dio _dio;
  final StreamController<ConnectionStatus> _connectionCtrl =
      StreamController<ConnectionStatus>.broadcast();
  Timer? _healthTimer;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  String get id => 'ollama:${config.model}';

  OllamaProvider({OllamaConfig? config})
      : config = config ?? const OllamaConfig() {
    _dio = Dio(BaseOptions(
      baseUrl: this.config.baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  @override
  Future<List<String>> availableModels() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/tags');
      final data = response.data as Map<String, dynamic>;
      final models = data['models'] as List<dynamic>? ?? [];
      return models
          .map((m) => (m as Map<String, dynamic>)['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw ProviderFailure(
        id,
        'Failed to fetch models: ${_formatDioError(e)}',
      );
    }
  }

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) async {
    try {
      final messages = [
        {'role': 'system', 'content': request.systemPrompt},
        {'role': 'user', 'content': request.userCommand},
      ];

      final body = {
        'model': config.model,
        'messages': messages,
        'stream': false,
        'format': _jsonSchemaToOllamaFormat(request.schemaJson),
        'options': {
          'temperature': 0.1,
          'num_predict': 2048,
        },
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/chat',
        data: body,
        options: Options(
          receiveTimeout: Duration(seconds: request.timeoutSeconds),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final message = data['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;

      if (content == null || content.trim().isEmpty) {
        throw ProviderFailure(id, 'Empty response from model');
      }

      final cleaned = _cleanJsonResponse(content);
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      return EditOperationSet.fromJson(parsed);
    } on DioException catch (e) {
      throw ProviderFailure(
        id,
        _formatDioError(e),
        e,
      );
    } on FormatException catch (e) {
      throw ProviderFailure(id, 'Failed to parse response: ${e.message}');
    } on ProviderFailure {
      rethrow;
    } catch (e) {
      throw ProviderFailure(id, 'Unexpected error: $e');
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

  Map<String, dynamic> _jsonSchemaToOllamaFormat(String schemaJson) {
    try {
      final schema = jsonDecode(schemaJson) as Map<String, dynamic>;
      return {
        'type': 'object',
        'properties': schema,
        'required': ['operations', 'summary'],
      };
    } catch (_) {
      return {
        'type': 'object',
        'properties': {
          'operations': {'type': 'array'},
          'summary': {'type': 'string'},
          'clarification_needed': {'type': 'string'},
        },
        'required': ['operations', 'summary'],
      };
    }
  }

  String _formatDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out';
      case DioExceptionType.badResponse:
        return 'Server error: ${e.response?.statusCode}';
      case DioExceptionType.connectionError:
        return 'Cannot connect to Ollama at ${config.baseUrl}. Is Ollama running?';
      default:
        return 'Network error: ${e.message}';
    }
  }

  @override
  Stream<ConnectionStatus> watchConnection() {
    _checkHealth();
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkHealth(),
    );
    return _connectionCtrl.stream;
  }

  Future<void> _checkHealth() async {
    _connectionCtrl.add(ConnectionStatus.connecting);
    try {
      await _dio.get<Map<String, dynamic>>('/api/tags', options: Options(receiveTimeout: const Duration(seconds: 3)));
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
