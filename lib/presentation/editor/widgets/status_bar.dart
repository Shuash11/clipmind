import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: ClipMindColors.bgBase,
        border: Border(top: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: const Row(
        children: [
          _StatusPill(color: ClipMindColors.statusReady, label: 'Ready'),
          SizedBox(width: 8),
          _StatusPill(color: ClipMindColors.statusReady, label: 'FFmpeg ready'),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ClipMindColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ClipMindColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
