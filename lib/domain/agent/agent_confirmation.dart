import 'agent_turn.dart';

/// Which confirmation flow gated a batch of tool calls.
enum ConfirmationKind { bulk, perEdit }

/// What the agent wants approval for before executing edits.
///
/// [toolCalls] is the gated batch: for [ConfirmationKind.bulk] the whole
/// round's edit calls (≥3); for [ConfirmationKind.perEdit] the single edit
/// call awaiting approval.
class ConfirmationRequest {
  final int round;
  final List<AgentToolCall> toolCalls;
  final ConfirmationKind kind;

  const ConfirmationRequest({
    required this.round,
    required this.toolCalls,
    required this.kind,
  });
}

/// Human-in-the-loop gate for the tool-calling loop (MCP approval).
///
/// Implemented in the state layer (pending-confirmation state + completer);
/// the domain only awaits [ask]. Mirrors the [AgentEditApplier]
/// injected-dependency pattern: the domain never imports state/UI.
///
/// - Bulk mode (default): when a gate is provided, a round requesting ≥3
///   edit tool calls pauses for one approval covering the whole batch.
/// - Per-edit mode (opt-in via [requiresPerEditApproval]): every edit tool
///   call pauses for its own approval.
///
/// Returns true = approve (execute), false = skip (record "Skipped by
/// user" failures and let the model finish). If the run's cancellation
/// token fires while paused, the agent proceeds as denied.
abstract class ConfirmationGate {
  /// Opt-in per-edit mode. Defaults to false (bulk-only).
  bool get requiresPerEditApproval => false;

  /// Ask the user; true = approve, false = skip.
  Future<bool> ask(ConfirmationRequest request);
}
