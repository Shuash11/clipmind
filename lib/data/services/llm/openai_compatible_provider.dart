import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'llm_provider.dart';

/// Shared transport for OpenAI-compatible Chat Completions tool calling.
///
/// Extracted from [OpenAiProvider] so every provider behind an
/// OpenAI-compatible endpoint (OpenAI itself, Ollama's `{host}:{port}/v1`,
/// and later NIM) runs the identical agentic loop: strict function tools,
/// `tool_choice: auto`, `tool_calls[]` with JSON-string `arguments`, and
/// `role: "tool"` history mapping with empty-`userContent` omission.
///
/// Subclasses keep their own [LlmProvider.parseCommand] (legacy one-shot
/// path), health checks, and model lists — only the tool-calling transport
/// is shared. Behavior for OpenAI is preserved verbatim.
///
/// Hook interface (for Cycle 2 Phases 2-3: NIM/Gemini):
/// - [baseUrl]: origin + `/v1` prefix of the compat endpoint.
/// - [modelName]: model sent as `model` in the request body.
/// - [dio]: injectable HTTP client (mocked in tests).
/// - [resolveApiKey]: `null` means "no auth header" (Ollama keyless).
/// - [usesMaxCompletionTokens]: `true` sends `max_completion_tokens`;
///   `false` sends legacy `max_tokens` (Ollama: compat support unverified).
/// - [toolRequestExtras]: extra body params beyond model/messages/tools/
///   tool_choice/temperature. Defaults from [usesMaxCompletionTokens];
///   override for provider-specific subsets (Ollama excludes unverified
///   `parallel_tool_calls`).
/// - [authHeaders]: headers for the resolved key; default Bearer.
/// - [connectionErrorText]: provider-specific unreachable message.
/// - [mapToolsModelError]: actionable message for non-tools models
///   (Ollama overrides; default `null`).
/// - [chatCompletionsPath]: endpoint path posted by [chatWithTools];
///   default path-absolute `/v1/chat/completions`. Custom servers whose
///   Dio `baseUrl` already includes the version prefix override with the
///   relative `chat/completions`.
abstract class OpenAiCompatibleLlmProvider extends LlmProvider {
  /// Origin + `/v1` prefix of the OpenAI-compatible endpoint.
  String get baseUrl;

  /// Model name sent as `model` in the request body.
  String get modelName;

  /// Injectable HTTP client (mocked Dio in tests).
  Dio get dio;

  /// Path of the Chat Completions endpoint posted by [chatWithTools].
  ///
  /// Default is path-absolute (`/v1/chat/completions`), preserving
  /// OpenAI/Ollama/NIM behavior verbatim. Custom servers whose Dio
  /// `baseUrl` already includes the version prefix (e.g.
  /// `https://…/api/v1`) override with the relative `chat/completions`:
  /// Dio joins it onto the base path, while a leading `/` would replace
  /// the base path (RFC 3986) and drop the prefix.
  String get chatCompletionsPath => '/v1/chat/completions';

  /// API key, or `null` when the endpoint needs no auth (Ollama keyless).
  ///
  /// May throw [ProviderFailure] when a key is required but missing
  /// (OpenAI).
  Future<String?> resolveApiKey();

  /// `true` sends `max_completion_tokens: 4096`; `false` sends legacy
  /// `max_tokens: 4096` (Ollama: `max_completion_tokens` support on the
  /// compat layer is unverified).
  bool get usesMaxCompletionTokens => true;

  /// Extra body params for tool requests. Defaults to the OpenAI subset;
  /// Ollama overrides (via [usesMaxCompletionTokens]) to the conservative
  /// `{'max_tokens': 4096}` only, excluding unverified `parallel_tool_calls`.
  Map<String, dynamic> toolRequestExtras() {
    if (usesMaxCompletionTokens) {
      return const {'parallel_tool_calls': false, 'max_completion_tokens': 4096};
    }
    return const {'max_tokens': 4096};
  }

  /// Auth headers for the resolved key. Empty when keyless (Ollama sends
  /// no `Authorization` header unless the user configured a key).
  Map<String, String> authHeaders(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return const {};
    return {'Authorization': 'Bearer $apiKey'};
  }

  /// Provider-specific "cannot reach endpoint" message.
  String connectionErrorText() => 'Cannot connect to OpenAI API';

  /// Actionable message when the model rejects tool params (e.g. a
  /// non-tools Ollama model). Return `null` to fall back to the generic
  /// server-error text.
  String? mapToolsModelError(Object? data) => null;

  @override
  bool get supportsToolCalling => true;

  /// One Chat Completions round trip with tools (transport-only).
  ///
  /// Sends `strict: true` function tools with `tool_choice: auto` plus
  /// [toolRequestExtras]. Parses `tool_calls` (JSON-string `arguments`)
  /// into canonical [AgentToolCall]s. Retries transient failures
  /// (`maxRetries` 2 with backoff).
  @override
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) async {
    const maxRetries = 2;
    var attempt = 0;

    while (true) {
      try {
        final apiKey = await resolveApiKey();
        final body = {
          'model': modelName,
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
          ...toolRequestExtras(),
          'temperature': request.temperature,
        };

        final response = await dio.post<Map<String, dynamic>>(
          chatCompletionsPath,
          data: body,
          options: Options(
            receiveTimeout: Duration(seconds: request.timeoutSeconds),
            headers: authHeaders(apiKey),
          ),
        );

        return _parseTurnResponse(response.data);
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

  String formatDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final toolsHint = mapToolsModelError(e.response?.data);
        if (toolsHint != null) return toolsHint;
        if (status == 401) return 'Invalid API key';
        if (status == 429) return 'Rate limited. Please try again.';
        return 'Server error: $status';
      case DioExceptionType.connectionError:
        return connectionErrorText();
      default:
        return 'Network error: ${e.message}';
    }
  }
}
