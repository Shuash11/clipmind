import 'package:clipmind/core/async/cancellation_token.dart';
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
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptProvider extends LlmProvider {
  final List<AgentTurnResult> script;
  int calls = 0;

  _ScriptProvider(this.script);

  @override
  String get id => 'script';

  @override
  bool get supportsToolCalling => true;

  @override
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) async {
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

class _CountingExecutor implements ToolExecutor {
  int calls = 0;
  final List<String> seenIds = [];

  @override
  Future<ToolResult> execute(ToolCall call) async {
    calls++;
    seenIds.add(call.id);
    return ToolResult.ok(summary: 'ok ${call.name}');
  }
}

class _BulkGate implements ConfirmationGate {
  final bool approve;
  int calls = 0;
  final List<ConfirmationRequest> seen = [];

  _BulkGate({required this.approve});

  @override
  bool get requiresPerEditApproval => false;

  @override
  Future<bool> ask(ConfirmationRequest request) async {
    calls++;
    seen.add(request);
    return approve;
  }
}

class _PerEditGate implements ConfirmationGate {
  final bool approve;
  int calls = 0;
  final List<ConfirmationRequest> seen = [];

  _PerEditGate({required this.approve});

  @override
  bool get requiresPerEditApproval => true;

  @override
  Future<bool> ask(ConfirmationRequest request) async {
    calls++;
    seen.add(request);
    return approve;
  }
}

class _CancelGate implements ConfirmationGate {
  final CancellationController controller;
  int calls = 0;

  _CancelGate(this.controller);

  @override
  bool get requiresPerEditApproval => false;

  @override
  Future<bool> ask(ConfirmationRequest request) async {
    calls++;
    controller.cancel();
    // Slow approval loses the race against the already-fired token,
    // so the domain proceeds as denied without hanging.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return true;
  }
}

ToolRegistry _registryWith(_CountingExecutor counter) {
  final base = <String, ToolExecutor>{
    for (final d in ToolRegistry.defaultDefinitions()) d.name: counter,
  };
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

AgentToolCall _edit(String id, String name) => AgentToolCall(
      id: id,
      name: name,
      args: const {'clip_id': 'clip_1'},
    );

void main() {
  group('ConfirmationGate', () {
    test('bulk approve: >=3 edits pause once then execute', () async {
      final provider = _ScriptProvider([
        AgentTurnResult(
          toolCalls: [
            _edit('c1', 'mute_clip'),
            _edit('c2', 'mute_clip'),
            _edit('c3', 'mute_clip'),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Done.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final counter = _CountingExecutor();
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith(counter),
      );
      final gate = _BulkGate(approve: true);
      final events = <AgentActivityEvent>[];
      final sub = agent.activityEvents.listen(events.add);

      final result = await agent.run(
        validated: _validated(),
        gate: gate,
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(gate.calls, equals(1));
      expect(gate.seen.single.kind, equals(ConfirmationKind.bulk));
      expect(gate.seen.single.toolCalls, hasLength(3));
      expect(counter.calls, equals(3));
      expect(result.status, equals(AgentRunStatus.success));
      expect(result.records, hasLength(3));
      expect(result.records.every((r) => r.success), isTrue);
      expect(
        events.any((e) => e.kind == AgentActivityKind.confirmationRequested),
        isTrue,
      );
      final resolved = events.firstWhere(
        (e) => e.kind == AgentActivityKind.confirmationResolved,
      );
      expect(resolved.success, isTrue);
      agent.dispose();
    });

    test('bulk skip: edits fail as skipped, reads still execute', () async {
      final provider = _ScriptProvider([
        AgentTurnResult(
          toolCalls: [
            const AgentToolCall(
              id: 'r1',
              name: 'list_project_clips',
            ),
            _edit('c1', 'mute_clip'),
            _edit('c2', 'mute_clip'),
            _edit('c3', 'mute_clip'),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Skipped, nothing applied.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final counter = _CountingExecutor();
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith(counter),
      );
      final gate = _BulkGate(approve: false);
      final events = <AgentActivityEvent>[];
      final sub = agent.activityEvents.listen(events.add);

      final result = await agent.run(
        validated: _validated(),
        gate: gate,
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(gate.calls, equals(1));
      // Only the read executed; the 3 edits were skipped.
      expect(counter.calls, equals(1));
      expect(counter.seenIds, equals(['r1']));
      expect(result.status, equals(AgentRunStatus.success));
      expect(result.records, hasLength(4));
      final skipped = result.records.where((r) => r.id != 'r1').toList();
      expect(skipped, hasLength(3));
      for (final r in skipped) {
        expect(r.success, isFalse);
        expect(r.summary, contains('Skipped by user'));
      }
      expect(
        result.records.firstWhere((r) => r.id == 'r1').success,
        isTrue,
      );
      final resolved = events.firstWhere(
        (e) => e.kind == AgentActivityKind.confirmationResolved,
      );
      expect(resolved.success, isFalse);
      agent.dispose();
    });

    test('per-edit: every edit pauses', () async {
      final provider = _ScriptProvider([
        AgentTurnResult(
          toolCalls: [_edit('c1', 'mute_clip'), _edit('c2', 'mute_clip')],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Done.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final counter = _CountingExecutor();
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith(counter),
      );
      final gate = _PerEditGate(approve: true);

      final result = await agent.run(
        validated: _validated(),
        gate: gate,
      );

      expect(gate.calls, equals(2));
      expect(
        gate.seen.every((r) => r.kind == ConfirmationKind.perEdit),
        isTrue,
      );
      expect(
        gate.seen.every((r) => r.toolCalls.length == 1),
        isTrue,
      );
      expect(counter.calls, equals(2));
      expect(result.records.every((r) => r.success), isTrue);
      agent.dispose();
    });

    test('cancel-while-paused proceeds as denied', () async {
      final controller = CancellationController();
      final provider = _ScriptProvider([
        AgentTurnResult(
          toolCalls: [
            _edit('c1', 'mute_clip'),
            _edit('c2', 'mute_clip'),
            _edit('c3', 'mute_clip'),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Never reached.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final counter = _CountingExecutor();
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith(counter),
      );
      final gate = _CancelGate(controller);

      final result = await agent.run(
        validated: _validated(),
        cancellation: controller.token,
        gate: gate,
      );

      expect(gate.calls, equals(1));
      // Nothing executed; all three recorded as denied skips.
      expect(counter.calls, equals(0));
      expect(result.records, hasLength(3));
      for (final r in result.records) {
        expect(r.success, isFalse);
        expect(r.summary, contains('Skipped by user'));
      }
      // The paused round was denied, then the pre-round check cancels.
      expect(result.status, equals(AgentRunStatus.cancelled));
      agent.dispose();
    });

    test('<3 edits with bulk gate causes no pause', () async {
      final provider = _ScriptProvider([
        AgentTurnResult(
          toolCalls: [_edit('c1', 'mute_clip'), _edit('c2', 'mute_clip')],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Done.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final counter = _CountingExecutor();
      final agent = ToolCallingAgent(
        provider: provider,
        context: _context(),
        registry: _registryWith(counter),
      );
      final gate = _BulkGate(approve: false);
      final events = <AgentActivityEvent>[];
      final sub = agent.activityEvents.listen(events.add);

      final result = await agent.run(
        validated: _validated(),
        gate: gate,
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(gate.calls, equals(0));
      expect(counter.calls, equals(2));
      expect(result.records.every((r) => r.success), isTrue);
      expect(
        events.any(
          (e) => e.kind == AgentActivityKind.confirmationRequested,
        ),
        isFalse,
      );
      agent.dispose();
    });
  });
}
