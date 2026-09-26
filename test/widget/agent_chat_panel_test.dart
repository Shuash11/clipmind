import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/domain/agent/agent_activity.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/agent_chat_panel.dart';
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
  }) async {
    calls++;
    await gate.future;
    if (cancellation?.isCancelled == true) {
      return const SubmitResult(
        status: SubmitStatus.cancelled,
        message: 'Cancelled — 0 edit(s) applied.',
      );
    }
    return result;
  }
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
    }) {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
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

    testWidgets('activity feed renders tool events while running', (
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

      container.read(agentActivityFeedProvider.notifier).push(
            AgentActivityEvent(
              kind: AgentActivityKind.toolCallStarted,
              round: 1,
              toolCallId: 'call_1',
              toolName: 'trim_clip',
            ),
          );
      container.read(agentActivityFeedProvider.notifier).push(
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
      await tester.pump();

      expect(find.byKey(const ValueKey('agent-activity-feed')), findsOneWidget);
      expect(find.textContaining('trim_clip'), findsWidgets);
      expect(find.textContaining('150ms'), findsOneWidget);
      gate.complete();
      await _settle(tester);
      expect(find.text('Trimmed it.'), findsOneWidget);
    });
  });
}

