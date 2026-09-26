import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_providers.dart';
import 'package:clipmind/features/agent/presentation/widgets/edit_plan_card.dart';
import 'package:clipmind/features/agent/presentation/widgets/revise_plan_dialog.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'chat_bubble.dart';
import 'model_selector_dropdown.dart';
import 'suggested_prompt_chip.dart';

class AgentChatPanel extends ConsumerStatefulWidget {
  const AgentChatPanel({super.key});

  static const List<String> suggestedPrompts = [
    'Cut out the first 5 seconds',
    'Trim this clip to 30 seconds',
    'Mute the selected clip',
    'Add an intro text overlay',
    'Adjust the selected clip brightness',
  ];

  @override
  ConsumerState<AgentChatPanel> createState() => _AgentChatPanelState();
}

class _AgentChatPanelState extends ConsumerState<AgentChatPanel> {
  final _controller = TextEditingController();
  final _uuid = const Uuid();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt(String text) async {
    final trimmed = text.trim();
    final editState = ref.read(editPlanNotifierProvider);
    if (trimmed.isEmpty || editState.isBusy) return;
    ref
        .read(chatMessagesProvider.notifier)
        .add(
          ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.user,
            content: trimmed,
            timestamp: DateTime.now(),
          ),
        );
    _controller.clear();
    await ref.read(editPlanNotifierProvider.notifier).submit(trimmed);
  }

  void _showReviseDialog(String planId) {
    showDialog<void>(
      context: context,
      builder: (context) => RevisePlanDialog(
        onRevise: (instruction) {
          ref
              .read(editPlanNotifierProvider.notifier)
              .revise(planId, instruction);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = ref.watch(chatMessagesProvider);
    final editState = ref.watch(editPlanNotifierProvider);
    final isBusy = editState.isBusy;
    final plan = editState.plan;

    return Container(
      decoration: const BoxDecoration(
        color: ClipMindColors.bgSurface,
        border: Border(left: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ClipMindColors.borderColor),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: ClipMindColors.accentPrimary,
                ),
                const SizedBox(width: 8),
                Text('AI Assistant', style: theme.textTheme.titleMedium),
                const Spacer(),
                const ModelSelectorDropdown(),
              ],
            ),
          ),
          if (messages.isEmpty && plan == null && !isBusy)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: AgentChatPanel.suggestedPrompts
                    .map(
                      (prompt) => SuggestedPromptChip(
                        text: prompt,
                        onPressed: () => _submitPrompt(prompt),
                      ),
                    )
                    .toList(),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ...messages.map((message) => ChatBubble(message: message)),
                if (plan != null)
                  EditPlanCard(
                    plan: plan,
                    action: editState.action,
                    failureMessage: editState.failureMessage,
                    saveOutcome: editState.saveOutcome,
                    onApply: () {
                      ref
                          .read(editPlanNotifierProvider.notifier)
                          .apply(plan.id);
                    },
                    onCancel: () {
                      ref
                          .read(editPlanNotifierProvider.notifier)
                          .cancel(plan.id);
                    },
                    onRevise: () => _showReviseDialog(plan.id),
                  )
                else if (editState.failureMessage != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      editState.failureMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: ClipMindColors.statusWarning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: ClipMindColors.borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !isBusy,
                    decoration: InputDecoration(
                      hintText: isBusy
                          ? 'Preparing preview...'
                          : 'Type a command...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 1,
                    style: theme.textTheme.bodyLarge,
                    onSubmitted: isBusy ? null : _submitPrompt,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isBusy
                        ? ClipMindColors.textMuted
                        : ClipMindColors.accentPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isBusy
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: () => _submitPrompt(_controller.text),
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
