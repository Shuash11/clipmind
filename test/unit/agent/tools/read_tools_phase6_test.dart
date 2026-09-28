import 'dart:io';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/ffmpeg/scene_detection_service.dart';
import 'package:clipmind/data/services/transcription/whisper_service.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFfprobe extends Mock implements FfprobeService {}

/// Deterministic binary for scene-detection tests: the fake `runProcess`
/// below never executes it, but the service resolves the binary first —
/// without this stub the tests would depend on FFmpeg being installed
/// (green locally, red in CI).
class _FakeResolver extends FfmpegBinaryResolver {
  @override
  String? resolveFfmpeg({String? settingsPath}) => '/fake/ffmpeg';
}

class _NoWhisper extends WhisperTranscriptionService {
  @override
  String? findBinary({String? configuredPath}) => null;
}

class _FakeFfmpeg extends FfmpegService {
  int wavExtracts = 0;

  _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path);

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    final out = File(job.outputPath);
    await out.parent.create(recursive: true);
    await out.writeAsString('fake-wav');
    if (job.outputPath.endsWith('.wav')) wavExtracts++;
    return FfmpegResult(success: true, outputPath: job.outputPath, exitCode: 0);
  }
}

const _sceneStderr =
    '[Parsed_showinfo_1 @ 0] n:   0 pts:  15360 pts_time:1       duration:    512 duration_time:0.0333333 \n'
    '[Parsed_showinfo_1 @ 0] n:   1 pts:  46080 pts_time:3       duration:    512 duration_time:0.0333333 \n';

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
  late Map<String, Map<String, dynamic>> store;
  late int sceneRuns;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipmind_read6_');
    inputA = '${tmp.path}/a.mp4';
    inputB = '${tmp.path}/b.mp4';
    outDir = '${tmp.path}/out';
    await File(inputA).writeAsString('a');
    await File(inputB).writeAsString('b');
    await Directory(outDir).create();
    ffmpeg = _FakeFfmpeg();
    store = {};
    sceneRuns = 0;
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  SceneDetectionService scenes() => SceneDetectionService(
    resolver: _FakeResolver(),
    runProcess: (_, _) async {
      sceneRuns++;
      return ProcessResult(0, 0, '', _sceneStderr);
    },
  );

  ToolExecutionContext ctx({
    Project? project,
    SceneDetectionService? sceneService,
    WhisperTranscriptionService? whisper,
    WhisperPaths? Function()? whisperConfig,
    bool dryRun = false,
    CancellationToken? cancellation,
  }) {
    return ToolExecutionContext(
      project: () => project ?? _project(inputA, inputB, outDir),
      outputDir: outDir,
      projectDir: tmp.path,
      applier: AgentEditApplier(onApply: (_, _) async {}),
      ffmpegService: ffmpeg,
      ffprobeService: _MockFfprobe(),
      sceneDetectionService: sceneService ?? scenes(),
      whisperService: whisper ?? _NoWhisper(),
      readAnalysis: (kind) => store[kind],
      writeAnalysis: (kind, payload) {
        store[kind] = payload;
      },
      whisperConfig: whisperConfig,
      dryRun: dryRun,
      cancellation: cancellation,
    );
  }

  Future<ToolResult> call(
    ToolExecutionContext c,
    String name, [
    Map<String, dynamic> args = const {},
  ]) {
    return ReadToolExecutor(c).execute(
      ToolCall(id: 'call_1', name: name, args: args),
    );
  }

  group('detect_scenes', () {
    test('computes, persists, then serves from cache', () async {
      final c = ctx();
      final first = await call(c, 'detect_scenes', {
        'clip_id': 'clip_1',
      });
      expect(first.success, isTrue);
      expect(first.data['scenes_ms'], equals([1000, 3000]));
      expect(first.data['count'], equals(2));
      expect(first.data['cached'], isFalse);
      expect(sceneRuns, equals(1));
      expect(store['scenes:clip_1']!['source_path'], equals(inputA));

      final second = await call(c, 'detect_scenes', {
        'clip_id': 'clip_1',
      });
      expect(second.success, isTrue);
      expect(second.data['scenes_ms'], equals([1000, 3000]));
      expect(second.data['cached'], isTrue);
      expect(sceneRuns, equals(1), reason: 'no recompute on cache hit');
    });

    test('changed source file invalidates the stamp', () async {
      final c = ctx();
      await call(c, 'detect_scenes', {'clip_id': 'clip_1'});
      expect(sceneRuns, equals(1));

      final inputA2 = '${tmp.path}/a2.mp4';
      await File(inputA2).writeAsString('a2');
      final moved = _project(inputA2, inputB, outDir);
      final again = await ReadToolExecutor(
        ctx(project: moved),
      ).execute(
        const ToolCall(
          id: 'call_2',
          name: 'detect_scenes',
          args: {'clip_id': 'clip_1'},
        ),
      );
      expect(again.success, isTrue);
      expect(again.data['cached'], isFalse);
      expect(sceneRuns, equals(2));
      expect(store['scenes:clip_1']!['source_path'], equals(inputA2));
    });

    test('unknown clip fails with actionable message', () async {
      final result = await call(ctx(), 'detect_scenes', {
        'clip_id': 'ghost',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown clip ID "ghost"'));
      expect(sceneRuns, equals(0));
    });

    test('ffmpeg failure degrades to an actionable error', () async {
      final failing = SceneDetectionService(
        resolver: _FakeResolver(),
        runProcess: (_, _) async => ProcessResult(0, 1, '', 'boom'),
      );
      final result = await call(
        ctx(sceneService: failing),
        'detect_scenes',
        {'clip_id': 'clip_1'},
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Scene detection failed'));
      expect(store.containsKey('scenes:clip_1'), isFalse);
    });

    test('read tools pass through in dry-run mode', () async {
      final result = await call(
        ctx(dryRun: true),
        'detect_scenes',
        {'clip_id': 'clip_1'},
      );
      expect(result.success, isTrue);
      expect(result.data['cached'], isFalse);
      expect(sceneRuns, equals(1));
    });
  });

  group('get_storyboard', () {
    test('without analysis returns clips + hint to detect scenes', () async {
      final result = await call(ctx(), 'get_storyboard', {'clip_id': null});
      expect(result.success, isTrue);
      expect(result.data['clip_count'], equals(2));
      expect(result.data['edit_history_count'], equals(0));
      expect(result.data['hint'], contains('detect_scenes'));
      final clips = result.data['clips'] as List;
      expect(clips.first['id'], equals('clip_1'));
      expect(clips.first['scenes_cached'], isFalse);
      expect(clips.first['start_ms'], equals(0));
      expect(clips.first['end_ms'], equals(60000));
    });

    test('with cached scenes returns detail and no hint', () async {
      final c = ctx();
      await call(c, 'detect_scenes', {'clip_id': 'clip_1'});
      final partial = await call(c, 'get_storyboard', {'clip_id': null});
      expect(partial.success, isTrue);
      expect(partial.data['hint'], contains('clip_2'),
          reason: 'hint names the clips still missing analysis');
      final clips = partial.data['clips'] as List;
      final first = clips.firstWhere((e) => e['id'] == 'clip_1');
      expect(first['scenes_ms'], equals([1000, 3000]));
      expect(first['scenes_cached'], isTrue);

      await call(c, 'detect_scenes', {'clip_id': 'clip_2'});
      final full = await call(c, 'get_storyboard', {'clip_id': null});
      expect(full.success, isTrue);
      expect(full.data.containsKey('hint'), isFalse);
    });

    test('single-clip filter and unknown clip', () async {
      final c = ctx();
      final one = await call(c, 'get_storyboard', {'clip_id': 'clip_2'});
      expect(one.success, isTrue);
      expect(one.data['clip_count'], equals(1));
      final bad = await call(c, 'get_storyboard', {'clip_id': 'ghost'});
      expect(bad.success, isFalse);
      expect(bad.error, contains('Unknown clip ID "ghost"'));
    });
  });

  group('get_transcript', () {
    test('degrades gracefully when whisper is absent', () async {
      final result = await call(ctx(), 'get_transcript', {
        'clip_id': 'clip_1',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('whisper.cpp not found'));
      expect(result.error, contains('Settings'));
      expect(ffmpeg.wavExtracts, equals(0),
          reason: 'no audio extraction without a binary');
      expect(store.containsKey('transcript:clip_1'), isFalse);
    });

    test('missing model file fails with setup hint', () async {
      final fakeBinary = '${tmp.path}/whisper-cli';
      await File(fakeBinary).writeAsString('fake');
      final result = await call(
        ctx(
          whisper: WhisperTranscriptionService(
            runProcess: (_, _) async => ProcessResult(0, 0, 'hi', ''),
          ),
          whisperConfig: () => WhisperPaths(
            binaryPath: fakeBinary,
            modelPath: '${tmp.path}/missing.bin',
          ),
        ),
        'get_transcript',
        {'clip_id': 'clip_1'},
      );
      expect(result.success, isFalse);
      expect(result.error, contains('model'));
    });

    test('with binary+model returns, persists, truncates, caches',
        () async {
      final fakeBinary = '${tmp.path}/whisper-cli';
      final model = '${tmp.path}/model.bin';
      await File(fakeBinary).writeAsString('fake');
      await File(model).writeAsString('fake-model');
      var transcribes = 0;
      String seenAudio = '';
      final whisper = WhisperTranscriptionService(
        runProcess: (exe, args) async {
          transcribes++;
          expect(exe, equals(fakeBinary));
          expect(args, contains('-m'));
          expect(args, contains(model));
          seenAudio = args.last;
          expect(seenAudio.endsWith('.wav'), isTrue);
          // Long output to exercise max_chars truncation.
          final lines = List.generate(
            20,
            (i) =>
                '[00:00:${i.toString().padLeft(2, '0')}.000 --> 00:00:99.000]  word$i padding padding padding',
          );
          return ProcessResult(0, 0, '${lines.join('\n')}\n', '');
        },
      );
      final c = ctx(
        whisper: whisper,
        whisperConfig: () =>
            WhisperPaths(binaryPath: fakeBinary, modelPath: model),
      );

      final first = await call(c, 'get_transcript', {
        'clip_id': 'clip_1',
        'max_chars': 100,
      });
      expect(first.success, isTrue);
      expect(transcribes, equals(1));
      expect(ffmpeg.wavExtracts, equals(1));
      // Temp wav is cleaned up after the run.
      expect(File(seenAudio).existsSync(), isFalse);
      expect(first.data['truncated'], isTrue);
      expect((first.data['text'] as String).length, equals(100));
      expect(first.data['cached'], isFalse);
      expect(store['transcript:clip_1']!['source_path'], equals(inputA));
      expect(
        (store['transcript:clip_1']!['text'] as String).length,
        greaterThan(100),
        reason: 'full text persisted, truncation is presentation-only',
      );

      final second = await call(c, 'get_transcript', {
        'clip_id': 'clip_1',
        'max_chars': 100,
      });
      expect(second.success, isTrue);
      expect(second.data['cached'], isTrue);
      expect(second.data['text'], equals(first.data['text']));
      expect(transcribes, equals(1), reason: 'no recompute on cache hit');
    });

    test('unknown clip fails without touching whisper', () async {
      final result = await call(ctx(), 'get_transcript', {
        'clip_id': 'ghost',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown clip ID "ghost"'));
    });
  });

  group('whisper helpers', () {
    test('parseTranscriptText strips timestamp prefixes', () {
      expect(
        WhisperTranscriptionService.parseTranscriptText(
          '[00:00:00.000 --> 00:00:02.000]  hello world\n'
          '[00:00:02.000 --> 00:00:04.000]  second line\n',
        ),
        equals('hello world\nsecond line'),
      );
      expect(
        WhisperTranscriptionService.parseTranscriptText('plain text\n'),
        equals('plain text'),
      );
    });

    test('isSafeConfiguredPath rejects traversal and relatives', () {
      expect(
        WhisperTranscriptionService.isSafeConfiguredPath('whisper-cli'),
        isFalse,
      );
      expect(
        WhisperTranscriptionService.isSafeConfiguredPath(r'C:\a\..\b\w.exe'),
        isFalse,
      );
      expect(
        WhisperTranscriptionService.isSafeConfiguredPath(''),
        isFalse,
      );
    });
  });
}
