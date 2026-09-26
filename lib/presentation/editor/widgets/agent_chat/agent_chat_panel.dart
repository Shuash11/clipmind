import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/player_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'chat_bubble.dart';
import 'suggested_prompt_chip.dart';
import 'model_selector_dropdown.dart';

/// Map a typed pipeline result to a chat message status.
///
/// No string-matching on message text; the domain returns [SubmitStatus].
MessageStatus messageStatusForSubmit(SubmitStatus status) {
  switch (status) {
    case SubmitStatus.success:
      return MessageStatus.applied;
    case SubmitStatus.clarificationNeeded:
      return MessageStatus.needsClarification;
    case SubmitStatus.error:
      return MessageStatus.error;
  }
}

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

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
    );
    ref.read(chatMessagesProvider.notifier).add(userMessage);

    final project = ref.read(projectProvider).valueOrNull;
    if (project != null) {
      try {
        await ref.read(appDatabaseProvider).saveChatMessage(
              project.id,
              userMessage,
            );
      } catch (_) {
        // Chat persistence is best-effort for Phase 1.
      }
    }

    _controller.clear();
    setState(() => _isLoading = true);

    try {
      final currentProject = ref.read(projectProvider).valueOrNull;
      if (currentProject == null) {
        ref.read(chatMessagesProvider.notifier).addAgentResult(
              id: _uuid.v4(),
              content: 'Open a project with a video file first.',
              status: MessageStatus.error,
            );
        return;
      }

      // Real ffprobe metadata (cached); null means unverified defaults.
      VideoMetadata? metadata;
      try {
        metadata = await ref.read(projectMetadataProvider.future);
      } catch (_) {
        metadata = null;
      }

      final registry = ref.read(providerRegistryProvider);
      final provider = await registry.getActiveProvider();

      if (provider == null) {
        ref.read(chatMessagesProvider.notifier).addAgentResult(
              id: _uuid.v4(),
              content: 'No LLM provider configured. Add an API key in Settings.',
              status: MessageStatus.error,
            );
        return;
      }

      // Last 3 messages give the LLM conversational context.
      final history = ref.read(chatMessagesProvider);
      final recentHistory = history.reversed.take(3).map((m) {
        return AgentRequest(
          systemPrompt: m.content,
          userCommand: m.content,
          schemaJson: '',
          timeoutSeconds: 30,
        );
      }).toList();

      final pipeline = ref.read(nl2vecPipelineProvider);
      final applier = ref.read(agentEditApplierProvider);
      final result = await pipeline.submitCommand(
        trimmed,
        currentProject,
        provider: provider,
        metadata: metadata,
        recentHistory: recentHistory,
        applier: applier,
      );

      final status = messageStatusForSubmit(result.status);
      final operationIds =
          result.appliedOperations.map((op) => op.id).toList();

      final agentMessage = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.agent,
        content: result.message,
        timestamp: DateTime.now(),
        status: status,
        resultingOperationIds: operationIds,
      );
      ref.read(chatMessagesProvider.notifier).add(agentMessage);
      try {
        await ref.read(appDatabaseProvider).saveChatMessage(
              currentProject.id,
              agentMessage,
            );
      } catch (_) {}

      // Timeline already re-rendered via ProjectNotifier.applyEdit;
      // point the preview at the new output file immediately.
      if (result.status == SubmitStatus.success &&
          result.outputPath != null) {
        ref.read(currentVideoPathProvider.notifier).state = result.outputPath;
      }
    } catch (_) {
      ref.read(chatMessagesProvider.notifier).addAgentResult(
            id: _uuid.v4(),
            content:
                'Something went wrong while processing that command. Check provider settings and try again.',
            status: MessageStatus.error,
          );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          // Suggested prompts (only if no messages and not loading)
          if (messages.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: AgentChatPanel.suggestedPrompts
                    .map(
                      (String p) => SuggestedPromptChip(
                        text: p,
                        onPressed: _isLoading ? null : () => _submitPrompt(p),
                      ),
                    )
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
              border: Border(
                top: BorderSide(color: ClipMindColors.borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: _isLoading
                          ? 'Processing...'
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
                    onSubmitted: _isLoading
                        ? null
                        : (value) => _submitPrompt(value),
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
