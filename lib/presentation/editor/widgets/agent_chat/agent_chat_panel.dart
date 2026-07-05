import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/project.dart' as project_model;
import 'chat_bubble.dart';
import 'suggested_prompt_chip.dart';
import 'model_selector_dropdown.dart';

class AgentChatPanel extends ConsumerStatefulWidget {
  const AgentChatPanel({super.key});

  static const List<String> suggestedPrompts = [
    'Cut out the first 5 seconds',
    'Add subtitles from speech',
    'Make a highlight reel',
    'Trim to 30 seconds',
    'Add intro text',
  ];

  @override
  ConsumerState<AgentChatPanel> createState() => _AgentChatPanelState();
}

class _AgentChatPanelState extends ConsumerState<AgentChatPanel> {
  final _controller = TextEditingController();
  final _uuid = const Uuid();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    ref.read(chatMessagesProvider.notifier).add(ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
    ));

    _controller.clear();
    setState(() => _isLoading = true);

    try {
      final project = ref.read(projectProvider).valueOrNull;
      final snapshot = project != null
          ? _projectToSnapshot(project)
          : _emptySnapshot();

      final registry = ref.read(providerRegistryProvider);
      final provider = await registry.getActiveProvider();

      if (provider == null) {
        ref.read(chatMessagesProvider.notifier).add(ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.agent,
          content: 'No LLM provider configured. Add an API key in Settings.',
          timestamp: DateTime.now(),
          status: MessageStatus.error,
        ));
        return;
      }

      final pipeline = ref.read(nl2vecPipelineProvider);
      final result = await pipeline.submitCommand(trimmed, snapshot, provider: provider);

      final isError = result.startsWith('Error:');
      ref.read(chatMessagesProvider.notifier).add(ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.agent,
        content: isError ? result.replaceFirst('Error: ', '') : result,
        timestamp: DateTime.now(),
        status: isError ? MessageStatus.error : MessageStatus.applied,
      ));
    } catch (e) {
      ref.read(chatMessagesProvider.notifier).add(ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.agent,
        content: 'Unexpected error: $e',
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ProjectSnapshot _projectToSnapshot(project_model.Project project) {
    final clipSnapshots = <ClipSnapshot>[];
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        clipSnapshots.add(ClipSnapshot(
          id: clip.id,
          trackId: clip.trackId,
          label: clip.label ?? clip.id,
          startMs: clip.startMs,
          endMs: clip.endMs,
          positionMs: clip.positionMs,
        ));
      }
    }
    return ProjectSnapshot(
      durationMs: project.durationMs,
      width: 1920,
      height: 1080,
      fps: 30.0,
      codec: 'h264',
      hasAudio: true,
      clips: clipSnapshots,
    );
  }

  ProjectSnapshot _emptySnapshot() {
    return const ProjectSnapshot(
      durationMs: 0,
      width: 1920,
      height: 1080,
      fps: 30.0,
      codec: 'h264',
      hasAudio: true,
      clips: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = ref.watch(chatMessagesProvider);

    return Container(
      decoration: const BoxDecoration(
        color: ClipMindColors.bgSurface,
        border: Border(left: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: ClipMindColors.borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: ClipMindColors.accentPrimary),
                const SizedBox(width: 8),
                Text('AI Assistant', style: theme.textTheme.titleMedium),
                const Spacer(),
                const ModelSelectorDropdown(),
              ],
            ),
          ),
          // Suggested prompts (only if no messages and not loading)
          if (messages.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: AgentChatPanel.suggestedPrompts
                    .map((String p) => SuggestedPromptChip(
                      text: p,
                      onPressed: _isLoading ? null : () => _submitPrompt(p),
                    ))
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
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: ClipMindColors.borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: _isLoading ? 'Processing...' : 'Type a command...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10,
                      ),
                    ),
                    maxLines: 1,
                    style: theme.textTheme.bodyLarge,
                    onSubmitted: _isLoading ? null : (value) => _submitPrompt(value),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _isLoading
                        ? ClipMindColors.textMuted
                        : ClipMindColors.accentPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isLoading
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
                          icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
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
