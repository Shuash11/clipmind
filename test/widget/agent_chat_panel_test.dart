import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/app_settings.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/chat_step.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/settings_repository.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/data/services/transcription/whisper_service.dart';
import 'package:clipmind/domain/agent/agent_activity.dart';
import 'package:clipmind/domain/agent/agent_confirmation.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/agent_chat_panel.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/agent_steps_view.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/chat_bubble.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';

/// Legacy stub: the capturing pipeline below ignores the provider, so this
/// only needs to satisfy the controller's non-null provider lookup.
class _StubProvider extends LlmProvider {
  @override
  String get id => 'stub';

  @override
  Future<List<String>> availableModels() async => ['stub'];

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) =>
      throw UnimplementedError();

  @override
  Stream<ConnectionStatus> watchConnection() =>
      Stream.value(ConnectionStatus.connected);
}

class _FakeRegistry extends ProviderRegistry {
  final LlmProvider? active;
  _FakeRegistry(this.active);

  @override
  Future<LlmProvider?> getActiveProvider() async => active;
}

/// Capturing pipeline double: no FFmpeg, no file IO (async dart:io hangs
/// in this widget-test sandbox), optional gate for busy-state tests.
class _GatePipeline extends Nl2VecPipeline {
  final Completer<void> gate;
  final SubmitResult result;
  int calls = 0;

  _GatePipeline({Completer<void>? gate, required this.result})
      : gate = gate ?? (Completer<void>()..complete()),
        super(ffmpegService: FfmpegService());

  @override
  Future<SubmitResult> submitCommand(
    String text,
    Project project, {
    LlmProvider? provider,
    VideoMetadata? metadata,
    List<AgentRequest>? recentHistory,
    AgentEditApplier? applier,
    Project Function()? liveProject,
    CancellationToken? cancellation,
    ConfirmationGate? gate,
    bool dryRun = false,
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) async {
    calls++;
    await this.gate.future;
    if (cancellation?.isCancelled == true) {
      return const SubmitResult(
        status: SubmitStatus.cancelled,
        message: 'Cancelled — 0 edit(s) applied.',
      );
    }
    return result;
  }
}

/// Pausing pipeline double: routes the controller's REAL
/// [AgentConfirmationGate] through a [ConfirmationRequest] so the panel's
/// confirm bar is exercised end to end (ask -> UI -> resolve).
class _ConfirmingPipeline extends Nl2VecPipeline {
  final ConfirmationRequest request;
  final SubmitResult result;
  int calls = 0;

  _ConfirmingPipeline({required this.request, required this.result})
      : super(ffmpegService: FfmpegService());

  @override
  Future<SubmitResult> submitCommand(
    String text,
    Project project, {
    LlmProvider? provider,
    VideoMetadata? metadata,
    List<AgentRequest>? recentHistory,
    AgentEditApplier? applier,
    Project Function()? liveProject,
    CancellationToken? cancellation,
    ConfirmationGate? gate,
    bool dryRun = false,
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) async {
    calls++;
    final approved = await gate!.ask(request);
    if (!approved) {
      return const SubmitResult(
        status: SubmitStatus.cancelled,
        message: 'Skipped by user — 0 edit(s) applied.',
      );
    }
    return result;
  }
}

/// Plan-preview pipeline double: returns a dry-run result with edit-tool
/// records for the plan card, and records `executePlanned` replays.
class _PlanningPipeline extends Nl2VecPipeline {
  final SubmitResult dryRunResult;
  final SubmitResult plannedResult;
  int planned = 0;

  _PlanningPipeline({required this.dryRunResult, required this.plannedResult})
      : super(ffmpegService: FfmpegService());

  @override
  Future<SubmitResult> submitCommand(
    String text,
    Project project, {
    LlmProvider? provider,
    VideoMetadata? metadata,
    List<AgentRequest>? recentHistory,
    AgentEditApplier? applier,
    Project Function()? liveProject,
    CancellationToken? cancellation,
    ConfirmationGate? gate,
    bool dryRun = false,
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) async {
    return dryRunResult;
  }

  @override
  Future<SubmitResult> executePlanned(
    List<ToolCall> plannedCalls,
    Project project, {
    AgentEditApplier? applier,
    Project Function()? liveProject,
    CancellationToken? cancellation,
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) async {
    planned++;
    return plannedResult;
  }
}

/// Settings repository double: never touches the platform (real settings
/// load hangs in the widget-test sandbox), records saves.
class _FakeSettingsRepository extends SettingsRepository {
  int saves = 0;

  final AppSettings settings;

  _FakeSettingsRepository({this.settings = const AppSettings()});

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async => saves++;
}

Project _project() {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['/v/in.mp4'],
    tracks: const [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip_1',
            trackId: 't1',
            sourcePath: '/v/in.mp4',
            startMs: 0,
            endMs: 60000,
          ),
        ],
      ),
    ],
    durationMs: 60000,
    outputDir: '/out',
  );
}

/// Bounded pumps: lets run work finish without hanging on the busy
/// spinner (pumpAndSettle never settles while it animates).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
}

void main() {
  testWidgets('AgentChatPanel renders suggested prompts when no messages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AgentChatPanel())),
      ),
    );

    expect(find.text('AI Assistant'), findsOneWidget);
    for (final prompt in AgentChatPanel.suggestedPrompts) {
      expect(find.text(prompt), findsOneWidget);
    }
    expect(find.text('Type a command...'), findsOneWidget);
  });

  testWidgets('AgentChatPanel has send button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AgentChatPanel())),
      ),
    );

    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  group('Gen A wiring (no EditPlan flow)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    ProviderContainer makeContainer({
      required Nl2VecPipeline pipeline,
      LlmProvider? active,
      bool planPreview = false,
    }) {
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWith(
            (ref) => _FakeSettingsRepository(
              settings: planPreview
                  ? const AppSettings(planEditsBeforeApply: true)
                  : const AppSettings(),
            ),
          ),
          nl2vecPipelineProvider.overrideWithValue(pipeline),
          providerRegistryProvider.overrideWithValue(
            _FakeRegistry(active ?? _StubProvider()),
          ),
          projectMetadataProvider.overrideWith((ref) async => null),
        ],
      );
      container.read(projectProvider.notifier).setProject(_project());
      return container;
    }

    Future<void> pumpPanel(WidgetTester tester, ProviderContainer c) {
      return tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: Scaffold(body: AgentChatPanel())),
        ),
      );
    }

    Future<void> untilBusy(WidgetTester tester, ProviderContainer c) async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (c.read(agentRunControllerProvider) == AgentRunState.running) {
          return;
        }
      }
      fail('controller never became busy');
    }

    Future<void> untilPending(
      WidgetTester tester,
      ProviderContainer c,
    ) async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (c.read(pendingConfirmationProvider) != null) return;
      }
      fail('confirmation never became pending');
    }

    SubmitResult makeSuccess() => SubmitResult(
          status: SubmitStatus.success,
          message: 'Trimmed it.',
          appliedOperations: [
            EditOperation(
              id: 'call_1',
              type: EditOperationType.trim,
              targetClipIds: const ['clip_1'],
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        );

    testWidgets('submit shows the agent summary, no EditPlanCard', (
      WidgetTester tester,
    ) async {
      final pipeline = _GatePipeline(result: makeSuccess());
      final container = makeContainer(pipeline: pipeline);
      addTearDown(container.dispose);
      await pumpPanel(tester, container);

      await tester.enterText(find.byType(TextField), 'Trim the first 5 seconds');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await _settle(tester);

      expect(pipeline.calls, equals(1));
      expect(find.byKey(const ValueKey('edit-plan-card')), findsNothing);
      expect(find.text('Trimmed it.'), findsOneWidget);
      final reply = container.read(chatMessagesProvider).lastWhere(
            (m) => m.role == ChatRole.agent,
          );
      expect(reply.resultingOperationIds, equals(['call_1']));
    });

    testWidgets('Cancel button stops the run', (WidgetTester tester) async {
      final gate = Completer<void>();
      final pipeline = _GatePipeline(
        gate: gate,
        result: makeSuccess(),
      );
      final container = makeContainer(pipeline: pipeline);
      addTearDown(container.dispose);
      await pumpPanel(tester, container);

      await tester.enterText(find.byType(TextField), 'Trim it');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await untilBusy(tester, container);
      expect(find.byKey(const ValueKey('agent-run-cancel')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-run-cancel')));
      await tester.pump();
      expect(
        container.read(agentRunControllerProvider),
        equals(AgentRunState.cancelled),
      );
      gate.complete();
      await _settle(tester);

      expect(find.textContaining('Cancelled'), findsWidgets);
    });

    testWidgets('live pipeline view renders steps in order while running', (
      WidgetTester tester,
    ) async {
      final gate = Completer<void>();
      final pipeline = _GatePipeline(gate: gate, result: makeSuccess());
      final container = makeContainer(pipeline: pipeline);
      addTearDown(container.dispose);
      await pumpPanel(tester, container);

      await tester.enterText(find.byType(TextField), 'Trim it');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await untilBusy(tester, container);

      final feed = container.read(agentActivityFeedProvider.notifier);
      feed.push(
        AgentActivityEvent(
          kind: AgentActivityKind.toolCallStarted,
          round: 1,
          toolCallId: 'call_1',
          toolName: 'trim_clip',
        ),
      );
      feed.push(
        AgentActivityEvent(
          kind: AgentActivityKind.toolCallCompleted,
          round: 1,
          toolCallId: 'call_1',
          toolName: 'trim_clip',
          summary: 'Trimmed clip.',
          success: true,
          durationMs: 150,
        ),
      );
      feed.push(
        AgentActivityEvent(
          kind: AgentActivityKind.toolCallStarted,
          round: 1,
          toolCallId: 'call_2',
          toolName: 'probe_video',
        ),
      );
      feed.push(
        AgentActivityEvent(
          kind: AgentActivityKind.toolCallFailed,
          round: 1,
          toolCallId: 'call_2',
          toolName: 'probe_video',
          summary: 'Clip not found.',
          success: false,
          durationMs: 12,
        ),
      );
      feed.push(
        AgentActivityEvent(
          kind: AgentActivityKind.toolCallStarted,
          round: 1,
          toolCallId: 'call_3',
          toolName: 'change_speed',
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('agent-live-pipeline')),
        findsOneWidget,
      );
      expect(find.textContaining('AI is editing'), findsWidgets);
      final rows =
          tester.widgetList<AgentStepRow>(find.byType(AgentStepRow)).toList();
      expect(rows, hasLength(3));
      expect(rows[0].step.toolName, equals('trim_clip'));
      expect(rows[0].step.status, equals(AgentStepStatus.success));
      expect(rows[1].step.toolName, equals('probe_video'));
      expect(rows[1].step.status, equals(AgentStepStatus.failed));
      expect(rows[2].step.toolName, equals('change_speed'));
      expect(rows[2].step.status, equals(AgentStepStatus.running));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      gate.complete();
      await _settle(tester);
      expect(find.text('Trimmed it.'), findsOneWidget);
    });

    testWidgets('history load is invoked on init', (
      WidgetTester tester,
    ) async {
      await db.saveChatMessage(
        'p1',
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: 'Old user command',
          timestamp: DateTime(2026, 1, 1),
        ),
      );
      await db.saveChatMessage(
        'p1',
        ChatMessage(
          id: 'm2',
          role: ChatRole.agent,
          content: 'Restored from DB.',
          timestamp: DateTime(2026, 1, 2),
          steps: [
            const ChatStep(
              toolCallId: 'call_1',
              toolName: 'trim_clip',
              summary: 'Trimmed clip.',
              success: true,
              durationMs: 150,
              kind: ChatStepKind.edit,
            ),
          ],
        ),
      );
      final container = makeContainer(pipeline: _GatePipeline(result: makeSuccess()));
      addTearDown(container.dispose);

      await pumpPanel(tester, container);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Old user command'), findsOneWidget);
      expect(find.text('Restored from DB.'), findsOneWidget);
      // Persisted steps surface as a collapsed header on the agent bubble.
      expect(find.byKey(const ValueKey('agent-steps-header')), findsOneWidget);
    });

    group('confirmation bar', () {
      ConfirmationRequest bulkRequest() => const ConfirmationRequest(
            round: 1,
            kind: ConfirmationKind.bulk,
            toolCalls: [
              AgentToolCall(id: 'call_1', name: 'trim_clip'),
              AgentToolCall(id: 'call_2', name: 'mute_clip'),
              AgentToolCall(id: 'call_3', name: 'change_speed'),
            ],
          );

      ConfirmationRequest perEditRequest() => const ConfirmationRequest(
            round: 2,
            kind: ConfirmationKind.perEdit,
            toolCalls: [
              AgentToolCall(id: 'call_4', name: 'trim_clip'),
            ],
          );

      testWidgets('bulk: Approve continues the run', (
        WidgetTester tester,
      ) async {
        final pipeline = _ConfirmingPipeline(
          request: bulkRequest(),
          result: makeSuccess(),
        );
        final container = makeContainer(pipeline: pipeline);
        addTearDown(container.dispose);
        await pumpPanel(tester, container);

        await tester.enterText(find.byType(TextField), 'Make a montage');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await untilBusy(tester, container);
        await untilPending(tester, container);

        expect(
          find.byKey(const ValueKey('agent-confirm-bar')),
          findsOneWidget,
        );
        expect(find.textContaining('apply 3 edits'), findsOneWidget);
        expect(find.text('Approve'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        // Cancel stays active while paused.
        expect(
          find.byKey(const ValueKey('agent-run-cancel')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('agent-confirm-approve')));
        await _settle(tester);

        expect(pipeline.calls, equals(1));
        expect(find.text('Trimmed it.'), findsOneWidget);
        expect(container.read(pendingConfirmationProvider), isNull);
      });

      testWidgets('bulk: Skip skips the run', (WidgetTester tester) async {
        final pipeline = _ConfirmingPipeline(
          request: bulkRequest(),
          result: makeSuccess(),
        );
        final container = makeContainer(pipeline: pipeline);
        addTearDown(container.dispose);
        await pumpPanel(tester, container);

        await tester.enterText(find.byType(TextField), 'Make a montage');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await untilBusy(tester, container);
        await untilPending(tester, container);

        await tester.tap(find.byKey(const ValueKey('agent-confirm-skip')));
        await _settle(tester);

        expect(pipeline.calls, equals(1));
        expect(find.textContaining('Skipped by user'), findsWidgets);
        expect(container.read(pendingConfirmationProvider), isNull);
      });

      testWidgets('per-edit: Allow runs the call', (WidgetTester tester) async {
        final pipeline = _ConfirmingPipeline(
          request: perEditRequest(),
          result: makeSuccess(),
        );
        final container = makeContainer(pipeline: pipeline);
        addTearDown(container.dispose);
        await pumpPanel(tester, container);

        await tester.enterText(find.byType(TextField), 'Trim it');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await untilBusy(tester, container);
        await untilPending(tester, container);

        expect(find.textContaining('run trim_clip'), findsOneWidget);
        expect(find.text('Allow'), findsOneWidget);
        expect(find.text('Deny'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('agent-confirm-allow')));
        await _settle(tester);

        expect(pipeline.calls, equals(1));
        expect(find.text('Trimmed it.'), findsOneWidget);
        expect(container.read(pendingConfirmationProvider), isNull);
      });

      testWidgets('per-edit: Deny denies the call', (WidgetTester tester) async {
        final pipeline = _ConfirmingPipeline(
          request: perEditRequest(),
          result: makeSuccess(),
        );
        final container = makeContainer(pipeline: pipeline);
        addTearDown(container.dispose);
        await pumpPanel(tester, container);

        await tester.enterText(find.byType(TextField), 'Trim it');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await untilBusy(tester, container);
        await untilPending(tester, container);

        await tester.tap(find.byKey(const ValueKey('agent-confirm-deny')));
        await _settle(tester);

        expect(pipeline.calls, equals(1));
        expect(find.textContaining('Skipped by user'), findsWidgets);
        expect(container.read(pendingConfirmationProvider), isNull);
      });
    });

    group('plan card', () {
      const dryRunSteps = [
        ChatStep(
          toolCallId: 'call_1',
          toolName: 'trim_clip',
          args: {
            'clip_id': 'clip_1',
            'start': '00:00:00.000',
            'end': '00:00:05.000',
          },
          summary: 'Would trim clip.',
          success: true,
          durationMs: 3,
          kind: ChatStepKind.edit,
        ),
        ChatStep(
          toolCallId: 'call_2',
          toolName: 'mute_clip',
          args: {'clip_id': 'clip_1'},
          summary: 'Would mute clip.',
          success: true,
          durationMs: 2,
          kind: ChatStepKind.edit,
        ),
      ];

      PendingPlan planRequest() => const PendingPlan(
            command: 'Trim the first 5 seconds',
            projectId: 'p1',
            steps: dryRunSteps,
            calls: [
              ToolCall(id: 'call_1', name: 'trim_clip', args: {
                'clip_id': 'clip_1',
                'start': '00:00:00.000',
                'end': '00:00:05.000',
              }),
              ToolCall(id: 'call_2', name: 'mute_clip', args: {'clip_id': 'clip_1'}),
            ],
          );

      /// Park the run in planReady with a pending plan (the dry-run
      /// outcome) so the panel's plan-card rendering is exercised.
      void parkPlan(ProviderContainer container) {
        container.read(agentRunControllerProvider.notifier).state =
            AgentRunState.planReady;
        container.read(pendingPlanProvider.notifier).set(planRequest());
      }

      SubmitResult makePlanned() => SubmitResult(
            status: SubmitStatus.success,
            message: 'Applied 2 edit(s).',
            appliedOperations: [
              EditOperation(
                id: 'call_1',
                type: EditOperationType.trim,
                targetClipIds: const ['clip_1'],
                createdAt: DateTime(2026, 1, 1),
              ),
              EditOperation(
                id: 'call_2',
                type: EditOperationType.mute,
                targetClipIds: const ['clip_1'],
                createdAt: DateTime(2026, 1, 1),
              ),
            ],
          );

      testWidgets('plan card renders on planReady with planned steps', (
        WidgetTester tester,
      ) async {
        final pipeline = _PlanningPipeline(
          dryRunResult: const SubmitResult(
            status: SubmitStatus.success,
            message: 'Plan ready.',
          ),
          plannedResult: makePlanned(),
        );
        final container = makeContainer(pipeline: pipeline);
        addTearDown(container.dispose);
        await pumpPanel(tester, container);
        parkPlan(container);
        await tester.pump();

        expect(
          container.read(agentRunControllerProvider),
          equals(AgentRunState.planReady),
        );
        final plan = container.read(pendingPlanProvider);
        expect(plan, isNotNull);
        expect(plan!.steps, hasLength(2));
        expect(find.byKey(const ValueKey('agent-plan-card')), findsOneWidget);
        expect(find.text('Edit plan — 2 steps'), findsOneWidget);
        expect(find.text('Would trim clip.'), findsOneWidget);
        expect(find.text('Would mute clip.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-plan-approve')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-plan-discard')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('agent-plan-approve')));
        await _settle(tester);
        await tester.pump();

        // The REAL approvePlan ran: the recorded calls replayed through
        // the pipeline double, the plan cleared and the reply posted. The
        // widget-test sandbox defers the final idle transition (it lands
        // in the reply save's tail) — the Discard test covers the sync
        // path back to idle.
        expect(pipeline.planned, equals(1));
        expect(container.read(pendingPlanProvider), isNull);
        expect(find.textContaining('Applied 2 edit(s)'), findsWidgets);
        expect(find.byKey(const ValueKey('agent-plan-card')), findsNothing);
      });

      testWidgets('plan card Discard drops the plan', (
        WidgetTester tester,
      ) async {
        final pipeline = _PlanningPipeline(
          dryRunResult: const SubmitResult(
            status: SubmitStatus.success,
            message: 'Plan ready.',
          ),
          plannedResult: makePlanned(),
        );
        final container = makeContainer(pipeline: pipeline);
        addTearDown(container.dispose);
        await pumpPanel(tester, container);
        parkPlan(container);
        await tester.pump();
        expect(
          container.read(agentRunControllerProvider),
          equals(AgentRunState.planReady),
        );

        await tester.tap(find.byKey(const ValueKey('agent-plan-discard')));
        await _settle(tester);

        expect(pipeline.planned, equals(0));
        expect(
          container.read(agentRunControllerProvider),
          equals(AgentRunState.idle),
        );
        expect(container.read(pendingPlanProvider), isNull);
        expect(find.text('Plan discarded.'), findsOneWidget);
      });

      testWidgets('no overflow with the plan card at 340px', (
        WidgetTester tester,
      ) async {
        final longArgs = {
          'clip_id': 'clip_1',
          'text': 'X' * 160,
          'position': 'center',
        };
        final plan = PendingPlan(
          command: 'Overlay long text',
          projectId: 'p1',
          steps: [
            for (var i = 1; i <= 6; i++)
              ChatStep(
                toolCallId: 'call_$i',
                toolName: 'overlay_text',
                args: longArgs,
                summary: 'Would overlay the text near the top left corner',
                success: true,
                durationMs: 1200,
                kind: ChatStepKind.edit,
              ),
          ],
          calls: const [],
        );
        final pipeline = _PlanningPipeline(
          dryRunResult: const SubmitResult(
            status: SubmitStatus.success,
            message: 'Plan ready.',
          ),
          plannedResult: makePlanned(),
        );
        final container = makeContainer(pipeline: pipeline);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(width: 340, child: AgentChatPanel()),
              ),
            ),
          ),
        );
        // A user message exists in the real flow (the plan follows a
        // submit); it also hides the suggested prompts so the plan card's
        // space matches production.
        container.read(chatMessagesProvider.notifier).add(
              ChatMessage(
                id: 'm1',
                role: ChatRole.user,
                content: 'Overlay long text',
                timestamp: DateTime(2026, 1, 1),
              ),
            );
        container.read(agentRunControllerProvider.notifier).state =
            AgentRunState.planReady;
        container.read(pendingPlanProvider.notifier).set(plan);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('agent-plan-card')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final stepTexts = tester.widgetList<Text>(
          find.descendant(
            of: find.byType(AgentStepRow),
            matching: find.byType(Text),
          ),
        );
        expect(
          stepTexts.any((t) => t.overflow == TextOverflow.ellipsis),
          isTrue,
        );
      });
    });

    testWidgets('no overflow in the 340px panel during a busy run', (
      WidgetTester tester,
    ) async {
      final gate = Completer<void>();
      final pipeline = _GatePipeline(gate: gate, result: makeSuccess());
      final container = makeContainer(pipeline: pipeline);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SizedBox(width: 340, child: AgentChatPanel())),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Add a long overlay');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await untilBusy(tester, container);

      final longText = 'A' * 160;
      final feed = container.read(agentActivityFeedProvider.notifier);
      feed.push(
        AgentActivityEvent(
          kind: AgentActivityKind.toolCallStarted,
          round: 1,
          toolCallId: 'call_1',
          toolName: 'overlay_text',
          args: {
            'clip_id': 'clip_1',
            'text': longText,
            'position': 'center',
            'font_size': 48,
            'color': '#FFFFFF',
          },
        ),
      );
      feed.push(
        AgentActivityEvent(
          kind: AgentActivityKind.toolCallCompleted,
          round: 1,
          toolCallId: 'call_1',
          toolName: 'overlay_text',
          summary: longText,
          success: true,
          durationMs: 1250,
        ),
      );
      feed.push(
        AgentActivityEvent(
          kind: AgentActivityKind.toolCallStarted,
          round: 1,
          toolCallId: 'call_2',
          toolName: 'trim_clip',
          args: {
            'clip_id': 'clip_1',
            'start': '00:00:00.000',
            'end': '00:00:15.000',
          },
        ),
      );
      container.read(pendingConfirmationProvider.notifier).set(
            const ConfirmationRequest(
              round: 1,
              kind: ConfirmationKind.bulk,
              toolCalls: [
                AgentToolCall(id: 'call_1', name: 'overlay_text'),
                AgentToolCall(id: 'call_2', name: 'trim_clip'),
                AgentToolCall(id: 'call_3', name: 'mute_clip'),
              ],
            ),
          );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Long args are ellipsized, never overflowing the narrow panel.
      final stepTexts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(AgentStepRow),
          matching: find.byType(Text),
        ),
      );
      expect(
        stepTexts.any((t) => t.overflow == TextOverflow.ellipsis),
        isTrue,
      );
      gate.complete();
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('ChatBubble steps', () {
    ChatMessage messageWithSteps() => ChatMessage(
          id: 'm1',
          role: ChatRole.agent,
          content: 'Trimmed it.',
          timestamp: DateTime(2026, 1, 1),
          steps: [
            const ChatStep(
              toolCallId: 'call_1',
              toolName: 'trim_clip',
              args: {
                'clip_id': 'clip_1',
                'start': '00:00:00.000',
                'end': '00:00:15.000',
              },
              summary: 'Trimmed clip.',
              success: true,
              durationMs: 150,
              kind: ChatStepKind.edit,
            ),
            const ChatStep(
              toolCallId: 'call_2',
              toolName: 'probe_video',
              args: {'clip_id': 'clip_1'},
              summary: '1920x1080 @ 30fps',
              success: true,
              durationMs: 12,
              kind: ChatStepKind.read,
            ),
          ],
        );

    testWidgets('agent bubble shows collapsed steps header, expands to rows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChatBubble(message: messageWithSteps())),
        ),
      );

      // Collapsed by default: header visible, no rows rendered.
      expect(
        find.byKey(const ValueKey('agent-steps-header')),
        findsOneWidget,
      );
      expect(find.text('2 tool calls · 1 edit · 162ms'), findsOneWidget);
      expect(find.byType(AgentStepRow), findsNothing);

      await tester.tap(find.byKey(const ValueKey('agent-steps-header')));
      await tester.pump();

      expect(find.byType(AgentStepRow), findsNWidgets(2));
      expect(find.text('00:00:00.000 → 00:00:15.000'), findsOneWidget);
      expect(find.text('1920x1080 @ 30fps'), findsOneWidget);
      // Collapse again.
      await tester.tap(find.byKey(const ValueKey('agent-steps-header')));
      await tester.pump();
      expect(find.byType(AgentStepRow), findsNothing);
    });

    testWidgets('user bubble has no steps header', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: ChatMessage(
                id: 'm2',
                role: ChatRole.user,
                content: 'Trim the first 5 seconds',
                timestamp: DateTime(2026, 1, 1),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('agent-steps-header')),
        findsNothing,
      );
    });
  });
}

