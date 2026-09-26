import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/agent_activity.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/usecases/run_agent_command_usecase.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/player_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';

enum AgentRunState { idle, running, cancelled }

/// Single wiring point for agent runs (D3).
///
/// Centralizes what the panel did ad hoc: resolves the active provider,
/// reads project + ffprobe metadata, builds `recentHistory` from chat
/// messages (only real user content maps to `userCommand`), calls the use
/// case with a cancellation token, and attaches `resultingOperationIds`
/// to the agent's chat reply. The panel is a dumb view over this.
class AgentRunController extends StateNotifier<AgentRunState> {
  final Ref _ref;
  final Uuid _uuid = const Uuid();
  CancellationController? _cancel;
  StreamSubscription<AgentActivityEvent>? _feedSub;

  AgentRunController(this._ref) : super(AgentRunState.idle);

  bool get isBusy => state == AgentRunState.running;

  Future<void> submit(String command) async {
    final text = command.trim();
    if (text.isEmpty || isBusy) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: text,
      timestamp: DateTime.now(),
    );
    _ref.read(chatMessagesProvider.notifier).add(userMessage);
    final opened = _ref.read(projectProvider).valueOrNull;
    if (opened != null) {
      try {
        await _ref
            .read(appDatabaseProvider)
            .saveChatMessage(opened.id, userMessage);
      } catch (_) {}
    }

    state = AgentRunState.running;
    _ref.read(agentActivityFeedProvider.notifier).clear();
    final controller = CancellationController();
    _cancel = controller;
    _feedSub = _ref
        .read(nl2vecPipelineProvider)
        .agentActivity
        .listen(_ref.read(agentActivityFeedProvider.notifier).push);

    try {
      final project = _ref.read(projectProvider).valueOrNull;
      if (project == null) {
        await _replyError(
          null,
          'Open a project with a video file first.',
        );
        return;
      }

      VideoMetadata? metadata;
      try {
        metadata = await _ref.read(projectMetadataProvider.future);
      } catch (_) {
        metadata = null;
      }

      final provider =
          await _ref.read(providerRegistryProvider).getActiveProvider();
      if (provider == null) {
        await _replyError(
          project,
          'No LLM provider configured. Add an API key in Settings.',
        );
        return;
      }

      final useCase = RunAgentCommandUseCase(
        _ref.read(nl2vecPipelineProvider),
      );
      final snapshot = project;
      final result = await useCase.execute(
        text,
        snapshot,
        provider: provider,
        metadata: metadata,
        recentHistory: _recentHistory(),
        applier: _ref.read(agentEditApplierProvider),
        liveProject: () =>
            _ref.read(projectProvider).valueOrNull ?? snapshot,
        cancellation: controller.token,
      );

      final status = switch (result.status) {
        SubmitStatus.success => MessageStatus.applied,
        SubmitStatus.clarificationNeeded => MessageStatus.needsClarification,
        SubmitStatus.error || SubmitStatus.cancelled => MessageStatus.error,
      };
      final reply = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.agent,
        content: result.message,
        timestamp: DateTime.now(),
        status: status,
        resultingOperationIds: [
          for (final op in result.appliedOperations) op.id,
        ],
      );
      _ref.read(chatMessagesProvider.notifier).add(reply);
      try {
        await _ref.read(appDatabaseProvider).saveChatMessage(
              project.id,
              reply,
            );
      } catch (_) {}

      if (result.status == SubmitStatus.success &&
          result.outputPath != null) {
        _ref.read(currentVideoPathProvider.notifier).state =
            result.outputPath;
      }
    } finally {
      await _feedSub?.cancel();
      _feedSub = null;
      _cancel = null;
      if (state == AgentRunState.running) {
        state = AgentRunState.idle;
      }
    }
  }

  /// Stop further rounds/tool calls and kill a running FFmpeg job.
  /// Already-applied edits stay (undoable); nothing further starts.
  void cancel() {
    if (!isBusy) return;
    _cancel?.cancel();
    try {
      _ref.read(ffmpegServiceProvider).cancel();
    } catch (_) {}
    state = AgentRunState.cancelled;
  }

  List<AgentRequest> _recentHistory() {
    final messages = _ref.read(chatMessagesProvider);
    return messages.reversed.take(3).map((m) {
      if (m.role == ChatRole.user) {
        return AgentRequest(
          systemPrompt: '',
          userCommand: m.content,
          schemaJson: '',
          timeoutSeconds: 30,
        );
      }
      return AgentRequest(
        systemPrompt: m.content,
        userCommand: '',
        schemaJson: '',
        timeoutSeconds: 30,
      );
    }).toList();
  }

  Future<void> _replyError(Project? project, String text) async {
    final reply = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.agent,
      content: text,
      timestamp: DateTime.now(),
      status: MessageStatus.error,
    );
    _ref.read(chatMessagesProvider.notifier).add(reply);
    if (project != null) {
      try {
        await _ref.read(appDatabaseProvider).saveChatMessage(
              project.id,
              reply,
            );
      } catch (_) {}
    }
  }
}

final agentRunControllerProvider =
    StateNotifierProvider<AgentRunController, AgentRunState>(
  (ref) => AgentRunController(ref),
);

/// Raw agent activity stream (Phase-4 seed): the pipeline forwards the
/// per-run agent's events here.
final agentActivityProvider = StreamProvider<AgentActivityEvent>((ref) {
  return ref.watch(nl2vecPipelineProvider).agentActivity;
});

/// Compact rolling feed of activity events for the inline panel view.
class AgentActivityFeed extends StateNotifier<List<AgentActivityEvent>> {
  static const int maxEvents = 20;

  AgentActivityFeed() : super(const []);

  void push(AgentActivityEvent event) {
    final next = [...state, event];
    state = next.length > maxEvents
        ? next.sublist(next.length - maxEvents)
        : next;
  }

  void clear() {
    state = const [];
  }
}

final agentActivityFeedProvider =
    StateNotifierProvider<AgentActivityFeed, List<AgentActivityEvent>>(
  (ref) => AgentActivityFeed(),
);
