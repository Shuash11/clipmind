import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/domain/agent/agent_activity.dart';
import 'package:clipmind/domain/agent/agent_confirmation.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_1_input_validation.dart';
import 'package:clipmind/domain/agent/tool_calling_agent.dart';
import 'package:clipmind/domain/agent/tools/project_command_gateway.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';
import 'package:clipmind/domain/agent/tools/tool_selection.dart';
import 'package:clipmind/features/projects/domain/commands/tag_commands.dart';

import '../../features/projects/support/project_test_data.dart';
import 'tools/support/fake_project_command_gateway.dart';

/// Scripted provider: returns one canned turn per round.
class _ScriptProvider extends LlmProvider {
  final List<AgentTurnResult> script;
  final List<AgentTurnRequest> seen = [];
  int calls = 0;

  _ScriptProvider(this.script);

  @override
  String get id => 'script';

  @override
  bool get supportsToolCalling => true;

  @override
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) async {
    seen.add(request);
    return script[calls++];
  }

  @override
  Future<List<String>> availableModels() async => ['script'];

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) =>
      throw UnimplementedError();

  @override
  Stream<ConnectionStatus> watchConnection() =>
      Stream.value(ConnectionStatus.connected);
}

/// NIM-flavored scripted provider: same loop contract, NIM identity.
/// Proves the agentic loop is provider-agnostic end-to-end for NIM.
class _NimScriptProvider extends _ScriptProvider {
  _NimScriptProvider(super.script);

  @override
  String get id => 'nvidia_nim:meta/llama-3.3-70b-instruct';
}

/// Gemini-flavored scripted provider: same loop contract, Gemini identity.
/// Proves the agentic loop is provider-agnostic end-to-end for Gemini
/// (whose native wire uses synthetic `functionCall` ids and name-keyed
/// `functionResponse`, mapped to canonical turns by the provider).
class _GeminiScriptProvider extends _ScriptProvider {
  _GeminiScriptProvider(super.script);

  @override
  String get id => 'gemini:gemini-3.8-flash';
}

/// Slow-local-model scripted provider (Ollama-like): suggests a longer
/// per-round timeout for local inference on the large tool prompt.
class _SlowLocalScriptProvider extends _ScriptProvider {
  _SlowLocalScriptProvider(super.script);

  @override
  String get id => 'ollama:llama3.1';

  @override
  int get suggestedRoundTimeoutSeconds => 120;
}

class _OkExecutor implements ToolExecutor {
  @override
  Future<ToolResult> execute(ToolCall call) async => ToolResult.ok(
        data: {'output_path': '/out/${call.id}.mp4'},
        summary: 'ok',
      );
}

class _FailExecutor implements ToolExecutor {
  @override
  Future<ToolResult> execute(ToolCall call) async =>
      ToolResult.fail('Unknown clip ID "ghost".');
}

/// Records gate questions so loader-bypass behaviour can be asserted.
class _RecordingGate implements ConfirmationGate {
  final bool approve;
  int calls = 0;
  final List<ConfirmationRequest> seen = [];

  _RecordingGate({required this.approve});

  @override
  bool get requiresPerEditApproval => false;

  @override
  Future<bool> ask(ConfirmationRequest request) async {
    calls++;
    seen.add(request);
    return approve;
  }
}

/// Journals one applied edit like the real edit executor, then cancels the
/// run so the next boundary check observes cancellation mid-run.
class _JournalAndCancel implements ToolExecutor {
  _JournalAndCancel(this.ctx, this.controller);

  final ToolExecutionContext ctx;
  final CancellationController controller;

  @override
  Future<ToolResult> execute(ToolCall call) async {
    ctx.appliedOperations.add(EditOperation(
      id: call.id,
      type: EditOperationType.trim,
      targetClipIds: const ['clip_1'],
      createdAt: DateTime(2026, 1, 1),
    ));
    ctx.outputPaths.add('/out/${call.id}.mp4');
    controller.cancel();
    return ToolResult.ok(summary: 'ok');
  }
}

ToolRegistry _registryWith(Map<String, ToolExecutor> overrides) {
  final base = <String, ToolExecutor>{
    for (final d in ToolRegistry.defaultDefinitions())
      d.name: _OkExecutor(),
  };
  base.addAll(overrides);
  return ToolRegistry(executors: base);
}

ValidatedCommand _validated() {
  final (validated, _) = InputValidator.validate(
    'Trim the first 5 seconds then mute',
    null,
    projectClips: const [
      ClipSnapshot(
        id: 'clip_1',
        trackId: 't1',
        label: 'intro',
        startMs: 0,
        endMs: 60000,
        positionMs: 0,
      ),
    ],
  );
  return validated!;
}

/// One model turn that asks to load [tools] through the reserved meta-tool.
AgentTurnResult _loadTurn(String id, List<String> tools) => AgentTurnResult(
      toolCalls: [
        AgentToolCall(id: id, name: 'load_tools', args: {'tools': tools}),
      ],
      stopReason: AgentTurnStopReason.toolCalls,
    );

// Minimal context: no FFmpeg runs in these loop tests (stub executors,
// so services are never touched). The dry-run variant uses the real
// registry executors: mapping builds arg strings only, and dry-run
// returns before any FFmpeg execution. [gateway] wires the tag/marker
// command executor to the fake command pipeline.
ToolExecutionContext _context({
  bool dryRun = false,
  ProjectCommandGateway? gateway,
}) {
  final project = Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['/v/input.mp4'],
    tracks: const [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip_1',
            trackId: 't1',
            sourcePath: '/v/input.mp4',
            startMs: 0,
            endMs: 60000,
          ),
        ],
      ),
    ],
    durationMs: 60000,
    outputDir: '/out',
  );
  return ToolExecutionContext(
    project: () => project,
    outputDir: '/out',
    projectDir: '/out',
    applier: AgentEditApplier(
        onApply: (_, _, {removeClipIds = const []}) async {}),
    ffmpegService: FfmpegService(),
    ffprobeService: FfprobeService(),
    dryRun: dryRun,
    gateway: gateway,
  );
}

void main() {
  group('ToolCallingAgent loop', () {
    test(
        'round 1 tool call appends result, round 2 final text completes',
        () async {
      final provider = _ScriptProvider([
        const AgentTurnResult(
          text: 'Trimming now.',
          toolCalls: [
            AgentToolCall(
              id: 'call_1',
              name: 'trim_clip',
              args: {'clip_id': 'clip_1'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Trimmed the first 5 seconds.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      expect(result.status, equals(AgentRunStatus.success));
      expect(result.message, equals('Trimmed the first 5 seconds.'));
      expect(provider.calls, equals(2));
      // Second round history carries the assistant call + tool result.
      final round2 = provider.seen[1];
      expect(
        round2.history.any((m) =>
            m.role == AgentTurnRole.toolResult &&
            m.toolCallId == 'call_1'),
        isTrue,
      );
      expect(result.records, hasLength(1));
      expect(result.records.single.success, isTrue);
      agent.dispose();
    });

    test('NIM-flavored provider runs the loop end-to-end', () async {
      final provider = _NimScriptProvider([
        const AgentTurnResult(
          text: 'Trimming now.',
          toolCalls: [
            AgentToolCall(
              id: 'call_1',
              name: 'trim_clip',
              args: {'clip_id': 'clip_1'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Trimmed the first 5 seconds.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      expect(provider.supportsToolCalling, isTrue);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      expect(result.status, equals(AgentRunStatus.success));
      expect(result.message, equals('Trimmed the first 5 seconds.'));
      expect(provider.calls, equals(2));
      final round2 = provider.seen[1];
      expect(
        round2.history.any((m) =>
            m.role == AgentTurnRole.toolResult &&
            m.toolCallId == 'call_1'),
        isTrue,
      );
      expect(result.records, hasLength(1));
      expect(result.records.single.success, isTrue);
      agent.dispose();
    });

    test('Gemini-flavored provider runs the loop end-to-end', () async {
      final provider = _GeminiScriptProvider([
        const AgentTurnResult(
          text: 'Trimming now.',
          toolCalls: [
            AgentToolCall(
              id: 'fc_1_1',
              name: 'trim_clip',
              args: {'clip_id': 'clip_1'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Trimmed the first 5 seconds.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      expect(provider.supportsToolCalling, isTrue);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      expect(result.status, equals(AgentRunStatus.success));
      expect(result.message, equals('Trimmed the first 5 seconds.'));
      expect(provider.calls, equals(2));
      final round2 = provider.seen[1];
      expect(
        round2.history.any((m) =>
            m.role == AgentTurnRole.toolResult &&
            m.toolCallId == 'fc_1_1'),
        isTrue,
      );
      // The provider-neutral tool name travels with the result turn.
      expect(
        round2.history
            .where((m) => m.role == AgentTurnRole.toolResult)
            .single
            .toolName,
        equals('trim_clip'),
      );
      expect(result.records, hasLength(1));
      expect(result.records.single.success, isTrue);
      agent.dispose();
    });

    test('max-rounds guard stops after 4 tool rounds', () async {
      final provider = _ScriptProvider(
        List.generate(
          6,
          (i) => AgentTurnResult(
            text: 'Again $i.',
            toolCalls: [
              AgentToolCall(
                id: 'call_$i',
                name: 'mute_clip',
                args: const {'clip_id': 'clip_1'},
              ),
            ],
            stopReason: AgentTurnStopReason.toolCalls,
          ),
        ),
      );
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      expect(provider.calls, equals(ToolRegistry.maxToolRounds));
      expect(result.status, equals(AgentRunStatus.success));
      expect(result.message, contains('Stopped after the tool-round limit'));
      expect(result.records, hasLength(4));
      agent.dispose();
    });

    test('failure path emits toolCallFailed and still completes', () async {
      final provider = _ScriptProvider([
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(
              id: 'call_x',
              name: 'trim_clip',
              args: {'clip_id': 'ghost'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'That clip does not exist.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({'trim_clip': _FailExecutor()}),
      );
      final events = <AgentActivityEvent>[];
      final sub = agent.activityEvents.listen(events.add);

      final result = await agent.run(validated: _validated());
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(result.status, equals(AgentRunStatus.success));
      expect(result.message, equals('That clip does not exist.'));
      expect(
        events.any((e) => e.kind == AgentActivityKind.toolCallFailed),
        isTrue,
      );
      expect(
        events.any((e) => e.kind == AgentActivityKind.runCompleted),
        isTrue,
      );
      expect(result.records.single.success, isFalse);
      agent.dispose();
    });

    test('unknown tool name fails actionably without crashing', () async {
      final provider = _ScriptProvider([
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(id: 'call_u', name: 'teleport_clip', args: {}),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'No such tool.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      expect(result.status, equals(AgentRunStatus.success));
      expect(result.records.single.success, isFalse);
      expect(result.records.single.summary, contains('Unknown tool'));
      agent.dispose();
    });

    test('round 2 keeps the original user turn, no phantom user message',
        () async {
      final provider = _ScriptProvider([
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(
              id: 'call_1',
              name: 'trim_clip',
              args: {'clip_id': 'clip_1'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Done.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      await agent.run(validated: _validated());

      final round1 = provider.seen[0];
      expect(round1.history, isEmpty);
      expect(round1.userContent, contains('Trim the first 5 seconds'));
      final round2 = provider.seen[1];
      expect(round2.userContent, isEmpty);
      expect(round2.history.first.role, equals(AgentTurnRole.user));
      expect(
        round2.history.first.content,
        contains('Trim the first 5 seconds'),
      );
      final phantom = round2.history.where(
        (m) =>
            m.role == AgentTurnRole.user &&
            (m.content ?? '').contains('Continue'),
      );
      expect(phantom, isEmpty);
      agent.dispose();
    });

    test('cancellation between rounds returns partial applied edits',
        () async {
      final controller = CancellationController();
      final provider = _ScriptProvider([
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(
              id: 'call_1',
              name: 'trim_clip',
              args: {'clip_id': 'clip_1'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Never reached.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final ctx = _context();
      final agent = ToolCallingAgent(
        provider: provider,
        context: ctx,
        registry: ToolRegistry(executors: {
          for (final d in ToolRegistry.defaultDefinitions())
            d.name: _JournalAndCancel(ctx, controller),
        }),
      );
      final events = <AgentActivityEvent>[];
      final sub = agent.activityEvents.listen(events.add);

      final result = await agent.run(
        validated: _validated(),
        cancellation: controller.token,
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(provider.calls, equals(1));
      expect(result.status, equals(AgentRunStatus.cancelled));
      expect(result.message, equals('Cancelled — 1 edit(s) applied.'));
      expect(result.appliedOperations, hasLength(1));
      expect(
        events.any((e) => e.kind == AgentActivityKind.runCancelled),
        isTrue,
      );
      agent.dispose();
    });

    test('pre-cancelled token makes no provider calls', () async {
      final controller = CancellationController()..cancel();
      final provider = _ScriptProvider([
        const AgentTurnResult(
          text: 'Never reached.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(
        validated: _validated(),
        cancellation: controller.token,
      );

      expect(provider.calls, equals(0));
      expect(result.status, equals(AgentRunStatus.cancelled));
      expect(result.message, equals('Cancelled — 0 edit(s) applied.'));
      expect(result.appliedOperations, isEmpty);
      agent.dispose();
    });

    test('activity events arrive in loop order', () async {
      final provider = _ScriptProvider([
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(
              id: 'call_1',
              name: 'mute_clip',
              args: {'clip_id': 'clip_1'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Muted.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );
      final events = <AgentActivityEvent>[];
      final sub = agent.activityEvents.listen(events.add);

      await agent.run(validated: _validated());
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      final kinds = events.map((e) => e.kind).toList();
      expect(
        kinds,
        equals([
          AgentActivityKind.runStarted,
          AgentActivityKind.llmRoundStarted,
          AgentActivityKind.toolCallStarted,
          AgentActivityKind.toolCallCompleted,
          AgentActivityKind.llmRoundCompleted,
          AgentActivityKind.llmRoundStarted,
          AgentActivityKind.llmRoundCompleted,
          AgentActivityKind.runCompleted,
        ]),
      );
      agent.dispose();
    });

    test('dry-run planning round plans without applying', () async {
      final provider = _ScriptProvider([
        const AgentTurnResult(
          text: 'Planning a trim.',
          toolCalls: [
            AgentToolCall(
              id: 'call_plan',
              name: 'trim_clip',
              args: {
                'clip_id': 'clip_1',
                'start': '00:00:05.000',
                'end': '00:00:15.000',
              },
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Plan ready: trim the first clip.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      // Real registry executors against a dry-run context: the edit maps
      // and returns planned, never touching FFmpeg or the applier.
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(dryRun: true),
      );

      final result = await agent.run(validated: _validated());

      expect(result.status, equals(AgentRunStatus.success));
      expect(result.message, equals('Plan ready: trim the first clip.'));
      expect(result.records, hasLength(1));
      expect(result.records.single.success, isTrue);
      expect(result.records.single.summary, startsWith('Would '));
      expect(result.appliedOperations, isEmpty);
      expect(result.outputPath, isNull);
      agent.dispose();
    });

    test('slow local provider suggests 120s per round', () async {
      final provider = _SlowLocalScriptProvider([
        const AgentTurnResult(
          text: 'Trimmed the first 5 seconds.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      expect(result.status, equals(AgentRunStatus.success));
      expect(provider.seen.single.timeoutSeconds, equals(120));
      agent.dispose();
    });

    test('explicit per-run timeout wins over the provider suggestion',
        () async {
      final provider = _SlowLocalScriptProvider([
        const AgentTurnResult(
          text: 'Trimmed the first 5 seconds.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(
        validated: _validated(),
        timeoutSeconds: 30,
      );

      expect(result.status, equals(AgentRunStatus.success));
      expect(provider.seen.single.timeoutSeconds, equals(30));
      agent.dispose();
    });

    test('default providers keep the 60s per-round timeout', () async {
      final provider = _ScriptProvider([
        const AgentTurnResult(
          text: 'Trimmed the first 5 seconds.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      expect(result.status, equals(AgentRunStatus.success));
      expect(provider.seen.single.timeoutSeconds, equals(60));
      agent.dispose();
    });
  });

  group('ToolCallingAgent load_tools', () {
    test('a load unlocks a deferred tool for the next round', () async {
      final provider = _ScriptProvider([
        _loadTurn('load_1', ['apply_effect']),
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(
              id: 'call_1',
              name: 'apply_effect',
              args: {'clip_id': 'clip_1'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Effect applied.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      // Round 1 offers core + loader, not the deferred tool.
      final round1 = provider.seen[0].tools.map((d) => d.name).toList();
      expect(round1, contains('load_tools'));
      expect(round1, contains('trim_clip'));
      expect(round1, isNot(contains('apply_effect')));
      expect(round1.length, lessThanOrEqualTo(16));

      // Round 2 offers the loaded tool; the model uses it normally.
      final round2 = provider.seen[1].tools.map((d) => d.name).toList();
      expect(round2, contains('apply_effect'));

      expect(result.status, equals(AgentRunStatus.success));
      expect(result.message, equals('Effect applied.'));
      expect(provider.calls, equals(3));
      expect(
        result.records.map((r) => r.name),
        equals(['load_tools', 'apply_effect']),
      );
      expect(result.records.every((r) => r.success), isTrue);
      // The executor really ran (stub summary), not the deferred gate.
      expect(result.records.last.summary, equals('ok'));

      // The load result reaches the model as a normal tool result.
      final loadResult = provider.seen[1].history
          .singleWhere((m) => m.toolCallId == 'load_1');
      expect(loadResult.role, equals(AgentTurnRole.toolResult));
      expect(loadResult.toolError, isFalse);
      expect(loadResult.content, contains('apply_effect'));
      agent.dispose();
    });

    test('a loader round does not consume an operation round', () async {
      final provider = _ScriptProvider([
        _loadTurn('load_1', ['resize_clip']),
        for (var i = 0; i < 4; i++)
          AgentTurnResult(
            toolCalls: [
              AgentToolCall(
                id: 'call_$i',
                name: 'mute_clip',
                args: const {'clip_id': 'clip_1'},
              ),
            ],
            stopReason: AgentTurnStopReason.toolCalls,
          ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      // 1 loader round + 4 operation rounds = 5 model round trips.
      expect(provider.calls, equals(5));
      expect(
        result.records.where((r) => r.name == 'load_tools'),
        hasLength(1),
      );
      expect(
        result.records.where((r) => r.name == 'mute_clip'),
        hasLength(4),
      );
      expect(result.message, contains('Stopped after the tool-round limit'));
      agent.dispose();
    });

    test('the budget allows two loads; a third is rejected', () async {
      final provider = _ScriptProvider([
        _loadTurn('load_1', ['resize_clip']),
        _loadTurn('load_2', ['rotate_clip']),
        _loadTurn('load_3', ['apply_effect']),
        const AgentTurnResult(
          text: 'Done.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      // With the budget spent the loader is no longer offered...
      expect(
        provider.seen[2].tools.map((d) => d.name),
        isNot(contains('load_tools')),
      );
      // ...but a third call is still handled with a typed error.
      final loads =
          result.records.where((r) => r.name == 'load_tools').toList();
      expect(loads, hasLength(3));
      expect(loads[0].success, isTrue);
      expect(loads[1].success, isTrue);
      expect(loads[2].success, isFalse);
      expect(loads[2].summary, contains('load limit reached'));
      expect(result.status, equals(AgentRunStatus.success));
      expect(provider.calls, equals(4));
      agent.dispose();
    });

    test('unknown load names return a typed error and load nothing',
        () async {
      final provider = _ScriptProvider([
        _loadTurn('load_1', ['teleport_clip']),
        const AgentTurnResult(
          text: 'No such capability.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      expect(result.records.single.success, isFalse);
      expect(result.records.single.summary, contains('teleport_clip'));
      // The error lists the valid deferred names for self-correction.
      expect(result.records.single.summary, contains('resize_clip'));
      // Nothing was unlocked for the next round.
      expect(
        provider.seen[1].tools.map((d) => d.name),
        isNot(contains('resize_clip')),
      );
      agent.dispose();
    });

    test('a deferred call without a load fails with a loader pointer',
        () async {
      final provider = _ScriptProvider([
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(
              id: 'call_d',
              name: 'apply_effect',
              args: {'clip_id': 'clip_1'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'I need to load it first.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      // The executor never ran; the model gets a loader pointer instead.
      expect(result.records.single.success, isFalse);
      expect(
        result.records.single.summary,
        contains('deferred and not loaded'),
      );
      expect(result.records.single.summary, contains('load_tools'));
      expect(result.records.single.summary, contains('loads remaining: 2'));
      agent.dispose();
    });

    test('unknown-tool error lists active tools only, not deferred ones',
        () async {
      final provider = _ScriptProvider([
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(id: 'call_u', name: 'teleport_clip', args: {}),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'No such tool.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      final result = await agent.run(validated: _validated());

      final summary = result.records.single.summary;
      expect(summary, contains('Unknown tool "teleport_clip"'));
      expect(summary, contains('trim_clip'));
      expect(summary, contains('load_tools')); // loader hint while available
      // Deferred catalog tools are not advertised before loading.
      expect(summary, isNot(contains('apply_effect')));
      expect(summary, isNot(contains('resize_clip')));
      agent.dispose();
    });

    test('total model rounds are bounded by both budgets', () async {
      final provider = _ScriptProvider([
        _loadTurn('load_1', ['resize_clip']),
        _loadTurn('load_2', ['rotate_clip']),
        _loadTurn('load_3', ['extract_audio']),
        _loadTurn('load_4', ['burn_captions']),
        _loadTurn('load_5', ['add_transition']),
        _loadTurn('load_6', ['apply_effect']),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );

      // The model never returns plain text and keeps calling the loader.
      final result = await agent.run(validated: _validated());

      expect(
        provider.calls,
        equals(ToolRegistry.maxToolRounds + ToolSelection.maxToolLoads),
      );
      expect(provider.calls, equals(6));
      expect(result.records, hasLength(6));
      expect(result.message, contains('Stopped after the tool budget'));
      agent.dispose();
    });

    test('loader calls bypass the confirmation gates', () async {
      final provider = _ScriptProvider([
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(
              id: 'load_1',
              name: 'load_tools',
              args: {
                'tools': ['resize_clip'],
              },
            ),
            AgentToolCall(
              id: 'e1',
              name: 'mute_clip',
              args: {'clip_id': 'clip_1'},
            ),
            AgentToolCall(
              id: 'e2',
              name: 'mute_clip',
              args: {'clip_id': 'clip_1'},
            ),
            AgentToolCall(
              id: 'e3',
              name: 'mute_clip',
              args: {'clip_id': 'clip_1'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Done.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith({}),
      );
      final gate = _RecordingGate(approve: true);

      final result = await agent.run(validated: _validated(), gate: gate);

      // Only the three edits are gated; the loader never pauses.
      expect(gate.calls, equals(1));
      expect(gate.seen.single.kind, equals(ConfirmationKind.bulk));
      expect(gate.seen.single.toolCalls, hasLength(3));
      expect(
        gate.seen.single.toolCalls.map((c) => c.name),
        isNot(contains('load_tools')),
      );
      expect(
        result.records
            .where((r) => r.name == 'load_tools')
            .single
            .success,
        isTrue,
      );
      expect(
        result.records.where((r) => r.name == 'mute_clip'),
        hasLength(3),
      );
      agent.dispose();
    });
  });

  group('ToolCallingAgent tag/marker commands', () {
    const createTagCall = AgentToolCall(
      id: 'tag_call',
      name: 'create_tag',
      args: {'name': 'Music', 'color': '#AABBCC'},
    );

    test('a tag command before load_tools never reaches the gateway',
        () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final provider = _ScriptProvider([
        const AgentTurnResult(
          toolCalls: [createTagCall],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'I need to load it first.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(gateway: gateway),
      );

      final result = await agent.run(validated: _validated());

      expect(result.records.single.success, isFalse);
      expect(
        result.records.single.summary,
        contains('deferred and not loaded'),
      );
      expect(result.records.single.summary, contains('load_tools'));
      expect(gateway.batches, isEmpty);
      agent.dispose();
    });

    test('load_tools unlocks create_tag and the command reaches the gateway',
        () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final provider = _ScriptProvider([
        _loadTurn('load_1', ['create_tag']),
        const AgentTurnResult(
          toolCalls: [createTagCall],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Tag created.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(gateway: gateway),
      );

      final result = await agent.run(validated: _validated());

      // Round 1 hides the deferred command; round 2 offers it.
      expect(
        provider.seen[0].tools.map((d) => d.name),
        isNot(contains('create_tag')),
      );
      expect(
        provider.seen[1].tools.map((d) => d.name),
        contains('create_tag'),
      );

      expect(
        result.records.map((r) => r.name),
        equals(['load_tools', 'create_tag']),
      );
      expect(result.records.last.success, isTrue);
      expect(result.records.last.summary, contains('Created tag'));

      // The command really executed through the gateway and advanced state.
      expect(gateway.appliedCommands.single, isA<CreateTagCommand>());
      expect(
        gateway.state!.tags.map((tag) => tag.name),
        contains('Music'),
      );
      agent.dispose();
    });
  });
}

