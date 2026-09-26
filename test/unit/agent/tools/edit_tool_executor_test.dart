import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';

class _MockFfprobe extends Mock implements FfprobeService {}

class _FakeFfmpeg extends FfmpegService {
  FfmpegJob? lastJob;

  _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path);

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    lastJob = job;
    final out = File(job.outputPath);
    await out.parent.create(recursive: true);
    await out.writeAsString('fake');
    return FfmpegResult(success: true, outputPath: job.outputPath, exitCode: 0);
  }
}

class _Applied {
  final EditOperation op;
  final String path;
  _Applied(this.op, this.path);
}

Project _project(String inputA, String inputB, String outDir) {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: [inputA],
    tracks: [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip_1',
            trackId: 't1',
            sourcePath: inputA,
            startMs: 0,
            endMs: 60000,
          ),
          Clip(
            id: 'clip_2',
            trackId: 't1',
            sourcePath: inputB,
            startMs: 0,
            endMs: 30000,
          ),
        ],
      ),
    ],
    durationMs: 90000,
    outputDir: outDir,
  );
}

void main() {
  late Directory tmp;
  late String inputA;
  late String inputB;
  late String outDir;
  late _FakeFfmpeg ffmpeg;
  late List<_Applied> applied;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipmind_edit_tools_');
    inputA = '${tmp.path}/a.mp4';
    inputB = '${tmp.path}/b.mp4';
    outDir = '${tmp.path}/out';
    await File(inputA).writeAsString('a');
    await File(inputB).writeAsString('b');
    await Directory(outDir).create();
    ffmpeg = _FakeFfmpeg();
    applied = [];
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  ToolExecutionContext ctx() {
    final project = _project(inputA, inputB, outDir);
    return ToolExecutionContext(
      project: () => project,
      outputDir: outDir,
      projectDir: tmp.path,
      applier: AgentEditApplier(
        onApply: (op, path) async {
          applied.add(_Applied(op, path));
        },
      ),
      ffmpegService: ffmpeg,
      ffprobeService: _MockFfprobe(),
    );
  }

  group('EditToolExecutor', () {
    test('trim happy path runs job, applies, returns output path', () async {
      final executor = EditToolExecutor(ctx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_trim',
          name: 'trim_clip',
          args: {
            'clip_id': 'clip_1',
            'start': '00:00:05.000',
            'end': '00:00:15.000',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.data['output_path'], isNotNull);
      expect((result.data['output_path'] as String).startsWith(outDir), isTrue);
      expect(result.data['operation_id'], equals('call_trim'));
      // Job ran against the real file, never the clip ID.
      expect(ffmpeg.lastJob, isNotNull);
      expect(ffmpeg.lastJob!.inputPath, equals(inputA));
      expect(ffmpeg.lastJob!.args.any((a) => a == 'clip_1'), isFalse);
      // Applier was notified with the real output path.
      expect(applied, hasLength(1));
      expect(applied.single.path, equals(result.data['output_path']));
      expect(applied.single.op.targetClipIds, equals(['clip_1']));
    });

    test('unknown clip ID fails with actionable message', () async {
      final executor = EditToolExecutor(ctx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_bad',
          name: 'trim_clip',
          args: {
            'clip_id': 'ghost',
            'start': '00:00:05.000',
            'end': '00:00:15.000',
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown clip ID "ghost"'));
      expect(result.error, contains('list_project_clips'));
      expect(ffmpeg.lastJob, isNull);
      expect(applied, isEmpty);
    });

    test('invalid timecode fails with format hint', () async {
      final executor = EditToolExecutor(ctx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_tc',
          name: 'trim_clip',
          args: {'clip_id': 'clip_1', 'start': '5 seconds', 'end': '15'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('HH:MM:SS.mmm'));
      expect(applied, isEmpty);
    });

    test('drawtext injection attempt is rejected', () async {
      final executor = EditToolExecutor(ctx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_inj',
          name: 'overlay_text',
          args: {
            'clip_id': 'clip_1',
            'text': "Hello');scale=-1:-1",
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('filter'));
      expect(ffmpeg.lastJob, isNull);
      expect(applied, isEmpty);
    });

    test('mute produces an -an job', () async {
      final executor = EditToolExecutor(ctx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_mute',
          name: 'mute_clip',
          args: {'clip_id': 'clip_1'},
        ),
      );

      expect(result.success, isTrue);
      expect(ffmpeg.lastJob!.args, contains('-an'));
    });

    test('merge resolves every clip ID to a real path', () async {
      final executor = EditToolExecutor(ctx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_merge',
          name: 'merge_clips',
          args: {
            'clip_ids': ['clip_1', 'clip_2']
          },
        ),
      );

      expect(result.success, isTrue);
      final joined = ffmpeg.lastJob!.args.join(' ');
      expect(joined, contains(inputA));
      expect(joined, contains(inputB));
      expect(joined.contains('clip_1') && joined.contains('-i clip_1'), isFalse);
    });
  });
}
