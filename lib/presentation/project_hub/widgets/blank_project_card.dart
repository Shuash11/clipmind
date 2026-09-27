import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/presentation/shared_widgets/dashed_border.dart';

/// First card in the recent-projects row: dashed outline, plus icon,
/// creates a new empty project (the repository supports empty media).
class BlankProjectCard extends StatefulWidget {
  final VoidCallback? onTap;

  const BlankProjectCard({super.key, this.onTap});

  @override
  State<BlankProjectCard> createState() => _BlankProjectCardState();
}

class _BlankProjectCardState extends State<BlankProjectCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.015 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: DashedBorder(
              color: _isHovering
                  ? ClipMindColors.accentPrimary.withValues(alpha: 0.7)
                  : ClipMindColors.borderColor,
              radius: 14,
              child: Container(
                width: 224,
                height: 214,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isHovering
                      ? ClipMindColors.surfaceHover
                      : ClipMindColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: ClipMindColors.accentPrimary.withValues(
                          alpha: _isHovering ? 0.18 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: ClipMindColors.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Blank project',
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start with an empty timeline',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
