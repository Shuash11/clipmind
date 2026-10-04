import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';

class _FakeResolver extends FfmpegBinaryResolver {
  @override
  String? resolveFfmpeg({String? settingsPath}) => '/fake/ffmpeg';

  @override
  String? resolveFfprobe({String? settingsPath}) => '/fake/ffprobe';
}

Future<ProcessResult?> _neverCompletes(
  String binary,
  List<String> args,
) =>
    Completer<ProcessResult?>().future;

Future<ProcessResult> _neverCompletesJob(
  String binary,
  List<String> args,
) =>
    Completer<ProcessResult>().future;

// Cycle 13 Phase 3a (permanent-hang wedge): a hung probe/job must resolve
// to a typed failure within the timeout (the child is KILLED on the real
// path), and an invalid output path must yield a failed result — never an
// unhandled zone error. Seam-injected hangs keep these arg-level: no
// FFmpeg binary is spawned.
void main() {
  group('FfprobeService timeout', () {
    test('a hung probe resolves to null within the timeout', () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_probe_timeout_');
      try {
        final input = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
        final service = FfprobeService(
          resolver: _FakeResolver(),
          runProbe: _neverCompletes,
          probeTimeout: const Duration(milliseconds: 50),
        );
        final sw = Stopwatch()..start();
        final meta = await service.extractMetadata(input);
        sw.stop();
        expect(meta, isNull);
        expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('a hung thumbnail probe resolves to null within the timeout',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_thumb_timeout_');
      try {
        final input = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
        final service = FfprobeService(
          resolver: _FakeResolver(),
          runProbe: _neverCompletes,
          probeTimeout: const Duration(milliseconds: 50),
        );
        final sw = Stopwatch()..start();
        final out = await service.generateThumbnail(input);
        sw.stop();
        expect(out, isNull);
        expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });

  group('FfmpegService.runSync timeout + output guard', () {
    test('a hung job resolves to a failed result with the timeout message',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_job_timeout_');
      try {
        final input = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
        final service = FfmpegService(
          resolver: _FakeResolver(),
          tempDir: tmp.path,
          jobTimeout: const Duration(milliseconds: 50),
          runJob: _neverCompletesJob,
        );
        final sw = Stopwatch()..start();
        final result = await service.runSync(
          FfmpegJob(
            id: 'op_1',
            args: const ['-i', 'in.mp4'],
            expectedDurationMs: 0,
            inputPath: input,
            outputPath: '${tmp.path}/out.mp4',
          ),
        );
        sw.stop();
        expect(result.success, isFalse);
        expect(result.exitCode, equals(-1));
        expect(result.error, contains('timed out'));
        expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('an invalid output path yields a failed result, not a throw',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_job_badout_');
      try {
        final input = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
        // Block the output directory: a FILE sits where the parent dir
        // must be created, so `createSync` throws inside the service.
        final blocker =
            (File('${tmp.path}/blocker')..writeAsStringSync('x')).path;
        var ran = false;
        final service = FfmpegService(
          resolver: _FakeResolver(),
          tempDir: tmp.path,
          runJob: (binary, args) async {
            ran = true;
            return ProcessResult(0, 0, '', '');
          },
        );
        final result = await service.runSync(
          FfmpegJob(
            id: 'op_1',
            args: const ['-i', 'in.mp4'],
            expectedDurationMs: 0,
            inputPath: input,
            outputPath: '$blocker/out.mp4',
          ),
        );
        expect(result.success, isFalse);
        expect(result.exitCode, equals(-1));
        expect(ran, isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });
}
