import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'llm_provider.dart';
import 'openai_compatible_provider.dart';

class NvidiaNimConfig {
  final String model;
  final String apiKey;

  const NvidiaNimConfig({
    this.model = 'meta/llama-3.3-70b-instruct',
    this.apiKey = '',
  });
}

/// NVIDIA NIM behind the shared OpenAI-compatible tool-calling transport.
///
/// Live-verification gate: the endpoint
/// (`https://integrate.api.nvidia.com` + `/v1/chat/completions`) is
/// doc-verified against the NIM LLM APIs reference; `strict: true` inside
/// function definitions, `max_tokens: 4096`, and the `GET /v1/models`
/// health check are mock-verified only (like Ollama in Phase 1) until a
/// manual live test runs. Conservative extras only — `parallel_tool_calls`
/// and `max_completion_tokens` are excluded as unverified, and NIM-specific
/// `nvext` params are not used this phase.
///
/// Model discovery: the primary user-facing path is the Gen B selector's
/// "Discover models" button (live `GET {endpoint}/models` via
/// `OpenAiCompatibleAdapter.discoverModels` → the full live free catalog;
/// the live list is authoritative and unfiltered). [availableModels] below
/// mirrors that live list with a curated fallback.
class NvidiaNimProvider extends OpenAiCompatibleLlmProvider {
  static const _baseUrl = 'https://integrate.api.nvidia.com';

  /// Curated fallback (NIM LLM APIs reference, 2026-09-29): the ~40
  /// generative chat models. EXCLUDED — guard/classifier models, not
  /// editing agents: gliner-pii, llama-3.1-nemoguard-8b-content-safety,
  /// llama-3.1-nemoguard-8b-topic-control,
  /// llama-3.1-nemotron-safety-guard-8b-v3, nemoguard-jailbreak-detect,
  /// nemotron-content-safety-reasoning-4b. The hyphenation of
  /// `z-ai/glm4.7` / `z-ai/glm5.1` is inconsistent in the doc —
  /// TO-VERIFY-LIVE (the live list is authoritative).
  static const _models = [
    'meta/llama-3.3-70b-instruct',
    'deepseek-ai/deepseek-v4-flash',
    'deepseek-ai/deepseek-v4-flash-0731',
    'deepseek-ai/deepseek-v4-pro',
    'google/codegemma-7b',
    'google/gemma-7b',
    'meta/llama2-70b',
    'meta/llama-3.1-8b-instruct',
    'meta/llama-3.1-70b-instruct',
    'meta/llama-3.2-1b-instruct',
    'meta/llama-3.2-3b-instruct',
    'microsoft/phi-4-mini-instruct',
    'microsoft/phi-4-mini-flash-reasoning',
    'minimaxai/minimax-m2.5',
    'minimaxai/minimax-m2.7',
    'mistralai/mistral-nemotron',
    'mistralai/mixtral-8x7b-instruct',
    'mistralai/mixtral-8x22b-instruct',
    'moonshotai/kimi-k2-instruct',
    'moonshotai/kimi-k2-thinking',
    'moonshotai/kimi-k3',
    'nvidia/llama-3.3-nemotron-super-49b-v1',
    'nvidia/llama-3.3-nemotron-super-49b-v1.5',
    'nvidia/llama-3.1-nemotron-ultra-253b-v1',
    'nvidia/nemotron-3-ultra-550b-a55b',
    'nvidia/nemotron-3.5-lightning-30b-a3b',
    'nvidia/nemotron-3-nano-30b-a3b',
    'nvidia/nemotron-3-super-120b-a12b',
    'nvidia/nvidia-nemotron-nano-9b-v2',
    'nvidia/riva-translate-4b-instruct-v1.1',
    'nvidia/riva-translate-4b-instruct-v2',
    'nvidia/usdcode',
    'openai/gpt-oss-20b',
    'openai/gpt-oss-120b',
    'qwen/qwen2.5-coder-32b-instruct',
    'qwen/qwen3-next-80b-a3b-instruct',
    'qwen/qwen3-next-80b-a3b-thinking',
    'qwen/qwq-32b',
    'poolside/laguna-xs-2-1',
    'sarvamai/sarvam-m',
    'stepfun-ai/step-3.5-flash',
    'stockmark/stockmark-2-100b-instruct',
    'thinkingmachines/inkling',
    'upstage/solar-10.7b-instruct',
    'z-ai/glm4.7',
    'z-ai/glm5.1',
    'z-ai/glm-5.2',
    'z-ai/glm-5.3',
    'z-ai/glm-5.3-flash',
  ];

  final NvidiaNimConfig config;
  final SecureKeyStore _keyStore;
  late final Dio _dio;
  final StreamController<ConnectionStatus> _connectionCtrl =
      StreamController<ConnectionStatus>.broadcast();
  Timer? _healthTimer;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  String get id => 'nvidia_nim:${config.model}';

  @override
  String get baseUrl => _baseUrl;

  @override
  String get modelName => config.model;

  @override
  Dio get dio => _dio;

  /// `max_completion_tokens` support on NIM is unverified, so the shared
  /// transport sends legacy `max_tokens: 4096` instead (see
  /// [OpenAiCompatibleLlmProvider.toolRequestExtras]).
  @override
  bool get usesMaxCompletionTokens => false;

  /// Conservative subset only: `max_tokens` with no `parallel_tool_calls` /
  /// `max_completion_tokens` until verified against live NIM.
  @override
  Map<String, dynamic> toolRequestExtras() => const {'max_tokens': 4096};

  NvidiaNimProvider({
    NvidiaNimConfig? config,
    SecureKeyStore? keyStore,
    Dio? dio,
  })  : config = config ?? const NvidiaNimConfig(),
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

  @override
  Future<String?> resolveApiKey() async {
    if (config.apiKey.isNotEmpty) return config.apiKey;
    final stored = await _keyStore.readApiKey('nvidia_nim');
    if (stored == null || stored.isEmpty) {
      throw ProviderFailure(id, 'NVIDIA NIM API key not configured');
    }
    return stored;
  }

  /// Tool-calling transport is shared with OpenAI via
  /// [OpenAiCompatibleLlmProvider] against `integrate.api.nvidia.com/v1`.
  @override
  bool get supportsToolCalling => true;

  @override
  String connectionErrorText() => 'Cannot connect to NVIDIA NIM API';

  // [mapToolsModelError] intentionally left at the base default: NIM has
  // no documented tools-model error shape.

  /// Live model list with a curated fallback: `GET /v1/models` (same
  /// request shape as the health check), parsing the standard
  /// `data[].id` shape and deduping in endpoint order. Falls back to
  /// [_models] on ANY failure (no key, transport error, malformed body).
  @override
  Future<List<String>> availableModels() async {
    try {
      final apiKey = await resolveApiKey();
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/models',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          headers: authHeaders(apiKey),
        ),
      );
      final live = _parseModelIds(response.data);
      if (live.isNotEmpty) return live;
    } catch (_) {
      // Fall through to the curated list (graceful degradation).
    }
    return _models;
  }

  /// Standard OpenAI-compatible list shape: `{data: [{id, ...}]}`.
  /// Non-string ids are skipped; order is preserved, dupes dropped.
  static List<String> _parseModelIds(Map<String, dynamic>? data) {
    final entries = data?['data'];
    if (entries is! List) return const [];
    final seen = <String>[];
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      final id = entry['id'];
      if (id is! String || id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
    }
    return seen;
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
            headers: authHeaders(apiKey),
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
  /// strict tools, `tool_choice: auto`, `max_tokens: 4096`, JSON-string
  /// `arguments` decode with validation, `role: tool` history mapping,
  /// empty-`userContent` omission, retry/backoff. This override only
  /// documents the contract.
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
          headers: authHeaders(apiKey),
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
