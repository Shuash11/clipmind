import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(
        color: ClipMindColors.bgSurface,
        border: Border(top: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Row(
        children: [
          const _StatusDot(color: ClipMindColors.statusReady),
          const SizedBox(width: 6),
          Text('Ready', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(width: 16),
          const _StatusDot(color: ClipMindColors.statusReady),
          const SizedBox(width: 6),
          Text('Flash · connected', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(width: 16),
          const _StatusDot(color: ClipMindColors.statusReady),
          const SizedBox(width: 6),
          Text('FFmpeg ready', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
        ],
      ),
    );
  }
}
