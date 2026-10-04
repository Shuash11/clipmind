import 'dart:async';
import 'dart:convert';
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

  group('FfmpegService.run stall watchdog', () {
    test('hung ffmpeg with no progress is killed with typed stall failure',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_run_stall_');
      try {
        final input = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
        final fake = _FakeStreamingProcess(
          stdoutStream: _neverListStream(),
          stderrStream: Stream<List<int>>.value(const <int>[]),
          exitCodeFuture: Completer<int>().future,
        );
        final service = FfmpegService(
          resolver: _FakeResolver(),
          tempDir: tmp.path,
          stallTimeout: const Duration(milliseconds: 50),
          startProcess: (binary, args) async => fake,
        );
        final job = FfmpegJob(
          id: 'op_stall',
          args: const ['-i', 'in.mp4'],
          expectedDurationMs: 30000,
          inputPath: input,
          outputPath: '${tmp.path}/out.mp4',
        );
        final sw = Stopwatch()..start();
        await expectLater(
          service.run(job).toList(),
          throwsA(
            isA<FfmpegStallException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('stalled'),
                contains('no progress'),
              ),
            ),
          ),
        );
        sw.stop();
        expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
        expect(fake.killed, isTrue);
        expect(service.hasActiveProcess, isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('healthy ffmpeg with continuous progress is never falsely killed',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_run_healthy_');
      try {
        final input = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
        final lines = utf8.encode(
          'out_time_ms=15000\nspeed=2.0x\nout_time_ms=20000\nprogress=end\n',
        );
        final fake = _FakeStreamingProcess(
          stdoutStream: Stream<List<int>>.value(lines),
          stderrStream: Stream<List<int>>.value(const <int>[]),
          exitCodeFuture: Future.value(0),
        );
        final service = FfmpegService(
          resolver: _FakeResolver(),
          tempDir: tmp.path,
          stallTimeout: const Duration(milliseconds: 500),
          startProcess: (binary, args) async => fake,
        );
        final job = FfmpegJob(
          id: 'op_healthy',
          args: const ['-i', 'in.mp4'],
          expectedDurationMs: 30000,
          inputPath: input,
          outputPath: '${tmp.path}/out.mp4',
        );
        final events = await service.run(job).toList();
        expect(events, isNotEmpty);
        expect(events.last.status, equals('complete'));
        expect(events.last.percent, equals(1.0));
        expect(fake.killed, isFalse);
        expect(service.hasActiveProcess, isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('generator cancellation always clears the active process handle',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_run_cancel_');
      StreamController<List<int>>? controller;
      try {
        final input = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
        // Emit one progress line then hang: mirrors the use-case `break`
        // which stops listening after receiving progress events.
        controller = StreamController<List<int>>();
        controller.add(utf8.encode('out_time_ms=15000\n'));
        final fake = _FakeStreamingProcess(
          stdoutStream: controller.stream,
          stderrStream: Stream<List<int>>.value(const <int>[]),
          exitCodeFuture: Completer<int>().future,
        );
        final service = FfmpegService(
          resolver: _FakeResolver(),
          tempDir: tmp.path,
          // Long watchdog so only the cancellation clears the handle.
          stallTimeout: const Duration(seconds: 5),
          startProcess: (binary, args) async => fake,
        );
        final job = FfmpegJob(
          id: 'op_cancel',
          args: const ['-i', 'in.mp4'],
          expectedDurationMs: 30000,
          inputPath: input,
          outputPath: '${tmp.path}/out.mp4',
        );
        // `first` consumes one progress event then cancels the generator
        // subscription — the try/finally in run() must clear the handle.
        final first = await service.run(job).first;
        expect(first.percent, greaterThan(0));
        // Give the generator a tick to run its finally block.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasActiveProcess, isFalse);
        expect(fake.killed, isFalse);
      } finally {
        await controller?.close();
        await tmp.delete(recursive: true);
      }
    });
  });

  group('FfmpegService.run lifecycle hardening', () {
    test('cancel during startup kills the late child and ends without events',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_run_startcancel_');
      try {
        final input = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
        final hungFake = _FakeStreamingProcess(
          stdoutStream: _neverListStream(),
          stderrStream: Stream<List<int>>.value(const <int>[]),
          exitCodeFuture: Completer<int>().future,
        );
        final healthyLines = utf8.encode(
          'out_time_ms=15000\nprogress=end\n',
        );
        final healthyFake = _FakeStreamingProcess(
          stdoutStream: Stream<List<int>>.value(healthyLines),
          stderrStream: Stream<List<int>>.value(const <int>[]),
          exitCodeFuture: Future.value(0),
        );
        // First starter call suspends in the startup window; later calls
        // serve a healthy child so the follow-up run proves busy cleared.
        final starterGate = Completer<Process>();
        var calls = 0;
        final service = FfmpegService(
          resolver: _FakeResolver(),
          tempDir: tmp.path,
          stallTimeout: const Duration(seconds: 5),
          startProcess: (binary, args) {
            calls++;
            if (calls == 1) return starterGate.future;
            return Future<Process>.value(healthyFake);
          },
        );
        FfmpegJob jobFor(String id, String out) => FfmpegJob(
              id: id,
              args: const ['-i', 'in.mp4'],
              expectedDurationMs: 30000,
              inputPath: input,
              outputPath: out,
            );
        final eventsFuture =
            service.run(jobFor('op_startcancel', '${tmp.path}/out.mp4')).toList();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // Still starting up: no child handle yet.
        expect(service.hasActiveProcess, isFalse);
        service.cancel();
        starterGate.complete(hungFake);
        final events = await eventsFuture;
        expect(events, isEmpty);
        expect(hungFake.killed, isTrue);
        expect(service.hasActiveProcess, isFalse);
        // Busy cleared: a follow-up run on the same service proceeds.
        final followUp = await service
            .run(jobFor('op_next', '${tmp.path}/out2.mp4'))
            .toList();
        expect(followUp.last.status, equals('complete'));
        expect(calls, equals(2));
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('a second concurrent run is rejected with a typed busy failure',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_run_busy_');
      try {
        final input = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
        final healthyLines = utf8.encode(
          'out_time_ms=15000\nprogress=end\n',
        );
        final healthyFake = _FakeStreamingProcess(
          stdoutStream: Stream<List<int>>.value(healthyLines),
          stderrStream: Stream<List<int>>.value(const <int>[]),
          exitCodeFuture: Future.value(0),
        );
        // Hold the first run in the startup window so the test is
        // deterministic (no watchdog waits, no subscription cancels).
        final starterGate = Completer<Process>();
        var calls = 0;
        final service = FfmpegService(
          resolver: _FakeResolver(),
          tempDir: tmp.path,
          stallTimeout: const Duration(seconds: 5),
          startProcess: (binary, args) {
            calls++;
            return starterGate.future;
          },
        );
        FfmpegJob jobFor(String id, String out) => FfmpegJob(
              id: id,
              args: const ['-i', 'in.mp4'],
              expectedDurationMs: 30000,
              inputPath: input,
              outputPath: out,
            );
        final firstFuture = service
            .run(jobFor('op_first', '${tmp.path}/out.mp4'))
            .toList();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await expectLater(
          service.run(jobFor('op_second', '${tmp.path}/out2.mp4')).toList(),
          throwsA(
            isA<FfmpegBusyException>().having(
              (e) => e.message,
              'message',
              contains('busy'),
            ),
          ),
        );
        // The rejected run never reached the starter.
        expect(calls, equals(1));
        starterGate.complete(healthyFake);
        final events = await firstFuture;
        expect(events.last.status, equals('complete'));
        expect(service.hasActiveProcess, isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('non-zero exit surfaces a typed failure with partial-output context',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_run_exitcode_');
      try {
        final input = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
        final outputPath = '${tmp.path}/out.mp4';
        // Progress looked complete, but the child failed: must not read as
        // success via a file-exists check.
        final lines = utf8.encode(
          'out_time_ms=15000\nprogress=end\n',
        );
        final fake = _FakeStreamingProcess(
          stdoutStream: Stream<List<int>>.value(lines),
          stderrStream: Stream<List<int>>.value(const <int>[]),
          exitCodeFuture: Future.value(1),
        );
        final service = FfmpegService(
          resolver: _FakeResolver(),
          tempDir: tmp.path,
          stallTimeout: const Duration(seconds: 5),
          startProcess: (binary, args) async => fake,
        );
        final job = FfmpegJob(
          id: 'op_exitcode',
          args: const ['-i', 'in.mp4'],
          expectedDurationMs: 30000,
          inputPath: input,
          outputPath: outputPath,
        );
        await expectLater(
          service.run(job).toList(),
          throwsA(
            isA<FfmpegExitCodeException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('exit code 1'),
                contains('incomplete'),
              ),
            ),
          ),
        );
        // Already-exited child: nothing to kill; no stale handle.
        expect(fake.killed, isFalse);
        expect(service.hasActiveProcess, isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });
}

/// Never-emitting, never-closing byte stream: simulates a hung ffmpeg
/// whose stdout progress pipe goes silent.
Stream<List<int>> _neverListStream() => StreamController<List<int>>().stream;

/// Minimal fake for the streaming `Process.start` seam: exposes
/// never-ending or scripted stdout/stderr streams, records [kill], and
/// never spawns a real FFmpeg binary.
class _FakeStreamingProcess implements Process {
  _FakeStreamingProcess({
    required this.stdoutStream,
    required this.stderrStream,
    required this.exitCodeFuture,
  });

  final Stream<List<int>> stdoutStream;
  final Stream<List<int>> stderrStream;
  final Future<int> exitCodeFuture;

  bool killed = false;

  @override
  Stream<List<int>> get stdout => stdoutStream;

  @override
  Stream<List<int>> get stderr => stderrStream;

  @override
  Future<int> get exitCode => exitCodeFuture;

  @override
  int get pid => 9999;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }
}
