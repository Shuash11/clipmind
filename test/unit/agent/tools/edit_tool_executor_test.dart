import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
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

/// Handle-trimmed fixture: `clip_1` spans `[5000, 60000)` (clipSpan 55000)
/// so `clipSpan != fileLen` — the ranged-cut mismatch case.
Project _rangedProject(String inputA, String inputB, String outDir) {
  final base = _project(inputA, inputB, outDir);
  final track = base.tracks.first;
  final clips = [
    track.clips.first.copyWith(startMs: 5000, endMs: 60000),
    track.clips[1],
  ];
  return base.copyWith(
    tracks: [track.copyWith(clips: clips)],
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

  ToolExecutionContext ctx({
    CancellationToken? cancellation,
    bool dryRun = false,
    int? maxJobs,
  }) {
    final project = _project(inputA, inputB, outDir);
    return ToolExecutionContext(
      project: () => project,
      outputDir: outDir,
      projectDir: tmp.path,
      applier: AgentEditApplier(
        onApply: (op, path, {removeClipIds = const []}) async {
          applied.add(_Applied(op, path));
        },
      ),
      ffmpegService: ffmpeg,
      ffprobeService: _MockFfprobe(),
      cancellation: cancellation,
      dryRun: dryRun,
      maxJobs: maxJobs ?? 20,
    );
  }

  ToolExecutionContext rangedCtx() {
    final project = _rangedProject(inputA, inputB, outDir);
    return ToolExecutionContext(
      project: () => project,
      outputDir: outDir,
      projectDir: tmp.path,
      applier: AgentEditApplier(
        onApply: (op, path, {removeClipIds = const []}) async {
          applied.add(_Applied(op, path));
        },
      ),
      ffmpegService: ffmpeg,
      ffprobeService: _MockFfprobe(),
      cancellation: null,
      dryRun: false,
      maxJobs: 20,
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

    test('trim carries the new output range (stale-range fix)', () async {
      final executor = EditToolExecutor(ctx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_trim_range',
          name: 'trim_clip',
          args: {
            'clip_id': 'clip_1',
            'start': '00:00:05.000',
            'end': '00:00:15.000',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(applied, hasLength(1));
      // clip_1 spans [0, 60000]; the trim keeps 10s of content, so the
      // rendered output normalizes to [0, 10000].
      expect(applied.single.op.params['new_start_ms'], equals(0));
      expect(applied.single.op.params['new_end_ms'], equals(10000));
    });

    test('cut carries the new output range (stale-range fix)', () async {
      final executor = EditToolExecutor(ctx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_cut_range',
          name: 'cut_segment',
          args: {
            'clip_id': 'clip_1',
            'remove_start': '00:00:10.000',
            'remove_end': '00:00:20.000',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(applied, hasLength(1));
      // clip_1 spans [0, 60000] (60s); removing a 10s segment leaves 50s
      // of content, so the rendered output normalizes to [0, 50000].
      expect(applied.single.op.params['new_start_ms'], equals(0));
      expect(applied.single.op.params['new_end_ms'], equals(50000));
    });

    test(
        'cut on a ranged clip composes -ss/-t with shifted between '
        '(ranged-cut fix)', () async {
      final executor = EditToolExecutor(rangedCtx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_cut_ranged',
          name: 'cut_segment',
          args: {
            'clip_id': 'clip_1',
            // File times inside the [5000, 60000) clip span.
            'remove_start': '00:00:10.000',
            'remove_end': '00:00:20.000',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(applied, hasLength(1));
      // clipSpan 55000 − removed 10000 → [0, 45000].
      expect(applied.single.op.params['new_start_ms'], equals(0));
      expect(applied.single.op.params['new_end_ms'], equals(45000));
      // The executor carries the live extent for the mapper.
      expect(applied.single.op.params['clip_start_s'], equals(5.0));
      expect(applied.single.op.params['clip_len_s'], equals(55.0));

      // The FFmpeg job restricts the input and shifts the remove times:
      // file [10, 20] − clipStart 5 → clip-relative [5.0, 15.0].
      expect(ffmpeg.lastJob, isNotNull);
      final args = ffmpeg.lastJob!.args;
      expect(args, containsAll(['-ss', '5.0', '-t', '55.0']));
      expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
      final joined = args.join(' ');
      expect(joined, contains('between(t,5.0,15.0)'));

      // Consistency: the restricted output length (55 − 10 = 45s) equals
      // the propagated new range (45000ms) — the actual output length.
      final tIndex = args.indexOf('-t');
      final clipDurationSec = double.parse(args[tIndex + 1]);
      const removedLenSec = 10.0;
      final outputLenMs = ((clipDurationSec - removedLenSec) * 1000).round();
      expect(outputLenMs, equals(45000));
      expect(
        applied.single.op.params['new_end_ms'],
        equals(outputLenMs),
      );
    });

    test(
        'cut with clipSpan == fileLen is equivalent to the legacy path '
        '(behavior-preserving)', () async {
      final executor = EditToolExecutor(ctx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_cut_equiv',
          name: 'cut_segment',
          args: {
            'clip_id': 'clip_1',
            'remove_start': '00:00:10.000',
            'remove_end': '00:00:20.000',
          },
        ),
      );

      expect(result.success, isTrue);
      final args = ffmpeg.lastJob!.args;
      // Zero in-point: the composition restricts to the whole file and the
      // shifted times equal the originals numerically.
      expect(args, containsAll(['-ss', '0.0', '-t', '60.0']));
      expect(args.join(' '), contains('between(t,10.0,20.0)'));
      expect(applied.single.op.params['new_end_ms'], equals(50000));

      // Semantic equivalence with today's whole-file path.
      final legacy = CommandBuilder.cut(
        inputA,
        '00:00:10.000',
        '00:00:20.000',
      );
      expect(legacy.contains('-ss'), isFalse);
      expect(
        legacy.join(' '),
        contains('between(t,00:00:10.000,00:00:20.000)'),
      );
      // Both describe the same 10s removal: 60 − 10 = 50s of output.
      expect(
        CommandBuilder.shiftedCutTime('00:00:10.000', 0.0),
        equals('10.0'),
      );
      expect(
        CommandBuilder.shiftedCutTime('00:00:20.000', 0.0),
        equals('20.0'),
      );
    });

    test('stage_5 mapper passes the clip range to CommandBuilder.cut',
        () async {
      final clipPathMap = { 'clip_1': inputA, '_default': inputA };

      // Single-job path with range → restricted input + shifted times.
      final single = CommandMapper.mapOperations(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_cut_single',
              type: 'cut',
              targetClipId: 'clip_1',
              params: {
                'remove_start': '00:00:10.000',
                'remove_end': '00:00:20.000',
                'clip_start_s': 5.0,
                'clip_len_s': 55.0,
              },
            ),
          ],
          summary: 'cut',
        ),
        clipPathMap,
        outDir,
     );
      expect(single, hasLength(1));
      expect(
        single.single.args,
        containsAll(['-ss', '5.0', '-t', '55.0']),
      );
      expect(single.single.args.join(' '), contains('between(t,5.0,15.0)'));

      // Absent range → legacy whole-file path, unchanged behavior.
      final legacy = CommandMapper.mapOperations(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_cut_legacy',
              type: 'cut',
              targetClipId: 'clip_1',
              params: {
                'remove_start': '00:00:10.000',
                'remove_end': '00:00:20.000',
              },
            ),
          ],
          summary: 'cut',
        ),
        clipPathMap,
        outDir,
      );
      expect(legacy.single.args.contains('-ss'), isFalse);
      expect(
        legacy.single.args.join(' '),
        contains('between(t,00:00:10.000,00:00:20.000)'),
      );

      // Composed path (cut + volume) with range → same restriction.
      final composed = CommandMapper.mapOperations(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_cut_composed',
              type: 'cut',
              targetClipId: 'clip_1',
              params: {
                'remove_start': '00:00:10.000',
                'remove_end': '00:00:20.000',
                'clip_start_s': 5.0,
                'clip_len_s': 55.0,
              },
            ),
            EditOperationRequest(
              id: 'op_vol',
              type: 'change_volume',
              targetClipId: 'clip_1',
              params: {'factor': 1.0},
            ),
          ],
          summary: 'cut+volume',
        ),
        clipPathMap,
        outDir,
      );
      expect(composed, hasLength(1));
      expect(
        composed.single.args,
        containsAll(['-ss', '5.0', '-t', '55.0']),
      );
      expect(composed.single.args.join(' '), contains('between(t,5.0,15.0)'));
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

    test('cancelled-before-job fails fast without running FFmpeg', () async {
      final controller = CancellationController()..cancel();
      final executor = EditToolExecutor(
        ctx(cancellation: controller.token),
      );
      final result = await executor.execute(
        const ToolCall(
          id: 'call_cancel',
          name: 'trim_clip',
          args: {
            'clip_id': 'clip_1',
            'start': '00:00:05.000',
            'end': '00:00:15.000',
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Cancelled'));
      expect(ffmpeg.lastJob, isNull);
      expect(applied, isEmpty);
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

  group('EditToolExecutor dry-run (plan preview)', () {
    test('dry-run plans without executing FFmpeg or journaling', () async {
      final executor = EditToolExecutor(ctx(dryRun: true));
      final result = await executor.execute(
        const ToolCall(
          id: 'call_plan',
          name: 'trim_clip',
          args: {
            'clip_id': 'clip_1',
            'start': '00:00:05.000',
            'end': '00:00:15.000',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.data['planned'], isTrue);
      expect(result.data['op_type'], equals('trim'));
      expect(result.data['target_clip_ids'], equals(['clip_1']));
      expect(result.summary, startsWith('Would '));
      // Nothing executed, applied, or journaled.
      expect(ffmpeg.lastJob, isNull);
      expect(applied, isEmpty);
    });

    test('dry-run still validates args', () async {
      final executor = EditToolExecutor(ctx(dryRun: true));
      final result = await executor.execute(
        const ToolCall(
          id: 'call_bad',
          name: 'trim_clip',
          args: {'clip_id': 'clip_1', 'start': 'nope', 'end': '15'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('HH:MM:SS.mmm'));
      expect(result.data.containsKey('planned'), isFalse);
    });

    test('dry-run still enforces the edit budget', () async {
      final executor = EditToolExecutor(ctx(dryRun: true, maxJobs: 0));
      final result = await executor.execute(
        const ToolCall(
          id: 'call_over',
          name: 'mute_clip',
          args: {'clip_id': 'clip_1'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('budget'));
    });
  });
}
