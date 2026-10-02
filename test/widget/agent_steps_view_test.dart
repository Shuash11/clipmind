import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/chat_step.dart';
import 'package:clipmind/domain/agent/agent_activity.dart';
import 'package:clipmind/domain/agent/agent_confirmation.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/agent_steps_view.dart';
import 'package:clipmind/state/agent_run_providers.dart';

AgentActivityEvent started(
  String id,
  String name, {
  int round = 1,
  Map<String, dynamic>? args,
}) {
  return AgentActivityEvent(
    kind: AgentActivityKind.toolCallStarted,
    round: round,
    toolCallId: id,
    toolName: name,
    args: args,
  );
}

AgentActivityEvent completed(
  String id,
  String name, {
  int round = 1,
  String summary = 'Done.',
  bool success = true,
  int durationMs = 100,
}) {
  return AgentActivityEvent(
    kind: AgentActivityKind.toolCallCompleted,
    round: round,
    toolCallId: id,
    toolName: name,
    summary: summary,
    success: success,
    durationMs: durationMs,
  );
}

AgentActivityEvent failed(
  String id,
  String name, {
  int round = 1,
  String summary = 'Clip not found.',
}) {
  return AgentActivityEvent(
    kind: AgentActivityKind.toolCallFailed,
    round: round,
    toolCallId: id,
    toolName: name,
    summary: summary,
    success: false,
    durationMs: 0,
  );
}

AgentStepData liveStep(AgentStepStatus status) {
  return AgentStepData(
    toolCallId: 'call_1',
    toolName: 'trim_clip',
    args: const {'clip_id': 'clip_1', 'start': '00:00:00.000'},
    summary: 'Trimmed clip.',
    durationMs: 150,
    kind: ChatStepKind.edit,
    status: status,
  );
}

void main() {
  group('AgentStepLabel.format', () {
    test('trim_clip start/end -> timecode arrow', () {
      expect(
        AgentStepLabel.format('trim_clip', {
          'clip_id': 'clip_1',
          'start': '00:00:00.000',
          'end': '00:00:15.000',
        }),
        '00:00:00.000 → 00:00:15.000',
      );
    });

    test('cut_segment remove_start/remove_end -> timecode arrow', () {
      expect(
        AgentStepLabel.format('cut_segment', {
          'clip_id': 'clip_1',
          'remove_start': '00:00:05.000',
          'remove_end': '00:00:10.000',
        }),
        '00:00:05.000 → 00:00:10.000',
      );
    });

    test('change_speed factor -> 2.0×', () {
      expect(
        AgentStepLabel.format('change_speed', {'clip_id': 'clip_1', 'factor': 2.0}),
        '2.0×',
      );
    });

    test('change_volume factor -> 0.5×', () {
      expect(
        AgentStepLabel.format('change_volume', {'clip_id': 'clip_1', 'factor': 0.5}),
        '0.5×',
      );
    });

    test('overlay_text text+position -> quoted text · center', () {
      expect(
        AgentStepLabel.format('overlay_text', {
          'clip_id': 'clip_1',
          'text': 'Hello',
          'position': 'center',
        }),
        '"Hello" · center',
      );
    });

    test('overlay_text null position -> quoted text only', () {
      expect(
        AgentStepLabel.format('overlay_text', {'text': 'Hello', 'position': null}),
        '"Hello"',
      );
    });

    test('probe_video clip_id -> clip_1', () {
      expect(
        AgentStepLabel.format('probe_video', {'clip_id': 'clip_1'}),
        'clip_1',
      );
    });

    test('merge_clips clip_ids -> joined with +', () {
      expect(
        AgentStepLabel.format('merge_clips', {
          'clip_ids': ['clip_1', 'clip_2'],
        }),
        'clip_1 + clip_2',
      );
    });

    test('unknown tool -> generic key=value pairs, nulls dropped', () {
      expect(
        AgentStepLabel.format('unknown_tool', {'width': 1920, 'height': null}),
        'width=1920',
      );
    });

    test('no args -> empty string', () {
      expect(AgentStepLabel.format('list_project_clips', const {}), '');
    });
  });

  group('deriveLiveSteps', () {
    test('pairs started with completed by toolCallId', () {
      final steps = deriveLiveSteps([
        started('call_1', 'trim_clip'),
        completed('call_1', 'trim_clip', summary: 'Trimmed clip.', durationMs: 150),
        started('call_2', 'probe_video'),
      ]);
      expect(steps, hasLength(2));
      expect(steps[0].toolCallId, 'call_1');
      expect(steps[0].status, AgentStepStatus.success);
      expect(steps[0].durationMs, 150);
      expect(steps[0].summary, 'Trimmed clip.');
      expect(steps[1].toolCallId, 'call_2');
      expect(steps[1].status, AgentStepStatus.running);
    });

    test('pairs started with failed by toolCallId', () {
      final steps = deriveLiveSteps([
        started('call_1', 'probe_video'),
        failed('call_1', 'probe_video'),
      ]);
      expect(steps, hasLength(1));
      expect(steps[0].status, AgentStepStatus.failed);
      expect(steps[0].summary, 'Clip not found.');
    });

    test('recorded skips render as skipped, not failed', () {
      final steps = deriveLiveSteps([
        started('call_1', 'trim_clip'),
        failed('call_1', 'trim_clip', summary: 'Skipped by user'),
      ]);
      expect(steps, hasLength(1));
      expect(steps[0].status, AgentStepStatus.skipped);
    });

    test('unpaired started stays running', () {
      final steps = deriveLiveSteps([started('call_1', 'trim_clip')]);
      expect(steps, hasLength(1));
      expect(steps[0].status, AgentStepStatus.running);
    });

    test('returns rows in execution order', () {
      final steps = deriveLiveSteps([
        started('call_3', 'mute_clip'),
        started('call_1', 'trim_clip'),
        completed('call_1', 'trim_clip'),
        completed('call_3', 'mute_clip'),
      ]);
      expect(
        steps.map((s) => s.toolCallId).toList(),
        ['call_3', 'call_1'],
      );
    });

    test('ignores non tool-call events', () {
      final steps = deriveLiveSteps([
        AgentActivityEvent(kind: AgentActivityKind.runStarted, summary: 'Go'),
        AgentActivityEvent(kind: AgentActivityKind.llmRoundStarted, round: 1),
        AgentActivityEvent(
          kind: AgentActivityKind.confirmationRequested,
          round: 1,
        ),
      ]);
      expect(steps, isEmpty);
    });

    test('read tools classified read, edit tools edit', () {
      final steps = deriveLiveSteps([
        started('call_1', 'probe_video'),
        completed('call_1', 'probe_video'),
        started('call_2', 'trim_clip'),
      ]);
      expect(steps[0].kind, ChatStepKind.read);
      expect(steps[1].kind, ChatStepKind.edit);
    });
  });

  group('AgentStepRow', () {
    testWidgets('running step shows spinner and tool name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AgentStepRow(step: liveStep(AgentStepStatus.running)))),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('trim_clip'), findsOneWidget);
      expect(find.text('150ms'), findsOneWidget);
    });

    testWidgets('success step shows check icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AgentStepRow(step: liveStep(AgentStepStatus.success)))),
      );

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('failed step shows close icon in error color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AgentStepRow(step: liveStep(AgentStepStatus.failed)))),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.close_rounded));
      expect(icon.color, ClipMindColors.statusError);
    });

    testWidgets('skipped step shows close icon in muted color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AgentStepRow(step: liveStep(AgentStepStatus.skipped)))),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.close_rounded));
      expect(icon.color, ClipMindColors.textMuted);
    });

    testWidgets('read steps are visually distinct from edit steps', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AgentStepRow(step: liveStep(AgentStepStatus.success)),
                const AgentStepRow(
                  step: AgentStepData(
                    toolCallId: 'call_2',
                    toolName: 'probe_video',
                    args: {'clip_id': 'clip_1'},
                    summary: '1920x1080 @ 30fps',
                    durationMs: 12,
                    kind: ChatStepKind.read,
                    status: AgentStepStatus.success,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Edit: wrench icon on accent tint; read: search icon on neutral tint.
      expect(find.byIcon(Icons.build_rounded), findsOneWidget);
      expect(find.byIcon(Icons.manage_search), findsOneWidget);
      // Read rows show their result summary.
      expect(find.text('1920x1080 @ 30fps'), findsOneWidget);
    });

    testWidgets('long args are ellipsized, not overflowing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: AgentStepRow(
                step: AgentStepData(
                  toolCallId: 'call_1',
                  toolName: 'overlay_text',
                  args: {
                    'clip_id': 'clip_1',
                    'text': 'X' * 120,
                    'position': 'center',
                  },
                  summary: 'Y' * 120,
                  durationMs: 900,
                  kind: ChatStepKind.edit,
                  status: AgentStepStatus.success,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(texts.any((t) => t.overflow == TextOverflow.ellipsis), isTrue);
    });
  });

  group('AgentLivePipelineView', () {
    testWidgets('shows header, steps in order, and round progress', (
      tester,
    ) async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final feed = container.read(agentActivityFeedProvider.notifier);
      feed.push(AgentActivityEvent(kind: AgentActivityKind.runStarted));
      feed.push(AgentActivityEvent(kind: AgentActivityKind.llmRoundStarted, round: 2));
      feed.push(started('call_1', 'trim_clip', round: 2));
      feed.push(completed('call_1', 'trim_clip', round: 2, durationMs: 150));
      feed.push(started('call_2', 'probe_video', round: 2));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: AgentLivePipelineView()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('agent-live-pipeline')),
        findsOneWidget,
      );
      expect(find.text('AI is editing'), findsOneWidget);
      expect(find.text('Round 2/4'), findsOneWidget);
      final rows =
          tester.widgetList<AgentStepRow>(find.byType(AgentStepRow)).toList();
      expect(rows, hasLength(2));
      expect(rows[0].step.toolName, 'trim_clip');
      expect(rows[1].step.toolName, 'probe_video');
      expect(rows[1].step.status, AgentStepStatus.running);
    });

    testWidgets('renders confirmation state distinctly while paused', (
      tester,
    ) async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final feed = container.read(agentActivityFeedProvider.notifier);
      feed.push(started('call_1', 'trim_clip'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AgentLivePipelineView(
                confirmation: ConfirmationRequest(
                  round: 1,
                  kind: ConfirmationKind.bulk,
                  toolCalls: [
                    AgentToolCall(id: 'call_1', name: 'trim_clip'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Waiting for your approval'), findsOneWidget);
      expect(find.text('AI is editing'), findsNothing);
    });

    testWidgets('auto-scrolls to the newest step on new events', (
      tester,
    ) async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      // Mount first (empty feed), then let events stream in — the real
      // run order. The view jumps to the newest step on each new event.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: AgentLivePipelineView()),
          ),
        ),
      );
      await tester.pump();

      final feed = container.read(agentActivityFeedProvider.notifier);
      // Enough completed pairs to exceed the 220px steps viewport.
      for (var i = 1; i <= 8; i++) {
        feed.push(started('call_$i', 'trim_clip'));
        feed.push(
          completed(
            'call_$i',
            'trim_clip',
            summary: 'Trimmed clip $i to a nice short length.',
            durationMs: 100 + i,
          ),
        );
      }
      await tester.pump();
      await tester.pump();

      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('agent-live-pipeline')),
        matching: find.byType(Scrollable),
      );
      final position =
          tester.state<ScrollableState>(scrollable.first).position;
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, closeTo(position.maxScrollExtent, 0.5));

      // A new event re-anchors the view on the newest step.
      feed.push(started('call_9', 'mute_clip'));
      await tester.pump();
      await tester.pump();
      final fresh =
          tester.state<ScrollableState>(scrollable.first).position;
      expect(position.pixels, closeTo(fresh.maxScrollExtent, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty feed shows a waiting placeholder', (tester) async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: AgentLivePipelineView()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Waiting for the first step…'), findsOneWidget);
      expect(find.byType(AgentStepRow), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
