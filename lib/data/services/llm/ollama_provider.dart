import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'llm_provider.dart';
import 'openai_compatible_provider.dart';

class OllamaConfig {
  final String host;
  final int port;
  final String model;
  final String apiKey;

  const OllamaConfig({
    this.host = 'localhost',
    this.port = 11434,
    this.model = 'llama3.1',
    this.apiKey = '',
  });

  String get baseUrl => 'http://$host:$port';

  String get compatBaseUrl => 'http://$host:$port/v1';
}

class OllamaProvider extends OpenAiCompatibleLlmProvider {
  final OllamaConfig config;
  final SecureKeyStore _keyStore;
  late final Dio _dio;
  final StreamController<ConnectionStatus> _connectionCtrl =
      StreamController<ConnectionStatus>.broadcast();
  Timer? _healthTimer;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  String get id => 'ollama:${config.model}';

  @override
  String get baseUrl => config.compatBaseUrl;

  @override
  String get modelName => config.model;

  @override
  Dio get dio => _dio;

  /// `max_completion_tokens` support on Ollama's compat layer is
  /// unverified, so the shared transport sends legacy `max_tokens: 4096`
  /// instead (see [OpenAiCompatibleLlmProvider.toolRequestExtras]).
  @override
  bool get usesMaxCompletionTokens => false;

  OllamaProvider({
    OllamaConfig? config,
    SecureKeyStore? keyStore,
    Dio? dio,
  })  : config = config ?? const OllamaConfig(),
        _keyStore = keyStore ?? SecureKeyStore() {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: this.config.compatBaseUrl,
            connectTimeout: const Duration(seconds: 5),
            // Local models are slow; keep the generous receive timeout.
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 60),
            headers: {'Content-Type': 'application/json'},
          ),
        );
  }

  @override
  Future<String?> resolveApiKey() async {
    if (config.apiKey.isNotEmpty) return config.apiKey;
    try {
      final stored = await _keyStore.readApiKey('ollama');
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (_) {
      // Keyless local installs are the norm; ignore store failures.
    }
    // No key: the shared transport sends no `Authorization` header.
    return null;
  }

  /// Tool-calling transport is shared with OpenAI via
  /// [OpenAiCompatibleLlmProvider] against `{host}:{port}/v1` (which
  /// officially supports tools). Conservative extras only: `max_tokens`
  /// with no `parallel_tool_calls`/`max_completion_tokens` until verified
  /// against a live Ollama. Requires a tools-capable model (e.g.
  /// `ollama pull llama3.1`); other models fail via [mapToolsModelError].
  @override
  bool get supportsToolCalling => true;

  @override
  String connectionErrorText() =>
      'Cannot connect to Ollama at ${config.baseUrl}. Is Ollama running?';

  @override
  String? mapToolsModelError(Object? data) {
    if (data == null) return null;
    final text = data.toString().toLowerCase();
    if (!text.contains('tool')) return null;
    return 'Model "${config.model}" does not support tool calling. '
        'Use a tools-capable model (e.g. llama3.1) — '
        'run `ollama pull llama3.1` and select it.';
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
        'Failed to fetch models: ${formatDioError(e)}',
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
        'options': {'temperature': 0.1, 'num_predict': 2048},
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
      throw ProviderFailure(id, formatDioError(e), e);
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
      await _dio.get<Map<String, dynamic>>(
        '/api/tags',
        options: Options(receiveTimeout: const Duration(seconds: 3)),
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
