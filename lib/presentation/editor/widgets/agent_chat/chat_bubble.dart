import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == ChatRole.user;
    final bgColor = isUser
        ? ClipMindColors.accentPrimary.withValues(alpha: 0.15)
        : ClipMindColors.surfaceCard;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: ClipMindColors.accentPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.auto_awesome, size: 14, color: ClipMindColors.accentPrimary),
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
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _statusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.thinking:
        return SizedBox(
          width: 10, height: 10,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: ClipMindColors.statusWarning),
        );
      case MessageStatus.needsClarification:
        return Icon(Icons.help_outline, size: 12, color: ClipMindColors.statusWarning);
      case MessageStatus.error:
        return Icon(Icons.error_outline, size: 12, color: ClipMindColors.statusError);
      default:
        return const SizedBox.shrink();
    }
  }

  Color _statusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.thinking: return ClipMindColors.statusWarning;
      case MessageStatus.needsClarification: return ClipMindColors.statusWarning;
      case MessageStatus.error: return ClipMindColors.statusError;
      default: return ClipMindColors.textMuted;
    }
  }

  String _statusLabel(MessageStatus status) {
    switch (status) {
      case MessageStatus.thinking: return 'Thinking...';
      case MessageStatus.needsClarification: return 'Needs clarification';
      case MessageStatus.error: return 'Error';
      default: return '';
    }
  }
}
