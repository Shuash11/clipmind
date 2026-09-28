import 'package:freezed_annotation/freezed_annotation.dart';
import 'tools/tool_definition.dart';

part 'agent_turn.freezed.dart';
part 'agent_turn.g.dart';

/// Canonical role for one turn message in the tool-calling loop.
enum AgentTurnRole { user, assistant, toolResult }

/// How a [chatWithTools] round trip ended.
enum AgentTurnStopReason { stop, toolCalls, maxRounds, error }

/// One function call requested by the assistant.
@freezed
class AgentToolCall with _$AgentToolCall {
  const factory AgentToolCall({
    required String id,
    required String name,
    @Default({}) Map<String, dynamic> args,
  }) = _AgentToolCall;

  factory AgentToolCall.fromJson(Map<String, dynamic> json) =>
      _$AgentToolCallFromJson(json);
}

/// One message in the canonical conversation owned by [ToolCallingAgent].
///
/// Assistant messages carry [toolCalls]; each tool result is its own
/// [AgentTurnRole.toolResult] message identified by [toolCallId].
/// [toolError] marks failed results (Anthropic `is_error`).
/// [toolName] is the provider-neutral function name for tool results
/// (Gemini `functionResponse` is keyed by name; `functionCall` carries no
/// id). OpenAI/Anthropic mappers ignore it; never repurpose [toolCallId].
@freezed
class AgentTurnMessage with _$AgentTurnMessage {
  const factory AgentTurnMessage({
    required AgentTurnRole role,
    String? content,
    @Default([]) List<AgentToolCall> toolCalls,
    String? toolCallId,
    @Default(false) bool toolError,
    String? toolName,
  }) = _AgentTurnMessage;

  factory AgentTurnMessage.fromJson(Map<String, dynamic> json) =>
      _$AgentTurnMessageFromJson(json);
}

/// One round trip to the provider: system prompt, user content, the tools
/// on offer, and the conversation so far.
@freezed
class AgentTurnRequest with _$AgentTurnRequest {
  const factory AgentTurnRequest({
    required String systemPrompt,
    required String userContent,
    @Default([]) List<ToolDefinition> tools,
    @Default([]) List<AgentTurnMessage> history,
    @Default(60) int timeoutSeconds,
    @Default(0.1) double temperature,
  }) = _AgentTurnRequest;

  factory AgentTurnRequest.fromJson(Map<String, dynamic> json) =>
      _$AgentTurnRequestFromJson(json);
}

/// Full trace of one executed tool call inside a turn result.
@freezed
class AgentToolCallRecord with _$AgentToolCallRecord {
  const factory AgentToolCallRecord({
    required String id,
    required String name,
    @Default({}) Map<String, dynamic> args,
    required bool success,
    @Default('') String summary,
    @Default(0) int durationMs,
  }) = _AgentToolCallRecord;

  factory AgentToolCallRecord.fromJson(Map<String, dynamic> json) =>
      _$AgentToolCallRecordFromJson(json);
}

/// What one [chatWithTools] round trip returned.
@freezed
class AgentTurnResult with _$AgentTurnResult {
  const factory AgentTurnResult({
    @Default('') String text,
    @Default([]) List<AgentToolCall> toolCalls,
    @Default([]) List<AgentToolCallRecord> records,
    @Default(AgentTurnStopReason.stop) AgentTurnStopReason stopReason,
  }) = _AgentTurnResult;

  factory AgentTurnResult.fromJson(Map<String, dynamic> json) =>
      _$AgentTurnResultFromJson(json);
}
