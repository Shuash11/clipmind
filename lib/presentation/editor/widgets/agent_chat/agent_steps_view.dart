import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/chat_step.dart';
import 'package:clipmind/domain/agent/agent_activity.dart';
import 'package:clipmind/domain/agent/agent_confirmation.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status of one tool-call step in the visible pipeline.
enum AgentStepStatus { running, success, failed, skipped }

/// One tool-call step row's data: built from live activity events or a
/// persisted [ChatStep]. Presentation-only mirror of the run's tool trace.
class AgentStepData {
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> args;
  final String? summary;
  final int? durationMs;
  final int round;
  final ChatStepKind kind;
  final AgentStepStatus status;

  const AgentStepData({
    required this.toolCallId,
    required this.toolName,
    this.args = const {},
    this.summary,
    this.durationMs,
    this.round = 0,
    this.kind = ChatStepKind.edit,
    required this.status,
  });

  /// From a persisted chat step (success -> done, else failed/skipped).
  factory AgentStepData.fromChatStep(ChatStep step) {
    return AgentStepData(
      toolCallId: step.toolCallId,
      toolName: step.toolName,
      args: step.args,
      summary: step.summary.isEmpty ? null : step.summary,
      durationMs: step.durationMs,
      round: step.round,
      kind: step.kind,
      status: statusForResult(success: step.success, summary: step.summary),
    );
  }

  /// From one live [AgentActivityEvent].
  factory AgentStepData.fromLiveEvent(
    AgentActivityEvent event, {
    required AgentStepStatus status,
  }) {
    return AgentStepData(
      toolCallId: event.toolCallId ?? '',
      toolName: event.toolName ?? 'tool',
      args: event.args ?? const {},
      summary: event.summary,
      durationMs: event.durationMs,
      round: event.round,
      kind: kindForTool(event.toolName),
      status: status,
    );
  }

  /// Success -> success; recorded skips -> skipped; anything else -> failed.
  static AgentStepStatus statusForResult({
    required bool success,
    String? summary,
  }) {
    if (success) return AgentStepStatus.success;
    final text = summary?.toLowerCase() ?? '';
    if (text.contains('skip')) return AgentStepStatus.skipped;
    return AgentStepStatus.failed;
  }

  /// Read tools answer from ground truth; unknown tools default to edit so
  /// the UI treats them with edit-level caution (matches the state layer).
  static ChatStepKind kindForTool(String? toolName) {
    if (toolName == null) return ChatStepKind.edit;
    for (final def in ToolRegistry.defaultDefinitions()) {
      if (def.name == toolName) {
        return def.category == ToolCategory.read
            ? ChatStepKind.read
            : ChatStepKind.edit;
      }
    }
    return ChatStepKind.edit;
  }

  AgentStepData copyWith({
    String? summary,
    int? durationMs,
    AgentStepStatus? status,
  }) {
    return AgentStepData(
      toolCallId: toolCallId,
      toolName: toolName,
      args: args,
      summary: summary ?? this.summary,
      durationMs: durationMs ?? this.durationMs,
      round: round,
      kind: kind,
      status: status ?? this.status,
    );
  }
}

/// Pure pairing: [AgentActivityKind.toolCallStarted] events paired with
/// their completed/failed follow-ups by toolCallId, into in-flight step
/// rows in execution order. Unpaired starts stay `running`; completions
/// without a start are created as finished rows (defensive).
List<AgentStepData> deriveLiveSteps(List<AgentActivityEvent> events) {
  final steps = <String, AgentStepData>{};
  final order = <String>[];
  for (final event in events) {
    switch (event.kind) {
      case AgentActivityKind.toolCallStarted:
        final id = event.toolCallId ?? '';
        if (!steps.containsKey(id)) order.add(id);
        steps[id] = AgentStepData.fromLiveEvent(
          event,
          status: AgentStepStatus.running,
        );
      case AgentActivityKind.toolCallCompleted:
      case AgentActivityKind.toolCallFailed:
        final id = event.toolCallId ?? '';
        if (!steps.containsKey(id)) order.add(id);
        steps[id] = (steps[id] ??
                AgentStepData.fromLiveEvent(
                  event,
                  status: AgentStepStatus.failed,
                ))
            .copyWith(
          summary: event.summary,
          durationMs: event.durationMs,
          status: AgentStepData.statusForResult(
            success: event.kind == AgentActivityKind.toolCallCompleted &&
                (event.success ?? true),
            summary: event.summary,
          ),
        );
      default:
        break;
    }
  }
  return [for (final id in order) steps[id]!];
}

/// Human-readable args for one tool call, e.g. `trim_clip {start, end}` ->
/// "00:00:00.000 → 00:00:15.000". Falls back to generic key=value pairs.
class AgentStepLabel {
  AgentStepLabel._();

  static String format(String toolName, Map<String, dynamic> args) {
    switch (toolName) {
      case 'trim_clip':
      case 'cut_segment':
        final start = (args['start'] ?? args['remove_start'])?.toString();
        final end = (args['end'] ?? args['remove_end'])?.toString();
        if (start != null && end != null) return '$start → $end';
      case 'change_speed':
      case 'change_volume':
        final factor = args['factor'];
        if (factor is num) return '$factor×';
      case 'overlay_text':
        final text = args['text']?.toString();
        if (text != null) {
          final position = args['position']?.toString();
          if (position == null || position.isEmpty) return '"$text"';
          return '"$text" · $position';
        }
      case 'probe_video':
      case 'mute_clip':
        final clipId = args['clip_id']?.toString();
        if (clipId != null) return clipId;
      case 'merge_clips':
        final clipIds = args['clip_ids'];
        if (clipIds is List && clipIds.isNotEmpty) return clipIds.join(' + ');
    }
    return _generic(args);
  }

  /// Generic fallback: "key=value" pairs, nulls dropped, ' · ' separated.
  static String _generic(Map<String, dynamic> args) {
    if (args.isEmpty) return '';
    return args.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' · ');
  }
}

/// One tool-call step row: status icon, tool-kind icon, name, formatted
/// args, summary and duration. Compact — fits the ~340px panel.
class AgentStepRow extends StatelessWidget {
  const AgentStepRow({super.key, required this.step});

  final AgentStepData step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = step.kind == ChatStepKind.read;
    final duration = step.durationMs == null ? null : _formatMs(step.durationMs!);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusIcon(step.status),
          const SizedBox(width: 6),
          _kindIcon(isRead),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        step.toolName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ClipMindColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (duration != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        duration,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ClipMindColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                for (final line in _detailLines(isRead)) ...[
                  const SizedBox(height: 2),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isRead
                          ? ClipMindColors.textMuted
                          : ClipMindColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Detail lines: formatted args and, when it adds information, the
  /// result summary. Read tools show their summary.
  List<String> _detailLines(bool isRead) {
    final args = AgentStepLabel.format(step.toolName, step.args);
    final summary = step.summary ?? '';
    final lines = <String>[];
    if (isRead) {
      if (summary.isNotEmpty) lines.add(summary);
    } else if (args.isNotEmpty) {
      lines.add(args);
      if (summary.isNotEmpty && summary != args) lines.add(summary);
    } else if (summary.isNotEmpty) {
      lines.add(summary);
    }
    return lines;
  }

  Widget _statusIcon(AgentStepStatus status) {
    switch (status) {
      case AgentStepStatus.running:
        return const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: ClipMindColors.accentPrimary,
          ),
        );
      case AgentStepStatus.success:
        return const Icon(
          Icons.check_rounded,
          size: 12,
          color: ClipMindColors.statusReady,
        );
      case AgentStepStatus.failed:
        return const Icon(
          Icons.close_rounded,
          size: 12,
          color: ClipMindColors.statusError,
        );
      case AgentStepStatus.skipped:
        return const Icon(
          Icons.close_rounded,
          size: 12,
          color: ClipMindColors.textMuted,
        );
    }
  }

  /// Read tools (info/search) are visually distinct from edit tools
  /// (wrench) with a subtle tint: the user sees the model reading too.
  Widget _kindIcon(bool isRead) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isRead ? ClipMindColors.bgElevated : ClipMindColors.accentSoft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        isRead ? Icons.manage_search : Icons.build_rounded,
        size: 11,
        color: isRead ? ClipMindColors.textMuted : ClipMindColors.accentPrimary,
      ),
    );
  }

  String _formatMs(int ms) {
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }
}

/// Live pipeline view over [agentActivityFeedProvider]: run header with a
/// status chip and round progress, then every tool call in order with a
/// distinct confirmation state. The cancel button stays with the panel.
class AgentLivePipelineView extends ConsumerStatefulWidget {
  const AgentLivePipelineView({super.key, this.confirmation});

  /// Non-null while a confirmation gate has paused the run; rendered as a
  /// distinct "waiting" chip in the header.
  final ConfirmationRequest? confirmation;

  @override
  ConsumerState<AgentLivePipelineView> createState() =>
      _AgentLivePipelineViewState();
}

class _AgentLivePipelineViewState extends ConsumerState<AgentLivePipelineView> {
  final _scroll = ScrollController();

  static const _stepsMaxHeight = 220.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feed = ref.watch(agentActivityFeedProvider);
    final steps = deriveLiveSteps(feed);
    final paused = widget.confirmation != null;

    // Jump to the newest step whenever a new event arrives.
    ref.listen(agentActivityFeedProvider, (previous, next) {
      if ((previous?.length ?? 0) < next.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    });

    return Container(
      key: const ValueKey('agent-live-pipeline'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ClipMindColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _statusChip(paused),
              const Spacer(),
              Text(
                'Round ${_currentRound(feed)}/${ToolRegistry.maxToolRounds}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ClipMindColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (steps.isEmpty)
            Text(
              paused
                  ? 'Waiting for your approval…'
                  : 'Waiting for the first step…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: ClipMindColors.textMuted,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _stepsMaxHeight),
              child: SingleChildScrollView(
                controller: _scroll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final step in steps) AgentStepRow(step: step),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(bool paused) {
    final label = paused ? 'Waiting for your approval' : 'AI is editing';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: paused
            ? ClipMindColors.statusWarning.withValues(alpha: 0.15)
            : ClipMindColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: paused
                  ? ClipMindColors.statusWarning
                  : ClipMindColors.accentPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: paused
                  ? ClipMindColors.statusWarning
                  : ClipMindColors.accentPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Highest observed round from the events (1 before any event). Max wins
  /// so out-of-order or interleaved events can't regress the display.
  int _currentRound(List<AgentActivityEvent> events) {
    var round = 1;
    for (final event in events) {
      if (event.round > round) round = event.round;
    }
    return round;
  }
}
