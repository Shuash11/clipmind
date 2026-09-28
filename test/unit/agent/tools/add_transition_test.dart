import 'dart:io';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/stage_6_execution.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFfprobe extends Mock implements FfprobeService {}

class _FakeFfmpeg extends FfmpegService {
  _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path);

  final List<FfmpegJob> jobs = [];

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    jobs.add(job);
    final out = File(job.outputPath);
    await out.parent.create(recursive: true);
    await out.writeAsString('fake-video');
    return FfmpegResult(
      success: true,
      outputPath: job.outputPath,
      exitCode: 0,
    );
  }
}

class _Applied {
  final EditOperation op;
  final String path;
  final List<String> removeClipIds;
  _Applied(this.op, this.path, this.removeClipIds);
}

const _metaA = VideoMetadata(
  durationMs: 60000,
  width: 1920,
  height: 1080,
  fps: 30,
  codec: 'h264',
  hasAudio: true,
  bitrate: 1000,
);

const _metaB = VideoMetadata(
  durationMs: 30000,
  width: 1920,
  height: 1080,
  fps: 30,
  codec: 'h264',
  hasAudio: true,
  bitrate: 1000,
);

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
  group('CommandBuilder.transition', () {
    test('builds xfade + acrossfade with offset', () {
      final args = CommandBuilder.transition(
        '/v/a.mp4',
        '/v/b.mp4',
        transition: 'fade',
        duration: 0.5,
        offset: 59.5,
        hasAudio: true,
      );
      expect(
        args,
        equals([
          '-i',
          '/v/a.mp4',
          '-i',
          '/v/b.mp4',
          '-filter_complex',
          '[0:v][1:v]xfade=transition=fade:duration=0.5:offset=59.5[outv];'
              '[0:a][1:a]acrossfade=d=0.5[outa]',
          '-map',
          '[outv]',
          '-map',
          '[outa]',
        ]),
      );
    });

    test('no audio maps video only', () {
      final args = CommandBuilder.transition(
        '/v/a.mp4',
        '/v/b.mp4',
        hasAudio: false,
      );
      expect(args, contains('-an'));
      expect(args.join(' '), isNot(contains('acrossfade')));
      expect(args.join(' '), isNot(contains('[outa]')));
    });

    test('duration clamps to the doc-verified 0–60 range', () {
      final args = CommandBuilder.transition(
        '/v/a.mp4',
        '/v/b.mp4',
        duration: 999,
        offset: -5,
      );
      expect(args.join(' '), contains('duration=60.0'));
      expect(args.join(' '), contains('offset=0.0'));
    });
  });

  group('add_transition executor', () {
    late Directory tmp;
    late String inputA;
    late String inputB;
    late String outDir;
    late _FakeFfmpeg ffmpeg;
    late _MockFfprobe ffprobe;
    late List<_Applied> applied;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_transition_');
      inputA = '${tmp.path}/a.mp4';
      inputB = '${tmp.path}/b.mp4';
      outDir = '${tmp.path}/out';
      await File(inputA).writeAsString('a');
      await File(inputB).writeAsString('b');
      await Directory(outDir).create();
      ffmpeg = _FakeFfmpeg();
      ffprobe = _MockFfprobe();
      when(() => ffprobe.extractMetadata(inputA))
          .thenAnswer((_) async => _metaA);
      when(() => ffprobe.extractMetadata(inputB))
          .thenAnswer((_) async => _metaB);
      applied = [];
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    ToolExecutionContext ctx({
      CancellationToken? cancellation,
      int? maxJobs,
    }) {
      return ToolExecutionContext(
        project: () => _project(inputA, inputB, outDir),
        outputDir: outDir,
        projectDir: tmp.path,
        applier: AgentEditApplier(
          onApply: (op, path, {removeClipIds = const []}) async {
            applied.add(_Applied(op, path, List.of(removeClipIds)));
          },
        ),
        ffmpegService: ffmpeg,
        ffprobeService: ffprobe,
        cancellation: cancellation,
        maxJobs: maxJobs ?? 20,
      );
    }

    Future<ToolResult> call(
      ToolExecutionContext c,
      String name, [
      Map<String, dynamic> args = const {},
    ]) {
      return EditToolExecutor(c).execute(
        ToolCall(id: 'call_1', name: name, args: args),
      );
    }

    test('happy path replaces the pair with one merged clip', () async {
      final result = await call(ctx(), 'add_transition', {
        'clip_id': 'clip_1',
        'second_clip_id': 'clip_2',
        'transition': 'dissolve',
        'duration': 1.0,
      });

      expect(result.success, isTrue);
      expect(
        result.summary,
        equals('Added dissolve transition (1.0s) between "clip_1" and "clip_2".'),
      );
      // xfade job against both real paths; offset = 60 − 1.
      final joined = ffmpeg.jobs.single.args.join(' ');
      expect(joined, contains(inputA));
      expect(joined, contains(inputB));
      expect(joined, contains('xfade=transition=dissolve'));
      expect(joined, contains('duration=1.0'));
      expect(joined, contains('offset=59.0'));
      expect(joined, contains('acrossfade'));
      // Applier replaces the pair: second clip removed.
      expect(applied, hasLength(1));
      expect(applied.single.removeClipIds, equals(['clip_2']));
      expect(
        applied.single.op.type,
        equals(EditOperationType.addTransition),
      );
      expect(
        applied.single.op.targetClipIds,
        equals(['clip_1', 'clip_2']),
      );
      expect(
        applied.single.op.params['clip_ids'],
        equals(['clip_1', 'clip_2']),
      );
    });

    test('defaults apply: fade at 0.5s', () async {
      final result = await call(ctx(), 'add_transition', {
        'clip_id': 'clip_1',
        'second_clip_id': 'clip_2',
      });

      expect(result.success, isTrue);
      expect(result.summary, contains('fade transition (0.5s)'));
      expect(
        ffmpeg.jobs.single.args.join(' '),
        contains('offset=59.5'),
      );
    });

    test('silent inputs skip the audio crossfade', () async {
      when(() => ffprobe.extractMetadata(inputA)).thenAnswer(
        (_) async => const VideoMetadata(
          durationMs: 60000,
          width: 1920,
          height: 1080,
          fps: 30,
          codec: 'h264',
          hasAudio: false,
          bitrate: 1000,
        ),
      );
      when(() => ffprobe.extractMetadata(inputB)).thenAnswer(
        (_) async => const VideoMetadata(
          durationMs: 30000,
          width: 1920,
          height: 1080,
          fps: 30,
          codec: 'h264',
          hasAudio: false,
          bitrate: 1000,
        ),
      );

      final result = await call(ctx(), 'add_transition', {
        'clip_id': 'clip_1',
        'second_clip_id': 'clip_2',
      });

      expect(result.success, isTrue);
      final joined = ffmpeg.jobs.single.args.join(' ');
      expect(joined, contains('-an'));
      expect(joined, isNot(contains('acrossfade')));
    });

    test('resolution mismatch fails with a resize hint', () async {
      when(() => ffprobe.extractMetadata(inputB)).thenAnswer(
        (_) async => const VideoMetadata(
          durationMs: 30000,
          width: 1280,
          height: 720,
          fps: 30,
          codec: 'h264',
          hasAudio: true,
          bitrate: 1000,
        ),
      );

      final result = await call(ctx(), 'add_transition', {
        'clip_id': 'clip_1',
        'second_clip_id': 'clip_2',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('1920x1080 vs 1280x720'));
      expect(result.error, contains('resize_clip'));
      expect(ffmpeg.jobs, isEmpty);
      expect(applied, isEmpty);
    });

    test('fps mismatch fails actionably', () async {
      when(() => ffprobe.extractMetadata(inputB)).thenAnswer(
        (_) async => const VideoMetadata(
          durationMs: 30000,
          width: 1920,
          height: 1080,
          fps: 25,
          codec: 'h264',
          hasAudio: true,
          bitrate: 1000,
        ),
      );

      final result = await call(ctx(), 'add_transition', {
        'clip_id': 'clip_1',
        'second_clip_id': 'clip_2',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('frame rate'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('unavailable metadata proceeds with a caution', () async {
      when(() => ffprobe.extractMetadata(any()))
          .thenAnswer((_) async => null);

      final result = await call(ctx(), 'add_transition', {
        'clip_id': 'clip_1',
        'second_clip_id': 'clip_2',
      });

      expect(result.success, isTrue);
      expect(result.summary, contains('could not be verified'));
      expect(ffmpeg.jobs, hasLength(1));
    });

    test('unknown second clip fails without touching FFmpeg', () async {
      final result = await call(ctx(), 'add_transition', {
        'clip_id': 'clip_1',
        'second_clip_id': 'ghost',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown clip ID "ghost"'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('same clip twice fails actionably', () async {
      final result = await call(ctx(), 'add_transition', {
        'clip_id': 'clip_1',
        'second_clip_id': 'clip_1',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('two different clips'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('unknown transition names the supported set', () async {
      final result = await call(ctx(), 'add_transition', {
        'clip_id': 'clip_1',
        'second_clip_id': 'clip_2',
        'transition': 'starwipe',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown transition "starwipe"'));
      expect(result.error, contains('fade'));
      expect(result.error, contains('dissolve'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('non-positive duration fails actionably', () async {
      final result = await call(ctx(), 'add_transition', {
        'clip_id': 'clip_1',
        'second_clip_id': 'clip_2',
        'duration': 0,
      });

      expect(result.success, isFalse);
      expect(result.error, contains('duration'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('budget and cancellation are enforced before work', () async {
      final overBudget = await call(
        ctx(maxJobs: 0),
        'add_transition',
        {'clip_id': 'clip_1', 'second_clip_id': 'clip_2'},
      );
      expect(overBudget.success, isFalse);
      expect(overBudget.error, contains('budget'));

      final controller = CancellationController()..cancel();
      final cancelled = await call(
        ctx(cancellation: controller.token),
        'add_transition',
        {'clip_id': 'clip_1', 'second_clip_id': 'clip_2'},
      );
      expect(cancelled.success, isFalse);
      expect(cancelled.error, contains('Cancelled'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('merge_clips now removes all-but-first (no double content)',
        () async {
      final result = await call(ctx(), 'merge_clips', {
        'clip_ids': ['clip_1', 'clip_2'],
      });

      expect(result.success, isTrue);
      expect(applied, hasLength(1));
      expect(applied.single.removeClipIds, equals(['clip_2']));
    });

    test('engine classifies xfade jobs as add_transition', () async {
      final engine = ExecutionEngine(ffmpeg);
      final events = <ExecutionProgress>[];
      final sub = engine.progress.listen(events.add);
      final job = FfmpegJob(
        id: 'job_1',
        args: CommandBuilder.transition('/v/a.mp4', '/v/b.mp4'),
        expectedDurationMs: 0,
        inputPath: '/v/a.mp4',
        outputPath: '${tmp.path}/out/j.mp4',
      );

      final result = await engine.execute([job], '');
      await sub.cancel();
      engine.dispose();

      expect(result.success, isTrue);
      expect(
        events
            .where((e) => e.status == 'running')
            .single
            .operationType,
        equals('add_transition'),
      );
      expect(
        result.appliedOps.single.type,
        equals(EditOperationType.addTransition),
      );
    });
  });
}
