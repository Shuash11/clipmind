import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class ImportSourceCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String source;
  final String subtitle;
  final VoidCallback? onTap;

  const ImportSourceCard({
    super.key,
    required this.icon,
    required this.label,
    required this.source,
    required this.subtitle,
    this.onTap,
  });

  @override
  State<ImportSourceCard> createState() => _ImportSourceCardState();
}

class _ImportSourceCardState extends State<ImportSourceCard> {
  bool _isHovering = false;

  Color get _accent {
    switch (widget.source) {
      case 'youtube':
        return const Color(0xFFFF5C6C);
      case 'gdrive':
        return const Color(0xFF35C779);
      default:
        return ClipMindColors.accentPrimary;
    }
  }

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
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              height: 126,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isHovering
                    ? ClipMindColors.surfaceHover
                    : ClipMindColors.surfaceCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isHovering
                      ? _accent.withValues(alpha: 0.65)
                      : ClipMindColors.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, size: 22, color: _accent),
                  ),
                  const Spacer(),
                  Text(
                    widget.label,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
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
    );
  }
}
