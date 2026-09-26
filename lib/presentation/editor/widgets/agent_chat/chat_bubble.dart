import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/chat_step.dart';

import 'agent_steps_view.dart';

/// One chat bubble. Agent bubbles with tool-call steps gain a collapsed
/// header ("N tool calls · M edits · Xs") that expands to per-step rows.
class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = widget.message;
    final isUser = message.role == ChatRole.user;
    final bgColor = isUser
        ? ClipMindColors.accentPrimary.withValues(alpha: 0.15)
        : ClipMindColors.surfaceCard;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: ClipMindColors.accentPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 14,
                color: ClipMindColors.accentPrimary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 13),
                  ),
                  if (message.status != MessageStatus.applied) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _statusIcon(message.status),
                        const SizedBox(width: 4),
                        Text(
                          _statusLabel(message.status),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _statusColor(message.status),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (message.steps.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _stepsHeader(theme, message.steps),
                    if (_expanded) ...[
                      const SizedBox(height: 4),
                      for (final step in message.steps)
                        AgentStepRow(step: AgentStepData.fromChatStep(step)),
                    ],
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Collapsed header: "N tool calls · M edits · Xs" + chevron.
  Widget _stepsHeader(ThemeData theme, List<ChatStep> steps) {
    final count = steps.length;
    final editCount = steps.where((s) => s.kind == ChatStepKind.edit).length;
    final totalMs = steps.fold<int>(0, (sum, s) => sum + s.durationMs);
    return GestureDetector(
      key: const ValueKey('agent-steps-header'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Row(
        children: [
          Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            size: 14,
            color: ClipMindColors.textMuted,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$count tool call${count == 1 ? '' : 's'}'
              ' · $editCount edit${editCount == 1 ? '' : 's'}'
              ' · ${_formatMs(totalMs)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ClipMindColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMs(int ms) {
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  Widget _statusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.thinking:
        return const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: ClipMindColors.statusWarning,
          ),
        );
      case MessageStatus.needsClarification:
        return const Icon(
          Icons.help_outline,
          size: 12,
          color: ClipMindColors.statusWarning,
        );
      case MessageStatus.error:
        return const Icon(
          Icons.error_outline,
          size: 12,
          color: ClipMindColors.statusError,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Color _statusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.thinking:
        return ClipMindColors.statusWarning;
      case MessageStatus.needsClarification:
        return ClipMindColors.statusWarning;
      case MessageStatus.error:
        return ClipMindColors.statusError;
      default:
        return ClipMindColors.textMuted;
    }
  }

  String _statusLabel(MessageStatus status) {
    switch (status) {
      case MessageStatus.thinking:
        return 'Thinking...';
      case MessageStatus.needsClarification:
        return 'Needs clarification';
      case MessageStatus.error:
        return 'Error';
      default:
        return '';
    }
  }
}
