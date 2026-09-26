import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/chat_step.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/agent_activity.dart';
import 'package:clipmind/domain/agent/agent_confirmation.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';
import 'package:clipmind/domain/usecases/run_agent_command_usecase.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/player_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';

enum AgentRunState { idle, running, cancelled }

/// Per-edit approval flag (readable config source for the gate).
///
/// `AppSettings` has no such field yet; the settings toggle (frontend)
/// will bind here. false = bulk-only mode (rounds with ≥3 edits pause).
final agentConfirmEditsProvider = StateProvider<bool>((ref) => false);

/// The confirmation request the agent is currently paused on, if any.
/// The UI renders it and answers via [AgentRunController.approvePendingConfirmation].
final pendingConfirmationProvider =
    StateNotifierProvider<PendingConfirmation, ConfirmationRequest?>(
  (ref) => PendingConfirmation(),
);

class PendingConfirmation extends StateNotifier<ConfirmationRequest?> {
  PendingConfirmation() : super(null);

  void set(ConfirmationRequest request) {
    state = request;
  }

  void clear() {
    state = null;
  }
}

/// State-layer [ConfirmationGate]: posts the request to
/// [pendingConfirmationProvider] and awaits the user's choice.
class AgentConfirmationGate implements ConfirmationGate {
  final Ref _ref;
  final bool perEdit;
  Completer<bool>? _completer;

  AgentConfirmationGate(this._ref, {required this.perEdit});

  @override
  bool get requiresPerEditApproval => perEdit;

  @override
  Future<bool> ask(ConfirmationRequest request) {
    final completer = Completer<bool>();
    _completer = completer;
    _ref.read(pendingConfirmationProvider.notifier).set(request);
    return completer.future.whenComplete(() {
      if (identical(_completer, completer)) {
        _completer = null;
        _ref.read(pendingConfirmationProvider.notifier).clear();
      }
    });
  }

  /// Complete a paused `ask` with [approved] (no-op when not paused).
  void resolve(bool approved) {
    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(approved);
    }
  }
}

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
  AgentConfirmationGate? _gate;

  AgentRunController(this._ref) : super(AgentRunState.idle);

  bool get isBusy => state == AgentRunState.running;

  /// Restore persisted chat history (with steps) for [projectId].
  /// Called by the UI on project open; replaces in-memory history.
  Future<void> loadHistory(String projectId) async {
    try {
      final messages =
          await _ref.read(appDatabaseProvider).getChatMessages(projectId);
      _ref.read(chatMessagesProvider.notifier).replaceAll(messages);
    } catch (_) {}
  }

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
      final gate = AgentConfirmationGate(
        _ref,
        perEdit: _ref.read(agentConfirmEditsProvider),
      );
      _gate = gate;
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
        gate: gate,
      );

      final status = switch (result.status) {
        SubmitStatus.success => MessageStatus.applied,
        SubmitStatus.clarificationNeeded => MessageStatus.needsClarification,
        SubmitStatus.error || SubmitStatus.cancelled => MessageStatus.error,
      };
      final steps = [
        for (final record in result.records) _toChatStep(record),
      ];
      final reply = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.agent,
        content: result.message,
        timestamp: DateTime.now(),
        status: status,
        resultingOperationIds: [
          for (final op in result.appliedOperations) op.id,
        ],
        steps: steps,
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
      _gate = null;
      _ref.read(pendingConfirmationProvider.notifier).clear();
      state = AgentRunState.idle;
    }
  }

  /// Answer the paused confirmation round (UI): true = approve, false = skip.
  /// No-op when nothing is pending.
  void approvePendingConfirmation(bool approved) {
    if (!isBusy) return;
    _gate?.resolve(approved);
  }

  /// Stop further rounds/tool calls and kill a running FFmpeg job.
  /// Already-applied edits stay (undoable); nothing further starts.
  /// A paused confirmation completes as denied.
  void cancel() {
    if (!isBusy) return;
    _gate?.resolve(false);
    _cancel?.cancel();
    try {
      _ref.read(ffmpegServiceProvider).cancel();
    } catch (_) {}
    state = AgentRunState.cancelled;
  }

  /// Map a domain call record to a persisted chat step.
  ///
  /// Kind comes from the tool registry; unknown tools default to edit
  /// so the UI treats them with edit-level caution.
  static final Map<String, ToolCategory> _toolKinds = {
    for (final def in ToolRegistry.defaultDefinitions()) def.name: def.category,
  };

  static ChatStep _toChatStep(AgentToolCallRecord record) {
    final category = _toolKinds[record.name] ?? ToolCategory.edit;
    return ChatStep(
      toolCallId: record.id,
      toolName: record.name,
      args: Map<String, dynamic>.from(record.args),
      summary: record.summary,
      success: record.success,
      durationMs: record.durationMs,
      kind: category == ToolCategory.read
          ? ChatStepKind.read
          : ChatStepKind.edit,
    );
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
