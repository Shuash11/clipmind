import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: ClipMindColors.bgBase,
        border:
            Border(bottom: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.undo, size: 18),
            onPressed: undoRedoState.canUndo
                ? () => ref.read(undoRedoProvider.notifier).undo()
                : null,
            tooltip: 'Undo',
            color: undoRedoState.canUndo
                ? ClipMindColors.textPrimary
                : ClipMindColors.textMuted,
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 18),
            onPressed: undoRedoState.canRedo
                ? () => ref.read(undoRedoProvider.notifier).redo()
                : null,
            tooltip: 'Redo',
            color: undoRedoState.canRedo
                ? ClipMindColors.textPrimary
                : ClipMindColors.textMuted,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => const AlertDialog(
                title: Text('Select Model'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(title: Text('Claude (Anthropic)'), leading: Icon(Icons.psychology)),
                    ListTile(title: Text('GPT-4o (OpenAI)'), leading: Icon(Icons.smart_toy)),
                    ListTile(title: Text('Gemini (Google)'), leading: Icon(Icons.auto_awesome)),
                    ListTile(title: Text('NVIDIA NIM'), leading: Icon(Icons.memory)),
                  ],
                ),
              ),
            ),
            icon: const Icon(Icons.tune,
                size: 14, color: ClipMindColors.textSecondary),
            label: const Text('Model',
                style: TextStyle(
                    color: ClipMindColors.textSecondary, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: project != null
                ? () => _openExportDialog(context, project)
                : null,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Export', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: ClipMindColors.accentPrimary,
            ),
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
