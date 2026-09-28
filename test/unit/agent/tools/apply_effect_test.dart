import 'dart:io';
import 'dart:math' as math;

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

Project _project(String inputA, String outDir) {
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
        ],
      ),
    ],
    durationMs: 60000,
    outputDir: outDir,
  );
}

void main() {
  group('CommandBuilder.effectFilter', () {
    test('vignette maps strength to radians (0.4 ≡ PI/5)', () {
      final filter =
          CommandBuilder.effectFilter(effect: 'vignette', strength: 0.4);
      final angle = double.parse(filter.split('=').last);
      expect(angle, closeTo(math.pi / 5, 1e-9));
    });

    test('vignette clamps strength to 0–1', () {
      expect(
        CommandBuilder.effectFilter(effect: 'vignette', strength: 9),
        equals('vignette=angle=${math.pi / 2}'),
      );
    });

    test('blur maps strength to gblur sigma', () {
      final filter =
          CommandBuilder.effectFilter(effect: 'blur', strength: 0.3);
      expect(double.parse(filter.split('=').last), closeTo(6.0, 1e-9));
    });

    test('grayscale is eq saturation zero (no standalone filter)', () {
      expect(
        CommandBuilder.effectFilter(effect: 'grayscale'),
        equals('eq=saturation=0'),
      );
    });

    test('contrast and saturation clamp to 0–3', () {
      expect(
        CommandBuilder.effectFilter(effect: 'contrast', contrast: 1.2),
        equals('eq=contrast=1.2'),
      );
      expect(
        CommandBuilder.effectFilter(effect: 'contrast', contrast: -2),
        equals('eq=contrast=0.0'),
      );
      expect(
        CommandBuilder.effectFilter(effect: 'saturation', saturation: 2.5),
        equals('eq=saturation=2.5'),
      );
      expect(
        CommandBuilder.effectFilter(effect: 'saturation', saturation: 99),
        equals('eq=saturation=3.0'),
      );
    });

    test('unknown effects yield the null passthrough', () {
      expect(
        CommandBuilder.effectFilter(effect: 'nope'),
        equals('null'),
      );
    });
  });

  group('apply_effect executor', () {
    late Directory tmp;
    late String inputA;
    late String outDir;
    late _FakeFfmpeg ffmpeg;
    late List<EditOperation> applied;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_effect_');
      inputA = '${tmp.path}/a.mp4';
      outDir = '${tmp.path}/out';
      await File(inputA).writeAsString('a');
      await Directory(outDir).create();
      ffmpeg = _FakeFfmpeg();
      applied = [];
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    ToolExecutionContext ctx({bool dryRun = false, int? maxJobs}) {
      return ToolExecutionContext(
        project: () => _project(inputA, outDir),
        outputDir: outDir,
        projectDir: tmp.path,
        applier: AgentEditApplier(
          onApply: (op, path, {removeClipIds = const []}) async {
            applied.add(op);
          },
        ),
        ffmpegService: ffmpeg,
        ffprobeService: _MockFfprobe(),
        dryRun: dryRun,
        maxJobs: maxJobs ?? 20,
      );
    }

    Future<ToolResult> call(
      ToolExecutionContext c, [
      Map<String, dynamic> args = const {'clip_id': 'clip_1'},
    ]) {
      return EditToolExecutor(c).execute(
        ToolCall(id: 'call_1', name: 'apply_effect', args: args),
      );
    }

    String videoFilter() {
      final job = ffmpeg.jobs.single;
      expect(job.args[0], equals('-i'));
      expect(job.args[1], equals(inputA));
      expect(job.args[2], equals('-vf'));
      return job.args[3];
    }

    test('vignette burns with default strength when omitted', () async {
      final result = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'vignette',
      });

      expect(result.success, isTrue);
      expect(result.summary, contains('vignette'));
      expect(videoFilter(), startsWith('vignette=angle='));
      expect(applied.single.type.name, equals('applyEffect'));
    });

    test('strength above 1 clamps; zero or negative fails', () async {
      final clamped = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'blur',
        'strength': 5,
      });
      expect(clamped.success, isTrue);
      final sigma =
          double.parse(videoFilter().split('=').last);
      expect(sigma, closeTo(20.0, 1e-9));

      final zero = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'blur',
        'strength': 0,
      });
      expect(zero.success, isFalse);
      expect(zero.error, contains('strength'));
      expect(ffmpeg.jobs, hasLength(1));
    });

    test('blur maps to gblur sigma', () async {
      final result = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'blur',
        'strength': 0.5,
      });

      expect(result.success, isTrue);
      expect(videoFilter(), equals('gblur=sigma=10.0'));
    });

    test('grayscale needs no params', () async {
      final result = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'grayscale',
      });

      expect(result.success, isTrue);
      expect(videoFilter(), equals('eq=saturation=0'));
    });

    test('contrast requires the multiplier and clamps negatives',
        () async {
      final ok = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'contrast',
        'contrast': 1.2,
      });
      expect(ok.success, isTrue);
      expect(videoFilter(), equals('eq=contrast=1.2'));

      final missing = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'contrast',
      });
      expect(missing.success, isFalse);
      expect(missing.error, contains('"contrast"'));

      final negative = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'contrast',
        'contrast': -2,
      });
      expect(negative.success, isTrue);
      expect(ffmpeg.jobs.last.args.join(' '), contains('eq=contrast=0.0'));
    });

    test('saturation mirrors the contrast contract', () async {
      final ok = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'saturation',
        'saturation': 2.5,
      });
      expect(ok.success, isTrue);
      expect(videoFilter(), equals('eq=saturation=2.5'));

      final missing = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'saturation',
      });
      expect(missing.success, isFalse);
      expect(missing.error, contains('"saturation"'));
    });

    test('unknown effect and clip fail actionably', () async {
      final badEffect = await call(ctx(), {
        'clip_id': 'clip_1',
        'effect': 'lensflare',
      });
      expect(badEffect.success, isFalse);
      expect(badEffect.error, contains('Unknown effect'));
      expect(badEffect.error, contains('adjust_brightness'));

      final badClip = await call(ctx(), {
        'clip_id': 'ghost',
        'effect': 'blur',
      });
      expect(badClip.success, isFalse);
      expect(badClip.error, contains('Unknown clip ID "ghost"'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('dry-run plans without executing', () async {
      final result = await call(
        ctx(dryRun: true),
        {'clip_id': 'clip_1', 'effect': 'grayscale'},
      );

      expect(result.success, isTrue);
      expect(result.data['planned'], isTrue);
      expect(result.data['op_type'], equals('apply_effect'));
      expect(ffmpeg.jobs, isEmpty);
      expect(applied, isEmpty);
    });

    test('one job of budget is consumed', () async {
      final over = await call(
        ctx(maxJobs: 0),
        {'clip_id': 'clip_1', 'effect': 'grayscale'},
      );
      expect(over.success, isFalse);
      expect(over.error, contains('budget'));

      final exact = await call(
        ctx(maxJobs: 1),
        {'clip_id': 'clip_1', 'effect': 'grayscale'},
      );
      expect(exact.success, isTrue);
    });

    test('composes with adjust_brightness in one job', () async {
      final jobs = CommandMapper.mapOperations(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_1',
              type: 'apply_effect',
              targetClipId: 'clip_1',
              params: {'effect': 'contrast', 'contrast': 1.2},
            ),
            EditOperationRequest(
              id: 'op_2',
              type: 'adjust_brightness',
              targetClipId: 'clip_1',
              params: {'value': 0.5},
            ),
          ],
          summary: 'x',
        ),
        {'clip_1': inputA},
        outDir,
      );

      expect(jobs, hasLength(1));
      final args = jobs.single.args.join(' ');
      expect(args, contains('eq=contrast=1.2'));
      expect(args, contains('eq=brightness=0.5'));
    });
  });
}
