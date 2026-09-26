import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/domain/agent/agent_activity.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_bubble.dart';
import 'model_selector_dropdown.dart';
import 'suggested_prompt_chip.dart';

/// Dumb view over [AgentRunController]: submits commands, shows busy/cancel
/// state and a compact inline activity feed. All run logic lives in state.
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
    final feed = ref.watch(agentActivityFeedProvider);

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
                if (isBusy && feed.isNotEmpty)
                  _ActivityFeed(feed: feed),
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

/// Compact inline feed: tool name + status + duration while running.
class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.feed});

  final List<AgentActivityEvent> feed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = feed.length > 3 ? feed.sublist(feed.length - 3) : feed;
    return Container(
      key: const ValueKey('agent-activity-feed'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ClipMindColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in visible)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _label(event),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: event.kind == AgentActivityKind.toolCallFailed
                      ? ClipMindColors.statusWarning
                      : ClipMindColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _label(AgentActivityEvent event) {
    switch (event.kind) {
      case AgentActivityKind.runStarted:
        return 'Run started';
      case AgentActivityKind.llmRoundStarted:
        return 'Thinking (round ${event.round})…';
      case AgentActivityKind.llmRoundCompleted:
        return 'Round ${event.round} planned';
      case AgentActivityKind.toolCallStarted:
        return 'Running ${event.toolName ?? 'tool'}…';
      case AgentActivityKind.toolCallCompleted:
        final duration = event.durationMs != null
            ? ' · ${event.durationMs}ms'
            : '';
        return '${event.toolName ?? 'Tool'} done$duration';
      case AgentActivityKind.toolCallFailed:
        return '${event.toolName ?? 'Tool'} failed';
      case AgentActivityKind.runCompleted:
        return event.summary ?? 'Done';
      case AgentActivityKind.runFailed:
        return event.summary ?? 'Failed';
      case AgentActivityKind.runCancelled:
        return event.summary ?? 'Cancelled';
    }
  }
}
