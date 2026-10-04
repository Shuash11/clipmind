import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:uuid/uuid.dart';

import 'ffmpeg_binary_resolver.dart';

class FfmpegProgress {
  final double percent;
  final int outTimeMs;
  final String speed;
  final String status;

  const FfmpegProgress({
    required this.percent,
    required this.outTimeMs,
    required this.speed,
    required this.status,
  });
}

class FfmpegJob {
  final String id;
  final List<String> args;
  final int expectedDurationMs;
  final String inputPath;
  final String outputPath;
  final String label;

  const FfmpegJob({
    required this.id,
    required this.args,
    required this.expectedDurationMs,
    required this.inputPath,
    required this.outputPath,
    this.label = '',
  });
}

class FfmpegResult {
  final bool success;
  final String outputPath;
  final int exitCode;
  final String? stderr;
  final String? error;

  const FfmpegResult({
    required this.success,
    required this.outputPath,
    required this.exitCode,
    this.stderr,
    this.error,
  });
}

class FfmpegService {
  final FfmpegBinaryResolver _resolver;
  final String _tempDir;
  final _uuid = const Uuid();

  /// Hung jobs resolve to a typed failure within this window; the child
  /// is KILLED on timeout so the UI can never wedge on a wedged ffmpeg.
  final Duration jobTimeout;

  /// Test seam: replaces the real process execution. Tests inject a
  /// never-completing future plus a short [jobTimeout] to verify the
  /// timeout → failed-result contract without spawning processes.
  final Future<ProcessResult> Function(String binary, List<String> args)?
      runJob;

  /// Stall watchdog window for the streaming [run] path. A healthy ffmpeg
  /// emits `-progress` lines about every 0.5 s, so 120 s only fires when
  /// the child is truly hung (no progress events at all).
  final Duration stallTimeout;

  /// Test seam for the streaming [run] path, consistent with [runJob].
  /// When non-null, replaces the real `Process.start` so tests can inject
  /// never-emitting stdout streams plus a short [stallTimeout] to verify
  /// the stall → kill → typed-failure contract without spawning processes.
  final Future<Process> Function(String binary, List<String> args)?
      startProcess;

  Process? _process;

  FfmpegService({
    FfmpegBinaryResolver? resolver,
    String? tempDir,
    this.jobTimeout = const Duration(minutes: 15),
    this.runJob,
    this.stallTimeout = const Duration(seconds: 120),
    this.startProcess,
  })  : _resolver = resolver ?? FfmpegBinaryResolver(),
        _tempDir = tempDir ?? Directory.systemTemp.path;

  /// Visible for testing: true while a streaming [run] holds a child
  /// handle. Lets tests verify the try/finally always clears [_process]
  /// on stall, completion, and generator cancellation.
  @visibleForTesting
  bool get hasActiveProcess => _process != null;

  String get tempDir => _tempDir;

  String createTempPath({String? suffix}) {
    final dir = Directory('$_tempDir/.clipmind');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return '${dir.path}/${_uuid.v4()}${suffix ?? '.mp4'}';
  }

  Stream<FfmpegProgress> run(FfmpegJob job) async* {
    final binary = _resolver.resolveFfmpeg();
    if (binary == null) {
      throw const FfmpegBinaryNotFoundException(
        'FFmpeg binary not found. Check installation or configure path in settings.',
      );
    }

    if (!File(job.inputPath).existsSync()) {
      throw Exception('Input file not found: ${job.inputPath}');
    }
    try {
      File(job.outputPath).parent.createSync(recursive: true);
    } catch (e) {
      throw Exception(
        'Failed to create output directory for "${job.outputPath}": $e',
      );
    }

    final starter = startProcess;
    final process = starter != null
        ? await starter(binary, [
            ...job.args,
            '-progress',
            'pipe:1',
            '-nostats',
            '-y',
            job.outputPath,
          ])
        : await Process.start(binary, [
            ...job.args,
            '-progress',
            'pipe:1',
            '-nostats',
            '-y',
            job.outputPath,
          ]);

    _process = process;

    try {
      // Drain stderr while parsing stdout progress: FFmpeg logs to stderr
      // and an unread pipe blocks the child once the OS buffer fills,
      // hanging the export. Live-gate finding 2026-10-01 (gate 1 hung here).
      final stderrDrained = process.stderr.transform(utf8.decoder).join();

      // Stall watchdog: the timer resets on every emitted progress line,
      // so a healthy export (lines every ~0.5 s) never fires; a hung
      // ffmpeg emits nothing and trips [stallTimeout].
      final lineStream = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(stallTimeout, onTimeout: (sink) {
        sink.addError(
          TimeoutException(
            'FFmpeg stalled — no progress for ${stallTimeout.inSeconds}s',
          ),
        );
      });

      String currentSpeed = '';
      await for (final line in lineStream) {
        if (line.contains('=')) {
          final eq = line.indexOf('=');
          if (eq == -1) continue;
          final key = line.substring(0, eq).trim();
          final value = line.substring(eq + 1).trim();

          if (key == 'out_time_ms') {
            final outTimeMs = int.tryParse(value) ?? 0;
            final percent = job.expectedDurationMs > 0
                ? (outTimeMs / job.expectedDurationMs).clamp(0.0, 1.0)
                : 0.0;
            yield FfmpegProgress(
              percent: percent,
              outTimeMs: outTimeMs,
              speed: currentSpeed,
              status: 'running',
            );
          } else if (key == 'speed') {
            currentSpeed = value;
          } else if (key == 'progress') {
            if (value == 'end') {
              yield FfmpegProgress(
                percent: 1.0,
                outTimeMs: job.expectedDurationMs,
                speed: currentSpeed,
                status: 'complete',
              );
            }
          }
        }
      }

      await stderrDrained;
      await process.exitCode;
    } on TimeoutException {
      // Hung child: kill it so the UI can never wedge, then surface a
      // typed, actionable failure (same wording family as the runSync
      // timeout) for the export consumer's `catch (e)`.
      try {
        process.kill();
      } catch (_) {}
      throw FfmpegStallException(
        'FFmpeg stalled — no progress for ${stallTimeout.inSeconds}s — '
        'the job took too long, the source is too large, '
        'or the disk is too slow',
      );
    } finally {
      // Generator cancellation (use-case break) lands here too: never
      // leak a stale handle.
      _process = null;
    }
  }

  Future<FfmpegResult> runSync(FfmpegJob job) async {
    final binary = _resolver.resolveFfmpeg();
    if (binary == null) {
      return FfmpegResult(
        success: false,
        outputPath: job.outputPath,
        exitCode: -1,
        stderr: 'FFmpeg binary not found',
        error: 'FFmpeg binary not found',
      );
    }

    if (!File(job.inputPath).existsSync()) {
      return FfmpegResult(
        success: false,
        outputPath: job.outputPath,
        exitCode: -1,
        error: 'Input not found: ${job.inputPath}',
      );
    }

    try {
      File(job.outputPath).parent.createSync(recursive: true);
      final fullArgs = [...job.args, '-y', job.outputPath];
      final ProcessResult raw;
      final runner = runJob;
      if (runner != null) {
        raw = await runner(binary, fullArgs).timeout(jobTimeout);
      } else {
        final process = await Process.start(binary, fullArgs);
        // Drain both pipes immediately so a chatty child never blocks
        // on a full OS buffer (same rule as the streaming `run` path).
        final stdoutFuture =
            process.stdout.transform(utf8.decoder).join();
        final stderrFuture =
            process.stderr.transform(utf8.decoder).join();
        int exitCode;
        try {
          exitCode = await process.exitCode.timeout(jobTimeout);
        } on TimeoutException {
          process.kill();
          return FfmpegResult(
            success: false,
            outputPath: job.outputPath,
            exitCode: -1,
            stderr: null,
            error: 'FFmpeg timed out after ${jobTimeout.inSeconds}s — '
                'the job took too long or the source is too large',
          );
        }
        final stdout = await stdoutFuture;
        final stderr = await stderrFuture;
        raw = ProcessResult(process.pid, exitCode, stdout, stderr);
      }
      return FfmpegResult(
        success: raw.exitCode == 0,
        outputPath: job.outputPath,
        exitCode: raw.exitCode,
        stderr: (raw.stderr as String?)?.isNotEmpty == true
            ? raw.stderr as String?
            : null,
      );
    } on TimeoutException {
      return FfmpegResult(
        success: false,
        outputPath: job.outputPath,
        exitCode: -1,
        stderr: null,
        error: 'FFmpeg timed out after ${jobTimeout.inSeconds}s — '
            'the job took too long or the source is too large',
      );
    } catch (e, s) {
      debugPrint('FfmpegService error: $e\n$s');
      return FfmpegResult(
        success: false,
        outputPath: job.outputPath,
        exitCode: -1,
        stderr: null,
        error: e.toString(),
      );
    }
  }

  void cancel() {
    _process?.kill(ProcessSignal.sigint);
    _process = null;
  }

  void dispose() {
    cancel();
    final dir = Directory('$_tempDir/.clipmind');
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

class FfmpegBinaryNotFoundException implements Exception {
  final String message;
  const FfmpegBinaryNotFoundException(this.message);

  @override
  String toString() => 'FfmpegBinaryNotFoundException: $message';
}

/// Typed stall failure for the streaming [FfmpegService.run] path.
/// Thrown when the watchdog sees no progress lines within [FfmpegService.stallTimeout];
/// the hung child has already been killed. The export use-case maps this
/// via its existing `catch (e)` to a failed `ExportResult`.
class FfmpegStallException implements Exception {
  final String message;
  const FfmpegStallException(this.message);

  @override
  String toString() => 'FfmpegStallException: $message';
}
