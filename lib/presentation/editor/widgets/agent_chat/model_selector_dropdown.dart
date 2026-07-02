import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class ModelSelectorDropdown extends StatelessWidget {
  const ModelSelectorDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ClipMindColors.bgElevated,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.memory, size: 12, color: ClipMindColors.textSecondary),
            const SizedBox(width: 4),
            Text('Flash', style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
            )),
            Icon(Icons.arrow_drop_down, size: 14, color: ClipMindColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
