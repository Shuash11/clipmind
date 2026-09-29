import 'dart:io';

import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/filter_graph_composer.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
import 'package:clipmind/domain/agent/stage_6_execution.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFfmpeg extends FfmpegService {
  _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path);

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
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

EditOperation _op(
  String id,
  EditOperationType type,
  Map<String, dynamic> params,
) {
  return EditOperation(
    id: id,
    type: type,
    targetClipIds: const ['clip_1'],
    params: params,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('FilterGraphComposer addSound', () {
    test('routes addSound to a standalone amix job', () {
      final jobs = FilterGraphComposer().compose(
        [
          _op('op_s', EditOperationType.addSound, {
            'sound_path': '/s/beep.wav',
            'volume': 1.0,
            'has_clip_audio': true,
          }),
        ],
        '/v/clip.mp4',
        '/v/out.mp4',
      );
      expect(jobs, hasLength(1));
      expect(jobs.single.args.join(' '), contains('amix=inputs=2'));
      expect(jobs.single.label, equals('addSound'));
    });

    test('one-sided replay maps the sound track without amix', () {
      final jobs = FilterGraphComposer().compose(
        [
          _op('op_s', EditOperationType.addSound, {
            'sound_path': '/s/beep.wav',
            'has_clip_audio': false,
          }),
        ],
        '/v/clip.mp4',
        '/v/out.mp4',
      );
      expect(jobs, hasLength(1));
      expect(jobs.single.args.join(' '), isNot(contains('amix')));
      expect(jobs.single.args, containsAll(['-map', '0:v', '-map', '1:a']));
    });

    test('overlayText replay carries the app-resolved fontfile', () {
      final jobs = FilterGraphComposer().compose(
        [
          _op('op_t', EditOperationType.overlayText, {
            'text': 'hi',
            'font_file': '/fonts/inter_regular.ttf',
          }),
        ],
        '/v/clip.mp4',
        '/v/out.mp4',
      );
      expect(jobs, hasLength(1));
      expect(
        jobs.single.args.join(' '),
        contains('fontfile=/fonts/inter_regular.ttf'),
      );
    });
  });

  group('CommandMapper add_sound', () {
    EditOperationSet set(
      String id,
      String type,
      Map<String, dynamic> params,
    ) {
      return EditOperationSet(
        operations: [
          EditOperationRequest(
            id: id,
            type: type,
            targetClipId: 'clip_1',
            params: params,
          ),
        ],
        summary: 'sound',
      );
    }

    test('maps add_sound to the addAudio builder', () {
      final jobs = CommandMapper.mapOperations(
        set('op_s', 'add_sound', {
          'sound_path': '/s/beep.wav',
          'volume': 0.8,
          'has_clip_audio': true,
        }),
        {'clip_1': '/v/clip.mp4'},
        Directory.systemTemp.path,
        defaultPath: '/v/clip.mp4',
      );
      expect(jobs, hasLength(1));
      final joined = jobs.single.args.join(' ');
      expect(joined, contains('[1:a]volume=0.8[snd]'));
      expect(joined, contains('amix=inputs=2'));
    });

    test('rejects traversal in the app-resolved sound_path', () {
      expect(
        () => CommandMapper.mapOperations(
          set('op_s', 'add_sound', {'sound_path': '../evil.wav'}),
          {'clip_1': '/v/clip.mp4'},
          Directory.systemTemp.path,
          defaultPath: '/v/clip.mp4',
        ),
        throwsA(isA<CommandMappingException>()),
      );
    });

    test('overlay_text carries fontfile through both paths', () {
      final single = CommandMapper.mapOperations(
        set('op_t', 'overlay_text', {
          'text': 'hi',
          'font_file': '/fonts/roboto_regular.ttf',
        }),
        {'clip_1': '/v/clip.mp4'},
        Directory.systemTemp.path,
        defaultPath: '/v/clip.mp4',
      );
      expect(
        single.single.args.join(' '),
        contains('fontfile=/fonts/roboto_regular.ttf'),
      );
      expect(
        () => CommandMapper.mapOperations(
          set('op_t', 'overlay_text', {
            'text': 'hi',
            'font_file': '../evil.ttf',
          }),
          {'clip_1': '/v/clip.mp4'},
          Directory.systemTemp.path,
          defaultPath: '/v/clip.mp4',
        ),
        throwsA(isA<CommandMappingException>()),
      );
    });
  });

  group('ExecutionEngine add_sound classification', () {
    late Directory tmp;
    late _FakeFfmpeg ffmpeg;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_addsound_');
      ffmpeg = _FakeFfmpeg();
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    Future<(List<ExecutionProgress>, ExecutionResult)> runJob(
      List<String> args,
    ) async {
      final engine = ExecutionEngine(ffmpeg);
      final events = <ExecutionProgress>[];
      final sub = engine.progress.listen(events.add);
      final result = await engine.execute(
        [
          FfmpegJob(
            id: 'job_1',
            args: args,
            expectedDurationMs: 0,
            inputPath: '/v/clip.mp4',
            outputPath: '${tmp.path}/out.mp4',
          ),
        ],
        '',
      );
      await sub.cancel();
      engine.dispose();
      return (events, result);
    }

    test('amix jobs classify as add_sound (even with a volume leg)', () async {
      final (events, result) = await runJob(
        CommandBuilder.addAudio('/v/clip.mp4', '/s/beep.wav', volume: 0.8),
      );
      expect(result.success, isTrue);
      expect(
        events.where((e) => e.status == 'running').single.operationType,
        equals('add_sound'),
      );
      expect(
        result.appliedOps.single.type,
        equals(EditOperationType.addSound),
      );
    });

    test('one-sided jobs classify as add_sound', () async {
      final (events, result) = await runJob(
        CommandBuilder.addAudio(
          '/v/clip.mp4',
          '/s/beep.wav',
          hasClipAudio: false,
        ),
      );
      expect(result.success, isTrue);
      expect(
        events.where((e) => e.status == 'running').single.operationType,
        equals('add_sound'),
      );
      expect(
        result.appliedOps.single.type,
        equals(EditOperationType.addSound),
      );
    });

    test('plain volume jobs still classify as change_volume', () async {
      final (events, result) = await runJob(
        CommandBuilder.changeVolume('/v/clip.mp4', 0.5),
      );
      expect(result.success, isTrue);
      expect(
        events.where((e) => e.status == 'running').single.operationType,
        equals('change_volume'),
      );
    });
  });
}
