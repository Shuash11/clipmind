import 'dart:async';

import 'package:dio/dio.dart';

import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'llm_provider.dart';
import 'openai_compatible_provider.dart';

class CustomOpenAiConfig {
  /// Full base INCLUDING the version prefix (e.g.
  /// `https://openrouter.ai/api/v1`), mirroring the Gen B
  /// `ProviderEndpointResolver` convention.
  final Uri endpoint;
  final String model;

  /// Already resolved from the Gen B credential store by the state layer.
  final String? apiKey;

  const CustomOpenAiConfig({
    required this.endpoint,
    required this.model,
    this.apiKey,
  });
}

/// User-configured OpenAI-compatible server (OpenRouter, llama.cpp server,
/// LiteLLM, …) behind the shared tool-calling transport.
///
/// URL convention: Dio `baseUrl` is the profile endpoint and
/// [chatCompletionsPath] is the relative `chat/completions`, so Dio joins
/// them (`…/api/v1` + `chat/completions`). A path-absolute post would
/// replace the base path (RFC 3986) and drop the prefix — the Phase-2
/// critical mismatch this override exists to avoid.
///
/// Conservative extras (`max_tokens` only, like Ollama) are safest for
/// unknown compat servers. Local servers may be slow: 60s receive
/// timeout, 120s suggested round timeout.
class CustomOpenAiCompatibleProvider extends OpenAiCompatibleLlmProvider {
  final CustomOpenAiConfig config;
  late final Dio _dio;
  final StreamController<ConnectionStatus> _connectionCtrl =
      StreamController<ConnectionStatus>.broadcast();
  Timer? _healthTimer;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  String get id => 'custom:${config.model}';

  @override
  String get baseUrl => _normalizedEndpoint;

  /// Dio concatenates a relative path directly onto the base (no `/`
  /// inserted), so the base keeps exactly one trailing slash — verified
  /// by unit test (`…/api/v1` + `chat/completions` must not become
  /// `…/api/v1chat/completions`).
  String get _normalizedEndpoint {
    final raw = config.endpoint.toString().replaceAll(RegExp(r'/+$'), '');
    return '$raw/';
  }

  @override
  String get modelName => config.model;

  @override
  Dio get dio => _dio;

  /// Relative path: joins onto the endpoint base (which already carries
  /// the version prefix). Never make this path-absolute — a leading `/`
  /// would drop the prefix.
  @override
  String get chatCompletionsPath => 'chat/completions';

  /// `max_completion_tokens` support on unknown servers is unverified;
  /// send legacy `max_tokens: 4096` (mirrors Ollama).
  @override
  bool get usesMaxCompletionTokens => false;

  @override
  bool get supportsToolCalling => true;

  /// Custom/local models may be slow.
  @override
  int get suggestedRoundTimeoutSeconds => 120;

  CustomOpenAiCompatibleProvider({
    required this.config,
    Dio? dio,
  }) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: _normalizedEndpoint,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 60),
            headers: {'Content-Type': 'application/json'},
          ),
        );
  }

  @override
  Future<String?> resolveApiKey() async {
    final key = config.apiKey;
    if (key != null && key.isNotEmpty) return key;
    // Keyless (Ollama-like): the shared transport sends no `Authorization`
    // header. A key-requiring server 401s → generic 'Invalid API key'.
    return null;
  }

  @override
  Future<List<String>> availableModels() async {
    return [config.model];
  }

  /// Legacy one-shot planning is unavailable for custom providers.
  ///
  /// Unreachable in production: the capability gate routes all
  /// tool-capable providers to the agentic loop.
  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) {
    throw ProviderFailure(
      id,
      'Legacy one-shot planning is unavailable for custom providers.',
    );
  }

  /// Tool-calling transport lives in [OpenAiCompatibleLlmProvider]:
  /// strict tools, `tool_choice: auto`, `max_tokens: 4096`, JSON-string
  /// `arguments` decode with validation, `role: tool` history mapping,
  /// empty-`userContent` omission, retry/backoff. This override only
  /// documents the contract.
  @override
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) =>
      super.chatWithTools(request);

  @override
  String connectionErrorText() =>
      'Cannot connect to ${config.endpoint.host} — is the server running?';

  // [mapToolsModelError] intentionally left at the base default (null):
  // unknown servers have no documented tools-model error shape.

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

  /// Health check GETs `{endpoint}/models` (relative, mirroring the Gen B
  /// discovery convention). Any HTTP response counts as connected — even
  /// 4xx (the server answered); only transport-establishment failures
  /// (connection/send timeouts, connection errors) count as disconnected.
  Future<void> _checkHealth() async {
    _connectionCtrl.add(ConnectionStatus.connecting);
    try {
      await _dio.get<Map<String, dynamic>>(
        'models',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      _setConnected();
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionError:
          _setDisconnected();
          break;
        default:
          // badResponse (any status) and friends: the server answered.
          _setConnected();
          break;
      }
    } catch (_) {
      _setDisconnected();
    }
  }

  void _setConnected() {
    if (_status != ConnectionStatus.connected) {
      _status = ConnectionStatus.connected;
      _connectionCtrl.add(ConnectionStatus.connected);
    }
  }

  void _setDisconnected() {
    if (_status != ConnectionStatus.disconnected) {
      _status = ConnectionStatus.disconnected;
      _connectionCtrl.add(ConnectionStatus.disconnected);
    }
  }

  void dispose() {
    _healthTimer?.cancel();
    _connectionCtrl.close();
  }
}
