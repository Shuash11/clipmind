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

/// Catalogued ids only (mirrors `FontResolver.catalog`).
Future<String?> _fakeResolve(String familyId) async {
  const known = {
    'inter',
    'montserrat',
    'roboto',
    'lato',
    'source_code_pro',
    'eb_garamond',
  };
  if (!known.contains(familyId)) return null;
  return '/fonts/$familyId.ttf';
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
  late Directory tmp;
  late String inputA;
  late String outDir;
  late _FakeFfmpeg ffmpeg;
  late List<_Applied> applied;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipmind_overlay_font_');
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

  ToolExecutionContext ctx({
    Future<String?> Function(String familyId)? resolveFont,
  }) {
    final project = _project(inputA, outDir);
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
      resolveFont: resolveFont,
    );
  }

  group('overlay_text font (T9)', () {
    test('font present resolves to font_file in the op params', () async {
      final executor = EditToolExecutor(ctx(resolveFont: _fakeResolve));
      final result = await executor.execute(
        const ToolCall(
          id: 'call_font',
          name: 'overlay_text',
          args: {
            'clip_id': 'clip_1',
            'text': 'Hello',
            'font': 'inter',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(applied, hasLength(1));
      expect(applied.single.op.params['font'], equals('inter'));
      expect(
        applied.single.op.params['font_file'],
        equals('/fonts/inter.ttf'),
      );
      expect(
        ffmpeg.lastJob!.args.join(' '),
        contains('fontfile=/fonts/inter.ttf'),
      );
    });

    test('display label normalizes to the catalogued id', () async {
      final executor = EditToolExecutor(ctx(resolveFont: _fakeResolve));
      final result = await executor.execute(
        const ToolCall(
          id: 'call_label',
          name: 'overlay_text',
          args: {
            'clip_id': 'clip_1',
            'text': 'Hello',
            'font': 'Source Code Pro',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(applied.single.op.params['font'], equals('source_code_pro'));
      expect(
        applied.single.op.params['font_file'],
        equals('/fonts/source_code_pro.ttf'),
      );
    });

    test('unknown family fails actionably without running FFmpeg', () async {
      final executor = EditToolExecutor(ctx(resolveFont: _fakeResolve));
      final result = await executor.execute(
        const ToolCall(
          id: 'call_unknown',
          name: 'overlay_text',
          args: {
            'clip_id': 'clip_1',
            'text': 'Hello',
            'font': 'comic-sans',
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown font'));
      expect(result.error, contains('Inter'));
      expect(ffmpeg.lastJob, isNull);
      expect(applied, isEmpty);
    });

    test('no font keeps the system-default behavior unchanged', () async {
      final executor = EditToolExecutor(ctx(resolveFont: _fakeResolve));
      final result = await executor.execute(
        const ToolCall(
          id: 'call_plain',
          name: 'overlay_text',
          args: {
            'clip_id': 'clip_1',
            'text': 'Hello',
          },
        ),
      );

      expect(result.success, isTrue);
      expect(applied.single.op.params.containsKey('font'), isFalse);
      expect(applied.single.op.params.containsKey('font_file'), isFalse);
      expect(ffmpeg.lastJob!.args.join(' '), isNot(contains('fontfile')));
    });

    test('font without a wired resolver fails actionably', () async {
      final executor = EditToolExecutor(ctx());
      final result = await executor.execute(
        const ToolCall(
          id: 'call_nowire',
          name: 'overlay_text',
          args: {
            'clip_id': 'clip_1',
            'text': 'Hello',
            'font': 'inter',
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('font'));
      expect(ffmpeg.lastJob, isNull);
      expect(applied, isEmpty);
    });

    test('composed path carries fontfile through the filter graph', () {
      final jobs = CommandMapper.mapOperations(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_fx',
              type: 'apply_effect',
              targetClipId: 'clip_1',
              params: {'effect': 'contrast', 'contrast': 1.3},
            ),
            EditOperationRequest(
              id: 'op_txt',
              type: 'overlay_text',
              targetClipId: 'clip_1',
              params: {
                'text': 'hi',
                'font': 'roboto',
                'font_file': '/fonts/roboto.ttf',
              },
            ),
          ],
          summary: 'effect + text',
        ),
        {'clip_1': inputA},
        outDir,
        defaultPath: inputA,
      );

      expect(jobs, hasLength(1));
      final joined = jobs.single.args.join(' ');
      expect(joined, contains('fontfile=/fonts/roboto.ttf'));
      expect(joined, contains('eq=contrast=1.3'));
    });
  });
}
