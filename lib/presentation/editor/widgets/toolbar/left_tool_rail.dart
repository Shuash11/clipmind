import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/presentation/shared_widgets/export_dialog.dart';
import 'package:clipmind/state/project_providers.dart';

class LeftToolRail extends ConsumerStatefulWidget {
  const LeftToolRail({super.key});

  @override
  ConsumerState<LeftToolRail> createState() => _LeftToolRailState();
}

class _LeftToolRailState extends ConsumerState<LeftToolRail> {
  static const _tools = [
    _ToolItem(icon: Icons.movie_outlined, label: 'Media'),
    _ToolItem(icon: Icons.text_fields_rounded, label: 'Text'),
    _ToolItem(icon: Icons.graphic_eq_rounded, label: 'Audio'),
    _ToolItem(icon: Icons.auto_fix_high_outlined, label: 'Effects'),
    _ToolItem(icon: Icons.blur_on_outlined, label: 'Transitions'),
    _ToolItem(icon: Icons.tune_rounded, label: 'Adjustments'),
    _ToolItem(icon: Icons.file_download_outlined, label: 'Export'),
  ];

  int _selectedIndex = 0;

  void _selectTool(int index) {
    setState(() => _selectedIndex = index);
    final tool = _tools[index];
    if (tool.label == 'Export') {
      final project = ref.read(projectProvider).valueOrNull;
      if (project == null) {
        _showMessage('Open a project before exporting.');
        return;
      }
      showDialog<void>(
        context: context,
        builder: (ctx) => ExportDialog(project: project),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: ClipMindColors.bgSurface,
        border: Border.all(color: ClipMindColors.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _tools.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final tool = _tools[index];
          return _ToolButton(
            icon: tool.icon,
            label: tool.label,
            selected: index == _selectedIndex,
            onPressed: () => _selectTool(index),
          );
        },
      ),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String label;

  const _ToolItem({required this.icon, required this.label});
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? ClipMindColors.accentPrimary.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? ClipMindColors.accentPrimary.withValues(alpha: 0.28)
                    : Colors.transparent,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (selected)
                  Positioned(
                    left: 0,
                    top: 10,
                    bottom: 10,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: ClipMindColors.accentPrimary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? ClipMindColors.accentPrimary
                      : ClipMindColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
