import 'dart:async';
import 'dart:convert';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'agent_activity.dart';
import 'agent_turn.dart';
import 'operation_schema.dart';
import 'tools/tool_definition.dart';
import 'tools/tool_executors.dart';
import 'tools/tool_prompts.dart';
import 'tools/tool_registry.dart';

enum AgentRunStatus { success, error }

/// Final outcome of one agent run, mapped by the pipeline to [SubmitResult].
class AgentRunResult {
  final AgentRunStatus status;
  final String message;
  final List<EditOperation> appliedOperations;
  final String? outputPath;

  /// Full call trace across all rounds (id/name/args/success/summary/
  /// durationMs). Per-round provider results ([AgentTurnResult]) carry no
  /// execution info — the trace accumulates here at run level.
  final List<AgentToolCallRecord> records;

  const AgentRunResult({
    required this.status,
    required this.message,
    this.appliedOperations = const [],
    this.outputPath,
    this.records = const [],
  });
}

/// Multi-round tool-calling loop (D1: the loop lives in domain).
///
/// Owns the canonical conversation (`List<AgentTurnMessage>`), calls
/// [LlmProvider.chatWithTools] once per round, executes each requested
/// tool via the registry, and maps tool results back. Bounded by
/// [ToolRegistry.maxToolRounds] rounds and the context job budget.
/// Activity is reported on [activityEvents]; providers stay transport-only.
class ToolCallingAgent {
  final LlmProvider provider;
  final ToolRegistry registry;
  final ToolExecutionContext context;
  final StreamController<AgentActivityEvent> _activity =
      StreamController<AgentActivityEvent>.broadcast();

  Stream<AgentActivityEvent> get activityEvents => _activity.stream;

  ToolCallingAgent({
    required this.provider,
    required ToolExecutionContext context,
    ToolRegistry? registry,
  })  : context = context,
        registry = registry ?? createToolRegistry(context);

  Future<AgentRunResult> run({
    required ValidatedCommand validated,
    List<AgentRequest>? recentHistory,
    int timeoutSeconds = 60,
    double temperature = 0.1,
  }) async {
    context.resetRun();
    final history = <AgentTurnMessage>[];
    final systemPrompt = ToolPromptBuilder.buildSystemPrompt();
    var userContent = ToolPromptBuilder.buildUserContent(validated);
    final recent = _recentHistoryLines(recentHistory);
    if (recent.isNotEmpty) {
      userContent += '\n---\nRECENT CHAT HISTORY (for context):\n$recent';
    }

    _emit(AgentActivityKind.runStarted, summary: validated.text);
    String lastText = '';
    var hitMaxRounds = false;
    final records = <AgentToolCallRecord>[];

    for (var round = 1; round <= ToolRegistry.maxToolRounds; round++) {
      _emit(AgentActivityKind.llmRoundStarted, round: round);
      AgentTurnResult turn;
      try {
        turn = await provider.chatWithTools(
          AgentTurnRequest(
            systemPrompt: systemPrompt,
            userContent: round == 1
                ? userContent
                : 'Continue with the next step. If every requested edit is '
                    'done, reply with a plain-text summary and no tool calls.',
            tools: registry.definitions(),
            history: List.unmodifiable(history),
            timeoutSeconds: timeoutSeconds,
            temperature: temperature,
          ),
        );
      } catch (e) {
        _emit(
          AgentActivityKind.runFailed,
          round: round,
          summary: 'LLM error: $e',
        );
        return AgentRunResult(
          status: AgentRunStatus.error,
          message: 'LLM error: $e',
          records: List.unmodifiable(records),
        );
      }

      lastText = turn.text;
      history.add(AgentTurnMessage(
        role: AgentTurnRole.assistant,
        content: turn.text.isEmpty ? null : turn.text,
        toolCalls: turn.toolCalls,
      ));

      if (turn.toolCalls.isEmpty) {
        _emit(
          AgentActivityKind.llmRoundCompleted,
          round: round,
          summary: turn.text,
        );
        break;
      }

      for (final call in turn.toolCalls) {
        await _executeOne(round, call, history, records);
      }
      _emit(AgentActivityKind.llmRoundCompleted, round: round);

      if (round == ToolRegistry.maxToolRounds) {
        hitMaxRounds = true;
      }
    }

    final applied = List<EditOperation>.from(context.appliedOperations);
    final outputPath = context.outputPaths.isEmpty
        ? null
        : context.outputPaths.first;
    var message = lastText.trim().isNotEmpty
        ? lastText.trim()
        : (applied.isEmpty
            ? 'No edits were needed.'
            : 'Applied ${applied.length} edit(s).');
    if (hitMaxRounds) {
      message +=
          ' (Stopped after ${ToolRegistry.maxToolRounds} tool rounds.)';
    }
    _emit(
      AgentActivityKind.runCompleted,
      summary: message,
      success: true,
    );
    return AgentRunResult(
      status: AgentRunStatus.success,
      message: message,
      appliedOperations: applied,
      outputPath: outputPath,
      records: List.unmodifiable(records),
    );
  }

  Future<void> _executeOne(
    int round,
    AgentToolCall call,
    List<AgentTurnMessage> history,
    List<AgentToolCallRecord> records,
  ) async {
    final stopwatch = Stopwatch()..start();
    _emit(
      AgentActivityKind.toolCallStarted,
      round: round,
      toolCallId: call.id,
      toolName: call.name,
      args: call.args,
    );

    final executor = registry.executorFor(call.name);
    ToolResult result;
    if (executor == null) {
      result = ToolResult.fail(
        'Unknown tool "${call.name}". Available tools: '
        '${registry.definitions().map((d) => d.name).join(', ')}. '
        'Check the tool name and retry.',
      );
    } else {
      try {
        result = await executor.execute(
          ToolCall(id: call.id, name: call.name, args: call.args),
        );
      } catch (e) {
        result = ToolResult.fail('Tool "${call.name}" failed: $e');
      }
    }
    stopwatch.stop();
    records.add(AgentToolCallRecord(
      id: call.id,
      name: call.name,
      args: call.args,
      success: result.success,
      summary: result.summary,
      durationMs: stopwatch.elapsedMilliseconds,
    ));

    history.add(AgentTurnMessage(
      role: AgentTurnRole.toolResult,
      // jsonEncode keeps model-provided strings intact on the wire.
      content: jsonEncode({
        'success': result.success,
        'summary': result.summary,
        'data': result.data,
        if (!result.success) 'error': result.error,
      }),
      toolCallId: call.id,
      toolError: !result.success,
    ));

    _emit(
      result.success
          ? AgentActivityKind.toolCallCompleted
          : AgentActivityKind.toolCallFailed,
      round: round,
      toolCallId: call.id,
      toolName: call.name,
      summary: result.summary,
      success: result.success,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  String _recentHistoryLines(List<AgentRequest>? recentHistory) {
    if (recentHistory == null || recentHistory.isEmpty) return '';
    final lines = StringBuffer();
    for (final entry in recentHistory.take(3)) {
      lines.writeln('User: ${entry.userCommand}');
    }
    return lines.toString();
  }

  void _emit(
    AgentActivityKind kind, {
    int round = 0,
    String? toolCallId,
    String? toolName,
    Map<String, dynamic>? args,
    String? summary,
    bool? success,
    int? durationMs,
  }) {
    _activity.add(AgentActivityEvent(
      kind: kind,
      round: round,
      toolCallId: toolCallId,
      toolName: toolName,
      args: args,
      summary: summary,
      success: success,
      durationMs: durationMs,
    ));
  }

  void dispose() {
    _activity.close();
  }
}
