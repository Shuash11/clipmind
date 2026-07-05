import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class ImportSourceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String source;
  final VoidCallback? onTap;

  const ImportSourceCard({
    super.key,
    required this.icon,
    required this.label,
    required this.source,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: ClipMindColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ClipMindColors.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: ClipMindColors.accentPrimary),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
