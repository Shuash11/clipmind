import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class LeftToolRail extends StatelessWidget {
  const LeftToolRail({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: ClipMindColors.bgSurface,
        border: Border(right: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Column(
        children: [
          _ToolIcon(icon: Icons.movie_outlined, label: 'Media'),
          _ToolIcon(icon: Icons.text_fields, label: 'Text'),
          _ToolIcon(icon: Icons.audiotrack_outlined, label: 'Audio'),
          _ToolIcon(icon: Icons.auto_fix_high_outlined, label: 'Effects'),
          _ToolIcon(icon: Icons.blur_on_outlined, label: 'Transitions'),
          _ToolIcon(icon: Icons.tune, label: 'Adjustments'),
          _ToolIcon(icon: Icons.file_download_outlined, label: 'Export'),
        ],
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ToolIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Tooltip(
        message: label,
        child: Icon(icon, size: 20, color: ClipMindColors.textSecondary),
      ),
    );
  }
}
