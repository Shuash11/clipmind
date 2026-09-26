import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class SuggestedPromptChip extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  const SuggestedPromptChip({super.key, required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      label: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: ClipMindColors.accentPrimary,
          fontSize: 11,
        ),
      ),
      backgroundColor: ClipMindColors.accentPrimary.withValues(alpha: 0.08),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
