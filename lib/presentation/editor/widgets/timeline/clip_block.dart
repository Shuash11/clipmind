import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class ClipBlock extends StatelessWidget {
  final Color color;
  final String label;
  final String durationLabel;
  final double width;
  final bool selected;
  final bool muted;
  final VoidCallback? onTap;

  const ClipBlock({
    super.key,
    required this.color,
    required this.label,
    required this.durationLabel,
    this.width = 120,
    this.selected = false,
    this.muted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = muted
        ? ClipMindColors.textMuted
        : ClipMindColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Tooltip(
        message: '$label - $durationLabel',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              width: width,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.34 : 0.20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected
                      ? ClipMindColors.textPrimary
                      : color.withValues(alpha: 0.66),
                  width: selected ? 1.6 : 1,
                ),
                boxShadow: [
                  if (selected)
                    BoxShadow(
                      color: color.withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    durationLabel,
                    style: const TextStyle(
                      color: ClipMindColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
