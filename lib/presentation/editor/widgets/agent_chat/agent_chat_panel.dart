import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'chat_bubble.dart';
import 'suggested_prompt_chip.dart';
import 'model_selector_dropdown.dart';

class AgentChatPanel extends ConsumerWidget {
  const AgentChatPanel({super.key});

  static const List<String> suggestedPrompts = [
    'Cut out the first 5 seconds',
    'Add subtitles from speech',
    'Make a highlight reel',
    'Trim to 30 seconds',
    'Add intro text',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final messages = ref.watch(chatMessagesProvider);

    return Container(
      decoration: BoxDecoration(
        color: ClipMindColors.bgSurface,
        border: Border(left: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ClipMindColors.borderColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: ClipMindColors.accentPrimary),
                const SizedBox(width: 8),
                Text('AI Assistant', style: theme.textTheme.titleMedium),
                const Spacer(),
                const ModelSelectorDropdown(),
              ],
            ),
          ),
          // Suggested prompts (only if no messages)
          if (messages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestedPrompts
                    .map((p) => SuggestedPromptChip(text: p))
                    .toList(),
              ),
            ),
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(message: messages[index]);
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ClipMindColors.borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Type a command...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10,
                      ),
                    ),
                    maxLines: 1,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: ClipMindColors.accentPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
