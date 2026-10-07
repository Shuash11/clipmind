import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/models/app_settings.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/chat_step.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/transcription/whisper_service.dart';
import 'package:clipmind/domain/agent/agent_activity.dart';
import 'package:clipmind/domain/agent/agent_confirmation.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';
import 'package:clipmind/domain/agent/tools/tool_selection.dart';
import 'package:clipmind/domain/usecases/run_agent_command_usecase.dart';
import 'package:clipmind/state/agent_analysis_providers.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/player_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';

enum AgentRunState { idle, running, cancelled, planReady }

/// Per-edit approval flag, persisted in [AppSettings.confirmAgentEdits].
///
/// Reads through to settings; every write persists via
/// `settingsProvider.notifier.update`. Keeps the `StateProvider`-style
/// interface (`watch` + `notifier.state =`) so existing bindings compile.
/// false = bulk-only mode (rounds with ≥3 edits pause).
final agentConfirmEditsProvider =
    StateNotifierProvider<AgentConfirmEditsFlag, bool>(
  (ref) => AgentConfirmEditsFlag(ref),
);

class AgentConfirmEditsFlag extends StateNotifier<bool> {
  AgentConfirmEditsFlag(this._ref) : super(false) {
    _syncFromSettings(_ref.read(settingsProvider).value);
    _ref.listen<AsyncValue<AppSettings>>(
      settingsProvider,
      (_, next) => _syncFromSettings(next.value),
    );
  }

  final Ref _ref;

  void _syncFromSettings(AppSettings? settings) {
    if (settings != null && state != settings.confirmAgentEdits) {
      super.state = settings.confirmAgentEdits;
    }
  }

  @override
  set state(bool value) {
    if (state == value) return;
    super.state = value;
    unawaited(_persist(value));
  }

  Future<void> _persist(bool value) async {
    try {
      final current = _ref.read(settingsProvider).value;
      if (current == null || current.confirmAgentEdits == value) return;
      await _ref
          .read(settingsProvider.notifier)
          .update(current.copyWith(confirmAgentEdits: value));
    } catch (_) {}
  }
}

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

/// A dry-run plan awaiting review: the proposed steps for the plan card
/// plus the recorded edit-tool calls for deterministic replay.
class PendingPlan {
  final String command;
  final String projectId;
  final List<ChatStep> steps;
  final List<ToolCall> calls;

  const PendingPlan({
    required this.command,
    required this.projectId,
    this.steps = const [],
    this.calls = const [],
  });
}

final pendingPlanProvider =
    StateNotifierProvider<PendingPlanHolder, PendingPlan?>(
  (ref) => PendingPlanHolder(),
);

class PendingPlanHolder extends StateNotifier<PendingPlan?> {
  PendingPlanHolder() : super(null);

  void set(PendingPlan plan) {
    state = plan;
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
      final project = _ref.read(projectProvider).value;
      if (project != null && project.id == projectId) {
        final clipIds = [
          for (final track in project.tracks)
            for (final clip in track.clips) clip.id,
        ];
        try {
          await _ref
              .read(agentAnalysisPortProvider(projectId))
              .warmUp(clipIds);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> submit(String command) async {
    final text = command.trim();
    if (text.isEmpty || isBusy) return;
    // A fresh command supersedes any pending plan.
    _ref.read(pendingPlanProvider.notifier).clear();

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: text,
      timestamp: DateTime.now(),
    );
    _ref.read(chatMessagesProvider.notifier).add(userMessage);
    final opened = _ref.read(projectProvider).value;
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
    var completedAsPlan = false;

    try {
      final project = _ref.read(projectProvider).value;
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
      // Await the settings load: on the first submit after app start the
      // repository may still be reading the JSON file, and a synchronous
      // read would silently fall back to defaults (no plan-preview).
      // Awaiting the cached `ready` future is free after the first load.
      // Re-read afterwards so later updates (not just the first load) win.
      // This also lets the confirm-edits flag sync before the gate is built.
      try {
        await _ref.read(settingsProvider.notifier).ready;
      } catch (_) {}
      final settings = _ref.read(settingsProvider).value;
      final gate = AgentConfirmationGate(
        _ref,
        perEdit: _ref.read(agentConfirmEditsProvider),
      );
      _gate = gate;
      final planPreview = settings?.planEditsBeforeApply ?? false;
      final analysisPort = _ref.read(agentAnalysisPortProvider(snapshot.id));
      final resolveFont = _ref.read(resolveFontProvider);
      final result = await useCase.execute(
        text,
        snapshot,
        provider: provider,
        metadata: metadata,
        recentHistory: _recentHistory(),
        applier: _ref.read(agentEditApplierProvider),
        liveProject: () =>
            _ref.read(projectProvider).value ?? snapshot,
        cancellation: controller.token,
        gate: gate,
        dryRun: planPreview,
        readAnalysis: analysisPort.read,
        writeAnalysis: analysisPort.write,
        whisperConfig: () => WhisperPaths(
          binaryPath: settings?.whisperBinaryPath ?? '',
          modelPath: settings?.whisperModelPath ?? '',
        ),
        resolveFont: resolveFont,
      );

      if (planPreview && result.status == SubmitStatus.success) {
        await _completeAsPlan(
          project: project,
          command: text,
          result: result,
        );
        completedAsPlan = true;
        return;
      }
      final steps = [
        for (final record in result.records) _toChatStep(record),
      ];
      await _postReply(project, result, steps);
    } finally {
      await _feedSub?.cancel();
      _feedSub = null;
      _cancel = null;
      _gate = null;
      _ref.read(pendingConfirmationProvider.notifier).clear();
      state = completedAsPlan ? AgentRunState.planReady : AgentRunState.idle;
    }
  }

  /// Finish a dry-run as a reviewable plan: record the proposed steps +
  /// replayable edit calls, post the plan-ready reply, and park the run in
  /// [AgentRunState.planReady]. A dry run with no edits posts normally.
  Future<void> _completeAsPlan({
    required Project project,
    required String command,
    required SubmitResult result,
  }) async {
    final steps = <ChatStep>[];
    final calls = <ToolCall>[];
    for (final record in result.records) {
      final step = _toChatStep(record);
      steps.add(step);
      if (step.kind == ChatStepKind.edit) {
        calls.add(ToolCall(
          id: record.id,
          name: record.name,
          args: Map<String, dynamic>.from(record.args),
        ));
      }
    }
    if (calls.isEmpty) {
      await _postReply(project, result, steps);
      return;
    }
    _ref.read(pendingPlanProvider.notifier).set(PendingPlan(
          command: command,
          projectId: project.id,
          steps: steps,
          calls: calls,
        ));
    final reply = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.agent,
      content: 'Plan ready: ${calls.length} edit(s) proposed. '
          'Review and approve or discard.',
      timestamp: DateTime.now(),
      status: MessageStatus.needsClarification,
      steps: steps,
    );
    _ref.read(chatMessagesProvider.notifier).add(reply);
    try {
      await _ref.read(appDatabaseProvider).saveChatMessage(
            project.id,
            reply,
          );
    } catch (_) {}
  }

  /// Shared reply posting for immediate runs and plan replays.
  Future<void> _postReply(
    Project project,
    SubmitResult result,
    List<ChatStep> steps,
  ) async {
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
      steps: steps,
    );
    _ref.read(chatMessagesProvider.notifier).add(reply);
    try {
      await _ref.read(appDatabaseProvider).saveChatMessage(
            project.id,
            reply,
          );
    } catch (_) {}

    if (result.status == SubmitStatus.success && result.outputPath != null) {
      _ref.read(currentVideoPathProvider.notifier).state = result.outputPath;
    }
  }

  /// Replay the pending plan deterministically (recorded calls, no new LLM
  /// round). Cancellable via [cancel]; already-applied edits stay undoable.
  Future<void> approvePlan() async {
    final plan = _ref.read(pendingPlanProvider);
    if (plan == null || state != AgentRunState.planReady) return;
    _ref.read(pendingPlanProvider.notifier).clear();

    state = AgentRunState.running;
    _ref.read(agentActivityFeedProvider.notifier).clear();
    final controller = CancellationController();
    _cancel = controller;
    _feedSub = _ref
        .read(nl2vecPipelineProvider)
        .agentActivity
        .listen(_ref.read(agentActivityFeedProvider.notifier).push);
    try {
      final project = _ref.read(projectProvider).value;
      if (project == null || project.id != plan.projectId) {
        await _replyError(
          project,
          'The project changed since this plan was created. '
          'Send the command again to re-plan.',
        );
        return;
      }
      final result =
          await _ref.read(nl2vecPipelineProvider).executePlanned(
                plan.calls,
                project,
                applier: _ref.read(agentEditApplierProvider),
                liveProject: () =>
                    _ref.read(projectProvider).value ?? project,
                cancellation: controller.token,
                resolveFont: _ref.read(resolveFontProvider),
              );
      final steps = [
        for (final record in result.records) _toChatStep(record),
      ];
      await _postReply(
        project,
        result,
        steps.isNotEmpty ? steps : plan.steps,
      );
    } finally {
      await _feedSub?.cancel();
      _feedSub = null;
      _cancel = null;
      _gate = null;
      _ref.read(pendingConfirmationProvider.notifier).clear();
      state = AgentRunState.idle;
    }
  }

  /// Drop the pending plan with a chat reply. No-op while replaying.
  Future<void> discardPlan() async {
    final plan = _ref.read(pendingPlanProvider);
    if (plan == null || state == AgentRunState.running) return;
    _ref.read(pendingPlanProvider.notifier).clear();
    if (state == AgentRunState.planReady) {
      state = AgentRunState.idle;
    }
    final reply = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.agent,
      content: 'Plan discarded.',
      timestamp: DateTime.now(),
      status: MessageStatus.applied,
    );
    _ref.read(chatMessagesProvider.notifier).add(reply);
    try {
      await _ref.read(appDatabaseProvider).saveChatMessage(
            plan.projectId,
            reply,
          );
    } catch (_) {}
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
  /// so the UI treats them with edit-level caution. The reserved
  /// `load_tools` meta-tool is a read step: visible in the trace, never
  /// replayed as an edit and never counted in a plan's edit count.
  static final Map<String, ToolCategory> _toolKinds = {
    for (final def in ToolRegistry.defaultDefinitions()) def.name: def.category,
    ToolSelection.loadToolsName: ToolCategory.read,
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
