/// Typed activity events for the tool-calling loop (D7).
///
/// Emitted on [ToolCallingAgent.activityEvents]. The legacy one-shot path
/// keeps using [PipelineEvent]; no UI changes in Phase 2.
enum AgentActivityKind {
  runStarted,
  llmRoundStarted,
  llmRoundCompleted,
  toolCallStarted,
  toolCallCompleted,
  toolCallFailed,
  runCompleted,
  runFailed,
  runCancelled,
}

class AgentActivityEvent {
  final AgentActivityKind kind;
  final int round;
  final String? toolCallId;
  final String? toolName;
  final Map<String, dynamic>? args;
  final String? summary;
  final bool? success;
  final int? durationMs;
  final DateTime timestamp;

  AgentActivityEvent({
    required this.kind,
    this.round = 0,
    this.toolCallId,
    this.toolName,
    this.args,
    this.summary,
    this.success,
    this.durationMs,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
