import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/domain/agent/agent_confirmation.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agent_steps_view.dart';
import 'chat_bubble.dart';
import 'model_selector_dropdown.dart';
import 'suggested_prompt_chip.dart';

/// Dumb view over [AgentRunController]: submits commands, shows busy/cancel
/// state, the live tool-call pipeline and the confirmation bar. All run
/// logic lives in state.
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

  @override
  void initState() {
    super.initState();
    // Restore persisted chat history (with steps) for the open project.
    final projectId = ref.read(projectProvider).valueOrNull?.id;
    if (projectId != null) {
      ref.read(agentRunControllerProvider.notifier).loadHistory(projectId);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _controller.clear();
    await ref.read(agentRunControllerProvider.notifier).submit(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = ref.watch(chatMessagesProvider);
    final runState = ref.watch(agentRunControllerProvider);
    final isBusy = runState == AgentRunState.running;
    final pending = ref.watch(pendingConfirmationProvider);

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
                // Scale-down fit: the selector shrinks instead of
                // overflowing the ~340px panel when the label is long.
                const Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ModelSelectorDropdown(),
                  ),
                ),
              ],
            ),
          ),
          if (messages.isEmpty && !isBusy)
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
                if (isBusy) const AgentLivePipelineView(),
              ],
            ),
          ),
          if (pending != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _ConfirmBar(
                request: pending,
                onAnswer: (approved) => ref
                    .read(agentRunControllerProvider.notifier)
                    .approvePendingConfirmation(approved),
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
                      hintText: isBusy ? 'Working...' : 'Type a command...',
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
                if (isBusy) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: ClipMindColors.textMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const SizedBox(
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: ClipMindColors.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ClipMindColors.borderColor,
                      ),
                    ),
                    child: IconButton(
                      key: const ValueKey('agent-run-cancel'),
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      tooltip: 'Cancel run',
                      onPressed: () => ref
                          .read(agentRunControllerProvider.notifier)
                          .cancel(),
                    ),
                  ),
                ] else
                  Container(
                    decoration: BoxDecoration(
                      color: ClipMindColors.accentPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
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

/// In-panel confirmation bar for a paused round: question + answer buttons.
/// True = approve (bulk: Approve, per-edit: Allow); false = skip/deny.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.request, required this.onAnswer});

  final ConfirmationRequest request;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBulk = request.kind == ConfirmationKind.bulk;
    final count = request.toolCalls.length;
    final toolName = request.toolCalls.isEmpty
        ? 'tool'
        : request.toolCalls.first.name;
    final question = isBulk
        ? 'The AI plans to apply $count edit${count == 1 ? '' : 's'} — Continue?'
        : 'The AI wants to run $toolName — Allow?';

    return Container(
      key: const ValueKey('agent-confirm-bar'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClipMindColors.statusWarning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ClipMindColors.statusWarning.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pause_circle_outline,
                size: 14,
                color: ClipMindColors.statusWarning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  question,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ClipMindColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ClipMindColors.accentPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton(
                    key: ValueKey(
                      isBulk ? 'agent-confirm-approve' : 'agent-confirm-allow',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: ClipMindColors.bgBase,
                    ),
                    onPressed: () => onAnswer(true),
                    child: Text(isBulk ? 'Approve' : 'Allow'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: ValueKey(
                    isBulk ? 'agent-confirm-skip' : 'agent-confirm-deny',
                  ),
                  onPressed: () => onAnswer(false),
                  child: Text(isBulk ? 'Skip' : 'Deny'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
