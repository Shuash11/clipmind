import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';

class _StubProvider extends LlmProvider {
  final EditOperationSet response;
  _StubProvider(this.response);

  @override
  String get id => 'stub';

  @override
  Future<List<String>> availableModels() async => ['stub-model'];

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) async => response;

  @override
  Stream<ConnectionStatus> watchConnection() =>
      Stream.value(ConnectionStatus.connected);
}

/// Scripted tool-capable provider: one canned turn per round.
class _ScriptToolProvider extends LlmProvider {
  final List<AgentTurnResult> script;
  int calls = 0;

  _ScriptToolProvider(this.script);

  @override
  String get id => 'script-tools';

  @override
  bool get supportsToolCalling => true;

  @override
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) async =>
      script[calls++];

  @override
  Future<List<String>> availableModels() async => ['script'];

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) =>
      throw UnimplementedError();

  @override
  Stream<ConnectionStatus> watchConnection() =>
      Stream.value(ConnectionStatus.connected);
}

class _FakeFfmpegService extends FfmpegService {
  _FakeFfmpegService() : super(tempDir: Directory.systemTemp.path);

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    final out = File(job.outputPath);
    await out.parent.create(recursive: true);
    await out.writeAsString('fake-video');
    return FfmpegResult(success: true, outputPath: job.outputPath, exitCode: 0);
  }
}

Project _projectWithClip({
  required String clipId,
  required String sourcePath,
  required String outputDir,
}) {
  const trackId = 'track_1';
  return Project(
    id: 'project_1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: [sourcePath],
    tracks: [
      Track(
        id: trackId,
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: clipId,
            trackId: trackId,
            sourcePath: sourcePath,
            startMs: 0,
            endMs: 60000,
          ),
        ],
      ),
    ],
    durationMs: 60000,
    outputDir: outputDir,
  );
}

void main() {
  group('CommandMapper path resolution', () {
    test('uses real file path, never the clip ID, in -i args', () {
      const set = EditOperationSet(
        operations: [
          EditOperationRequest(
            id: 'op_1',
            type: 'trim',
            targetClipId: 'clip_1',
            params: {'start': '00:00:05.000', 'end': '00:00:15.000'},
          ),
        ],
        summary: 'trim',
      );
      const realPath = r'C:\videos\input.mp4';
      final jobs = CommandMapper.mapOperations(
        set,
        {'clip_1': realPath},
        r'C:\projects\out',
        defaultPath: realPath,
      );

      expect(jobs, hasLength(1));
      expect(jobs.first.inputPath, equals(realPath));
      expect(jobs.first.args, contains(realPath));
      expect(jobs.first.args.any((a) => a == 'clip_1'), isFalse);
    });

    test('writes output into the project outputDir, not CWD', () {
      const set = EditOperationSet(
        operations: [
          EditOperationRequest(
            id: 'op_9',
            type: 'trim',
            targetClipId: 'clip_1',
            params: {'start': '0', 'end': '5'},
          ),
        ],
        summary: 'trim',
      );
      const realPath = r'C:\videos\input.mp4';
      const outDir = r'C:\projects\out';
      final jobs = CommandMapper.mapOperations(
        set,
        {'clip_1': realPath},
        outDir,
        defaultPath: realPath,
      );

      expect(jobs.first.outputPath.startsWith(outDir), isTrue);
    });

    test('merge resolves clip IDs to real paths', () {
      const set = EditOperationSet(
        operations: [
          EditOperationRequest(
            id: 'op_m',
            type: 'merge',
            targetClipId: 'clip_1',
            params: {
              'clip_ids': ['clip_1', 'clip_2']
            },
          ),
        ],
        summary: 'merge',
      );
      final jobs = CommandMapper.mapOperations(
        set,
        {'clip_1': r'C:\v\a.mp4', 'clip_2': r'C:\v\b.mp4'},
        r'C:\out',
        defaultPath: r'C:\v\a.mp4',
      );

      expect(jobs, hasLength(1));
      final joined = jobs.first.args.join(' ');
      expect(joined, contains(r'C:\v\a.mp4'));
      expect(joined, contains(r'C:\v\b.mp4'));
    });

    test('unknown clip ID throws a clear error', () {
      const set = EditOperationSet(
        operations: [
          EditOperationRequest(
            id: 'op_x',
            type: 'trim',
            targetClipId: 'nope',
            params: {'start': '0', 'end': '5'},
          ),
        ],
        summary: 'trim',
      );
      expect(
        () => CommandMapper.mapOperations(
          set,
          {'clip_1': r'C:\v\a.mp4'},
          r'C:\out',
          defaultPath: r'C:\v\a.mp4',
        ),
        throwsA(
          isA<CommandMappingException>().having(
            (e) => e.message,
            'message',
            contains('Unknown clip'),
          ),
        ),
      );
    });

    test('numeric LLM params do not crash safe casts', () {
      const set = EditOperationSet(
        operations: [
          EditOperationRequest(
            id: 'op_n',
            type: 'overlay_text',
            targetClipId: 'clip_1',
            params: {
              'text': 'Hi',
              'position': 'center',
              'font_size': 48,
              'color': '#FFFFFF',
              'start': 5,
              'end': 15,
            },
          ),
        ],
        summary: 'text',
      );
      final jobs = CommandMapper.mapOperations(
        set,
        {'clip_1': r'C:\v\a.mp4'},
        r'C:\out',
        defaultPath: r'C:\v\a.mp4',
      );
      expect(jobs, hasLength(1));
      expect(jobs.first.args.join(' '), contains('between(t,5,15)'));
    });
  });

  group('Nl2VecPipeline.submitCommand', () {
    test('returns typed error when project has no video file', () async {
      final pipeline = Nl2VecPipeline(ffmpegService: _FakeFfmpegService());
      final emptyProject = Project(
        id: 'empty',
        name: 'Empty',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        sourceMediaPaths: [],
        tracks: [],
        durationMs: 0,
        outputDir: '',
      );
      final stub = _StubProvider(
        const EditOperationSet(operations: [], summary: 'noop'),
      );

      final result = await pipeline.submitCommand(
        'Trim the first 5 seconds',
        emptyProject,
        provider: stub,
      );

      expect(result.status, equals(SubmitStatus.error));
      expect(result.message, contains('No video file in project'));
      expect(result.appliedOperations, isEmpty);
      pipeline.dispose();
    });

    test('trim runs against the real path and reports typed success',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_pipeline_test_');
      try {
        final input = File('${tmp.path}/input.mp4');
        await input.writeAsString('source');
        final outDir = Directory('${tmp.path}/out');
        await outDir.create();

        final project = _projectWithClip(
          clipId: 'clip_1',
          sourcePath: input.path,
          outputDir: outDir.path,
        );
        final stub = _StubProvider(
          const EditOperationSet(
            operations: [
              EditOperationRequest(
                id: 'op_1',
                type: 'trim',
                targetClipId: 'clip_1',
                params: {'start': '5', 'end': '15'},
              ),
            ],
            summary: 'Trimmed first 5 seconds',
          ),
        );

        final applied = <EditOperation>[];
        final appliedPaths = <String>[];
        final applier = AgentEditApplier(
          onApply: (op, path, {removeClipIds = const []}) async {
            applied.add(op);
            appliedPaths.add(path);
          },
        );

        final pipeline = Nl2VecPipeline(ffmpegService: _FakeFfmpegService());
        final result = await pipeline.submitCommand(
          'Trim the first 5 seconds',
          project,
          provider: stub,
          applier: applier,
        );

        expect(result.status, equals(SubmitStatus.success));
        expect(result.appliedOperations, hasLength(1));
        expect(result.appliedOperations.first.targetClipIds,
            equals(['clip_1']));
        expect(result.appliedOperations.first.status,
            equals(OperationStatus.applied));
        expect(result.outputPath, isNotNull);
        expect(result.outputPath!.startsWith(outDir.path), isTrue);
        // Applier was notified with the real output path.
        expect(applied, hasLength(1));
        expect(appliedPaths.single, equals(result.outputPath));
        // FFmpeg command references the real file, never the clip ID.
        expect(
          result.appliedOperations.first.ffmpegCommand,
          contains(input.path),
        );
        expect(
          result.appliedOperations.first.ffmpegCommand,
          isNot(contains('clip_1')),
        );
        pipeline.dispose();
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('tool-capable provider routes through the agent loop', () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_tool_gate_');
      try {
        final input = File('${tmp.path}/input.mp4');
        await input.writeAsString('source');
        final outDir = Directory('${tmp.path}/out');
        await outDir.create();

        final project = _projectWithClip(
          clipId: 'clip_1',
          sourcePath: input.path,
          outputDir: outDir.path,
        );
        final script = _ScriptToolProvider([
          const AgentTurnResult(
            toolCalls: [
              AgentToolCall(
                id: 'call_1',
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
            text: 'Trimmed and muted.',
            stopReason: AgentTurnStopReason.stop,
          ),
        ]);

        final applied = <EditOperation>[];
        final applier = AgentEditApplier(
          onApply: (op, path, {removeClipIds = const []}) async {
            applied.add(op);
          },
        );

        final pipeline = Nl2VecPipeline(ffmpegService: _FakeFfmpegService());
        final result = await pipeline.submitCommand(
          'Trim the first 5 seconds',
          project,
          provider: script,
          applier: applier,
          liveProject: () => project,
        );

        expect(script.calls, equals(2));
        expect(result.status, equals(SubmitStatus.success));
        expect(result.message, equals('Trimmed and muted.'));
        expect(result.appliedOperations, hasLength(1));
        expect(result.outputPath, isNotNull);
        expect(result.outputPath!.startsWith(outDir.path), isTrue);
        expect(applied, hasLength(1));
        expect(applied.single.targetClipIds, equals(['clip_1']));
        pipeline.dispose();
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });
}
