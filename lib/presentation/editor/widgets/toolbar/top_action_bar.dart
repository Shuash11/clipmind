import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';
import 'package:clipmind/presentation/shared_widgets/export_dialog.dart';

class TopActionBar extends ConsumerWidget {
  const TopActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final undoRedoState = ref.watch(undoRedoProvider);
    final projectAsync = ref.watch(projectProvider);
    final project = projectAsync.valueOrNull;
    final projectTitle = project?.name ?? 'Untitled project';

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: ClipMindColors.bgBase,
        border: Border(bottom: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Project hub',
            child: IconButton(
              icon: const Icon(Icons.home_outlined, size: 20),
              onPressed: () => context.go(projectHubPath),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 26, color: ClipMindColors.borderColor),
          const SizedBox(width: 8),
          _ChromeIconButton(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            enabled: undoRedoState.canUndo,
            onPressed: () => ref.read(undoRedoProvider.notifier).undo(),
          ),
          _ChromeIconButton(
            icon: Icons.redo_rounded,
            tooltip: 'Redo',
            enabled: undoRedoState.canRedo,
            onPressed: () => ref.read(undoRedoProvider.notifier).redo(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: ClipMindColors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.movie_filter_rounded,
                    size: 17,
                    color: ClipMindColors.accentPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        project == null
                            ? 'No project loaded'
                            : '${project.sourceMediaPaths.length} media source${project.sourceMediaPaths.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => context.go(settingsPath),
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Model'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: project != null
                ? () => _openExportDialog(context, project)
                : null,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _openExportDialog(BuildContext context, Project project) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ExportDialog(project: project),
    );
  }
}

class _ChromeIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  const _ChromeIconButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 19),
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}
