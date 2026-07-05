import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class ModelSelectorDropdown extends StatelessWidget {
  const ModelSelectorDropdown({super.key});

  void _showModelPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.psychology),
            title: const Text('Claude (Anthropic)'),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('GPT-4o (OpenAI)'),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Gemini (Google)'),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('NVIDIA NIM'),
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showModelPicker(context),
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
            const Icon(Icons.memory, size: 12, color: ClipMindColors.textSecondary),
            const SizedBox(width: 4),
            Text('Flash', style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
            )),
            const Icon(Icons.arrow_drop_down, size: 14, color: ClipMindColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
