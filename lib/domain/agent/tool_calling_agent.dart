import 'dart:async';
import 'dart:convert';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'agent_activity.dart';
import 'agent_confirmation.dart';
import 'agent_turn.dart';
import 'operation_schema.dart';
import 'tools/tool_definition.dart';
import 'tools/tool_executors.dart';
import 'tools/tool_prompts.dart';
import 'tools/tool_registry.dart';

enum AgentRunStatus { success, error, cancelled }

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
    CancellationToken? cancellation,
    ConfirmationGate? gate,
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
      if (cancellation?.isCancelled == true) {
        return _cancelled(records, round: round);
      }
      _emit(AgentActivityKind.llmRoundStarted, round: round);
      AgentTurnResult turn;
      try {
        turn = await provider.chatWithTools(
          AgentTurnRequest(
            systemPrompt: systemPrompt,
            // Round 1 carries the command as the trailing user message;
            // rounds 2+ pass empty content — the original user turn already
            // lives in history (providers omit empty trailing messages).
            userContent: round == 1 ? userContent : '',
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

      // The token may have been cancelled while the LLM call was in
      // flight (chatWithTools itself is not cancellable).
      if (cancellation?.isCancelled == true) {
        return _cancelled(records, round: round);
      }

      lastText = turn.text;
      if (round == 1) {
        // Seed history with the original user turn so rounds 2+ keep the
        // command even though they send no trailing user message.
        history.add(AgentTurnMessage(
          role: AgentTurnRole.user,
          content: userContent,
        ));
      }
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

      final bulkDenied = await _maybeBulkConfirm(
        round,
        turn.toolCalls,
        gate,
        cancellation,
      );
      if (bulkDenied == null) {
        return _cancelled(records, round: round);
      }
      for (final call in turn.toolCalls) {
        if (cancellation?.isCancelled == true && !bulkDenied) {
          return _cancelled(records, round: round);
        }
        if (bulkDenied && _isEditTool(call.name)) {
          _recordSkipped(round, call, history, records);
          continue;
        }
        if (gate != null &&
            gate.requiresPerEditApproval &&
            _isEditTool(call.name)) {
          if (cancellation?.isCancelled == true) {
            return _cancelled(records, round: round);
          }
          final approved = await _confirmOne(
            round,
            call,
            gate,
            cancellation,
          );
          if (!approved) {
            _recordSkipped(round, call, history, records);
            continue;
          }
        }
        if (cancellation?.isCancelled == true) {
          return _cancelled(records, round: round);
        }
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

  /// Bulk gate: null = cancelled before asking (caller cancels the run),
  /// true = gated batch denied (record skips), false = proceed normally.
  Future<bool?> _maybeBulkConfirm(
    int round,
    List<AgentToolCall> calls,
    ConfirmationGate? gate,
    CancellationToken? cancellation,
  ) async {
    if (gate == null || gate.requiresPerEditApproval) return false;
    final edits = calls.where((c) => _isEditTool(c.name)).toList();
    if (edits.length < 3) return false;
    if (cancellation?.isCancelled == true) return null;
    final summary = _bulkSummary(edits);
    _emit(
      AgentActivityKind.confirmationRequested,
      round: round,
      summary: summary,
    );
    final approved = await _askGate(
      gate,
      ConfirmationRequest(
        round: round,
        toolCalls: List.unmodifiable(edits),
        kind: ConfirmationKind.bulk,
      ),
      cancellation,
    );
    _emit(
      AgentActivityKind.confirmationResolved,
      round: round,
      summary: summary,
      success: approved,
    );
    return !approved;
  }

  Future<bool> _confirmOne(
    int round,
    AgentToolCall call,
    ConfirmationGate gate,
    CancellationToken? cancellation,
  ) async {
    final summary = '${call.name} (${call.id})';
    _emit(
      AgentActivityKind.confirmationRequested,
      round: round,
      toolCallId: call.id,
      toolName: call.name,
      summary: summary,
    );
    final approved = await _askGate(
      gate,
      ConfirmationRequest(
        round: round,
        toolCalls: [call],
        kind: ConfirmationKind.perEdit,
      ),
      cancellation,
    );
    _emit(
      AgentActivityKind.confirmationResolved,
      round: round,
      toolCallId: call.id,
      toolName: call.name,
      summary: summary,
      success: approved,
    );
    return approved;
  }

  Future<bool> _askGate(
    ConfirmationGate gate,
    ConfirmationRequest request,
    CancellationToken? cancellation,
  ) async {
    if (cancellation == null) return gate.ask(request);
    if (cancellation.isCancelled) return false;
    return Future.any<bool>([
      gate.ask(request),
      cancellation.whenCancelled.then((_) => false),
    ]);
  }

  bool _isEditTool(String name) {
    return registry.definitionFor(name)?.category == ToolCategory.edit;
  }

  String _bulkSummary(List<AgentToolCall> edits) {
    return '${edits.length} edit(s): ${edits.map((e) => e.name).join(', ')}';
  }

  /// Transparent skip: failed record + tool error history so the model can
  /// summarize and finish. Read tools in the same round still execute.
  void _recordSkipped(
    int round,
    AgentToolCall call,
    List<AgentTurnMessage> history,
    List<AgentToolCallRecord> records,
  ) {
    const message = 'Skipped by user';
    _emit(
      AgentActivityKind.toolCallStarted,
      round: round,
      toolCallId: call.id,
      toolName: call.name,
      args: call.args,
    );
    records.add(AgentToolCallRecord(
      id: call.id,
      name: call.name,
      args: call.args,
      success: false,
      summary: message,
      durationMs: 0,
    ));
    history.add(AgentTurnMessage(
      role: AgentTurnRole.toolResult,
      content: jsonEncode({
        'success': false,
        'summary': message,
        'data': <String, dynamic>{},
        'error': message,
      }),
      toolCallId: call.id,
      toolError: true,
    ));
    _emit(
      AgentActivityKind.toolCallFailed,
      round: round,
      toolCallId: call.id,
      toolName: call.name,
      summary: message,
      success: false,
      durationMs: 0,
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

  /// Partial result for a cancelled run: already-applied edits stay
  /// (undoable via the applier); nothing further starts.
  AgentRunResult _cancelled(
    List<AgentToolCallRecord> records, {
    required int round,
  }) {
    final applied = List<EditOperation>.from(context.appliedOperations);
    final outputPath =
        context.outputPaths.isEmpty ? null : context.outputPaths.first;
    final message = 'Cancelled — ${applied.length} edit(s) applied.';
    _emit(
      AgentActivityKind.runCancelled,
      round: round,
      summary: message,
      success: false,
    );
    return AgentRunResult(
      status: AgentRunStatus.cancelled,
      message: message,
      appliedOperations: applied,
      outputPath: outputPath,
      records: List.unmodifiable(records),
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
