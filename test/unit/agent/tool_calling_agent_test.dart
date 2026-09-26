import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/domain/agent/agent_activity.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_1_input_validation.dart';
import 'package:clipmind/domain/agent/tool_calling_agent.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';

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

// Minimal context: no FFmpeg runs in these loop tests (stub executors,
// so services are never touched).
ToolExecutionContext _context() {
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
    applier: AgentEditApplier(onApply: (_, _) async {}),
    ffmpegService: FfmpegService(),
    ffprobeService: FfprobeService(),
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
      expect(result.message, contains('Stopped after 4 tool rounds'));
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
  });
}

