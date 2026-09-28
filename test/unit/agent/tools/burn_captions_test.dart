import 'dart:io';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/ffmpeg/filter_escaping.dart';
import 'package:clipmind/data/services/ffmpeg/srt_builder.dart';
import 'package:clipmind/data/services/transcription/whisper_service.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFfprobe extends Mock implements FfprobeService {}

class _FakeFfmpeg extends FfmpegService {
  _FakeFfmpeg({this._failStderr}) : super(tempDir: Directory.systemTemp.path);

  final String? _failStderr;
  final List<FfmpegJob> jobs = [];

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    jobs.add(job);
    if (_failStderr != null) {
      return FfmpegResult(
        success: false,
        outputPath: job.outputPath,
        exitCode: 1,
        stderr: _failStderr,
      );
    }
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
  group('assColorFromHex', () {
    test('converts #RRGGBB to &H00BBGGRR (BGR order, opaque)', () {
      expect(FilterEscaping.assColorFromHex('#FF0000'), equals('&H000000FF'));
      expect(FilterEscaping.assColorFromHex('#00FF00'), equals('&H0000FF00'));
      expect(FilterEscaping.assColorFromHex('#0000FF'), equals('&H00FF0000'));
      expect(FilterEscaping.assColorFromHex('#FFFFFF'), equals('&H00FFFFFF'));
      expect(FilterEscaping.assColorFromHex('#ff0000'), equals('&H000000FF'));
    });

    test('rejects non-hex colors', () {
      expect(
        () => FilterEscaping.assColorFromHex('#XYZ'),
        throwsA(isA<FilterValidationException>()),
      );
      expect(
        () => FilterEscaping.assColorFromHex('red'),
        throwsA(isA<FilterValidationException>()),
      );
    });
  });

  group('escapeSubtitlePath', () {
    test('normalizes slashes and escapes colon and quote', () {
      expect(
        FilterEscaping.escapeSubtitlePath(r'C:\a\b\file.srt'),
        equals(r'C\:/a/b/file.srt'),
      );
      expect(
        FilterEscaping.escapeSubtitlePath("/tmp/a'b/c.srt"),
        equals(r"/tmp/a\'b/c.srt"),
      );
    });
  });

  group('SrtBuilder', () {
    test('formatTimestamp uses comma milliseconds', () {
      expect(SrtBuilder.formatTimestamp(0), equals('00:00:00,000'));
      expect(SrtBuilder.formatTimestamp(1000), equals('00:00:01,000'));
      expect(SrtBuilder.formatTimestamp(2500), equals('00:00:02,500'));
      expect(SrtBuilder.formatTimestamp(90000), equals('00:01:30,000'));
      expect(SrtBuilder.formatTimestamp(3723456), equals('01:02:03,456'));
    });

    test('buildSrt numbers entries, skips empty text, keeps order', () {
      const segments = [
        TranscriptSegment(startMs: 1000, endMs: 2500, text: 'Hello'),
        TranscriptSegment(startMs: 3000, endMs: 4000, text: '   '),
        TranscriptSegment(startMs: 5000, endMs: 6500, text: 'World'),
      ];
      expect(
        SrtBuilder.buildSrt(segments),
        equals(
          '1\n'
          '00:00:01,000 --> 00:00:02,500\n'
          'Hello\n'
          '\n'
          '2\n'
          '00:00:05,000 --> 00:00:06,500\n'
          'World\n'
          '\n',
        ),
      );
    });
  });

  group('CommandBuilder.burnCaptions', () {
    test('defaults omit force_style', () {
      final args = CommandBuilder.burnCaptions(
        r'C:\v\in.mp4',
        r'C:\t\cap.srt',
      );
      expect(args.sublist(0, 2), equals([r'-i', r'C:\v\in.mp4']));
      expect(args[2], equals('-vf'));
      expect(args[3], equals(r"subtitles=filename='C\:/t/cap.srt'"));
    });

    test('non-default style keys are included', () {
      final args = CommandBuilder.burnCaptions(
        '/v/in.mp4',
        '/t/cap.srt',
        fontSize: 32,
        assColor: '&H000000FF',
        alignment: 8,
      );
      expect(
        args[3],
        equals(
          "subtitles=filename='/t/cap.srt':"
          "force_style='FontSize=32,PrimaryColour=&H000000FF,Alignment=8'",
        ),
      );
    });

    test('center maps to Alignment=5', () {
      final args = CommandBuilder.burnCaptions(
        '/v/in.mp4',
        '/t/cap.srt',
        alignment: 5,
      );
      expect(args[3], contains('Alignment=5'));
      expect(args[3], isNot(contains('FontSize')));
    });
  });

  group('burn_captions executor', () {
    late Directory tmp;
    late String inputA;
    late String outDir;
    late Map<String, Map<String, dynamic>> store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_burn_');
      inputA = '${tmp.path}/a.mp4';
      outDir = '${tmp.path}/out';
      await File(inputA).writeAsString('a');
      await Directory(outDir).create();
      store = {};
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    ToolExecutionContext ctx({
      _FakeFfmpeg? ffmpeg,
      int? maxJobs,
      CancellationToken? cancellation,
    }) {
      return ToolExecutionContext(
        project: () => _project(inputA, outDir),
        outputDir: outDir,
        projectDir: tmp.path,
        applier: AgentEditApplier(
            onApply: (_, _, {removeClipIds = const []}) async {}),
        ffmpegService: ffmpeg ?? _FakeFfmpeg(),
        ffprobeService: _MockFfprobe(),
        readAnalysis: (kind) => store[kind],
        writeAnalysis: (kind, payload) {
          store[kind] = payload;
        },
        maxJobs: maxJobs ?? 20,
        cancellation: cancellation,
      );
    }

    void seedTranscript(List<Map<String, dynamic>> segments) {
      store['transcript:clip_1'] = {
        'clip_id': 'clip_1',
        'source_path': inputA,
        'text': 'hello world',
        'chars': 11,
        'segments': segments,
      };
    }

    Future<ToolResult> call(
      ToolExecutionContext c, [
      Map<String, dynamic> args = const {'clip_id': 'clip_1'},
    ]) {
      return EditToolExecutor(c).execute(
        ToolCall(id: 'call_1', name: 'burn_captions', args: args),
      );
    }

    String videoFilter(_FakeFfmpeg ffmpeg) {
      final job = ffmpeg.jobs.single;
      expect(job.args[0], equals('-i'));
      expect(job.args[1], equals(inputA));
      expect(job.args[2], equals('-vf'));
      return job.args[3];
    }

    String srtPathFrom(String vf) {
      final match = RegExp(r"filename='((?:[^'\\]|\\.)*)'").firstMatch(vf)!;
      return match
          .group(1)!
          .replaceAll(r'\:', ':')
          .replaceAll(r"\'", "'");
    }

    test('happy path burns cached segments and journals the edit',
        () async {
      seedTranscript([
        {'start_ms': 1000, 'end_ms': 2500, 'text': 'Hello'},
        {'start_ms': 5000, 'end_ms': 6500, 'text': 'World'},
      ]);
      final ffmpeg = _FakeFfmpeg();
      final c = ctx(ffmpeg: ffmpeg);

      final result = await call(c);

      expect(result.success, isTrue);
      expect(result.data['segments_burned'], equals(2));
      expect(result.data['operation_id'], equals('call_1'));
      expect(result.data['output_path'], isNotEmpty);
      expect(
        result.summary,
        equals('Burned 2 caption(s) into clip "clip_1".'),
      );
      final vf = videoFilter(ffmpeg);
      expect(vf, startsWith('subtitles=filename='));
      expect(vf, isNot(contains('force_style')));
      // Escaped form of the real temp path; the temp SRT is cleaned up.
      final srtPath = srtPathFrom(vf);
      expect(srtPath.endsWith('.srt'), isTrue);
      if (srtPath.contains(':')) expect(vf, contains(r'\:'));
      expect(File(srtPath).existsSync(), isFalse);
      // Applier applied (timeline/undo/DB) with the new op type.
      expect(c.appliedOperations, hasLength(1));
      expect(
        c.appliedOperations.single.type,
        equals(EditOperationType.burnCaptions),
      );
      expect(c.outputPaths, hasLength(1));
    });

    test('style args reach the filter; unknown position falls back',
        () async {
      seedTranscript([
        {'start_ms': 0, 'end_ms': 1000, 'text': 'Hi'},
      ]);
      final ffmpeg = _FakeFfmpeg();
      final result = await call(
        ctx(ffmpeg: ffmpeg),
        {
          'clip_id': 'clip_1',
          'font_size': 32,
          'font_color': '#FF0000',
          'position': 'top',
        },
      );

      expect(result.success, isTrue);
      expect(videoFilter(ffmpeg), contains('FontSize=32'));
      expect(videoFilter(ffmpeg), contains('PrimaryColour=&H000000FF'));
      expect(videoFilter(ffmpeg), contains('Alignment=8'));
    });

    test('unknown position defaults to bottom without error', () async {
      seedTranscript([
        {'start_ms': 0, 'end_ms': 1000, 'text': 'Hi'},
      ]);
      final ffmpeg = _FakeFfmpeg();
      final result = await call(
        ctx(ffmpeg: ffmpeg),
        {'clip_id': 'clip_1', 'position': 'sideways'},
      );

      expect(result.success, isTrue);
      expect(videoFilter(ffmpeg), isNot(contains('Alignment')));
    });

    test('bad font_color fails actionably without running FFmpeg',
        () async {
      seedTranscript([
        {'start_ms': 0, 'end_ms': 1000, 'text': 'Hi'},
      ]);
      final ffmpeg = _FakeFfmpeg();
      final result = await call(
        ctx(ffmpeg: ffmpeg),
        {'clip_id': 'clip_1', 'font_color': '#XYZ'},
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Invalid color'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('missing transcript hints get_transcript first', () async {
      final result = await call(ctx());
      expect(result.success, isFalse);
      expect(result.error, contains('No transcript cached'));
      expect(result.error, contains('call get_transcript first'));
    });

    test('stale stamp is treated as missing', () async {
      store['transcript:clip_1'] = {
        'source_path': '/elsewhere/b.mp4',
        'text': 'hi',
        'segments': [
          {'start_ms': 0, 'end_ms': 1, 'text': 'hi'},
        ],
      };
      final result = await call(ctx());
      expect(result.success, isFalse);
      expect(result.error, contains('No transcript cached'));
    });

    test('empty segments fail with re-run hint', () async {
      seedTranscript([]);
      final result = await call(ctx());
      expect(result.success, isFalse);
      expect(result.error, contains('no timed segments'));
    });

    test('unknown clip fails without touching FFmpeg', () async {
      final ffmpeg = _FakeFfmpeg();
      final result = await call(
        ctx(ffmpeg: ffmpeg),
        {'clip_id': 'ghost'},
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown clip ID "ghost"'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('filter failure surfaces stderr with the libass hint', () async {
      seedTranscript([
        {'start_ms': 0, 'end_ms': 1000, 'text': 'Hi'},
      ]);
      const stderr = 'No such filter: subtitles; libass not enabled';
      final result = await call(
        ctx(ffmpeg: _FakeFfmpeg(failStderr: stderr)),
      );
      expect(result.success, isFalse);
      expect(result.error, contains(stderr));
      expect(result.error, contains('libass'));
    });

    test('budget exceeded fails before writing work', () async {
      seedTranscript([
        {'start_ms': 0, 'end_ms': 1000, 'text': 'Hi'},
      ]);
      final ffmpeg = _FakeFfmpeg();
      final result = await call(ctx(ffmpeg: ffmpeg, maxJobs: 0));
      expect(result.success, isFalse);
      expect(result.error, contains('budget'));
      expect(ffmpeg.jobs, isEmpty);
    });
  });

  group('burn_captions mapping guard', () {
    test('traversal srt_path is rejected (defense-in-depth)', () {
      expect(
        () => CommandMapper.mapOperations(
          const EditOperationSet(
            operations: [
              EditOperationRequest(
                id: 'op_1',
                type: 'burn_captions',
                targetClipId: 'clip_1',
                params: {
                  'srt_path': '../evil/cap.srt',
                  'font_size': 24,
                },
              ),
            ],
            summary: 'x',
          ),
          {'clip_1': '/v/a.mp4'},
          '/out',
        ),
        throwsA(
          isA<CommandMappingException>().having(
            (e) => e.message,
            'message',
            contains('traversal'),
          ),
        ),
      );
    });

    test('clean srt_path maps to a subtitles job', () {
      final jobs = CommandMapper.mapOperations(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_1',
              type: 'burn_captions',
              targetClipId: 'clip_1',
              params: {
                'srt_path': '/t/cap.srt',
                'font_size': 24,
              },
            ),
          ],
          summary: 'x',
        ),
        {'clip_1': '/v/a.mp4'},
        '/out',
      );
      expect(jobs, hasLength(1));
      expect(jobs.single.args.join(' '), contains('subtitles='));
    });
  });
}
