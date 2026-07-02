import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'llm_provider.dart';

class AnthropicConfig {
  final String model;
  final String apiKey;

  const AnthropicConfig({
    this.model = 'claude-sonnet-4-20250514',
    this.apiKey = '',
  });
}

class AnthropicProvider implements LlmProvider {
  static const _baseUrl = 'https://api.anthropic.com';
  static const _apiVersion = '2023-06-01';
  static const _models = [
    'claude-sonnet-4-20250514',
    'claude-haiku-3-5-sonnet-20241022',
    'claude-3-opus-latest',
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

  AnthropicProvider({
    AnthropicConfig? config,
    SecureKeyStore? keyStore,
  })  : config = config ?? const AnthropicConfig(),
        _keyStore = keyStore ?? SecureKeyStore() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': config?.apiKey ?? '',
        'anthropic-version': _apiVersion,
      },
    ));
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
          {'role': 'user', 'content': '${request.systemPrompt}\n\n${request.userCommand}'},
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

        final response = await _dio.post(
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
          await Future.delayed(Duration(seconds: attempt * 2));
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
              'required': ['id', 'type', 'targetClipId', 'params'],
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
      await _dio.post(
        '/v1/messages',
        data: {
          'model': config.model,
          'max_tokens': 1,
          'messages': [{'role': 'user', 'content': 'test'}],
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
