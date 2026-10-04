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

  /// True while a streaming [run] is in flight, including the startup
  /// window where the child has not been assigned to [_process] yet.
  /// Backs the single-flight guard and the cancel-during-startup race fix.
  bool _streamingBusy = false;

  /// Set by [cancel] when a streaming run is in flight but [_process] is
  /// still null (startup window) or to mark an active run as cancelled so
  /// the exit-code gate does not turn a deliberate cancel into a failure.
  /// Cleared when each run is claimed; idle cancels never set it.
  bool _cancelPending = false;

  FfmpegService({
    FfmpegBinaryResolver? resolver,
    String? tempDir,
    this.jobTimeout = const Duration(minutes: 15),
    this.runJob,
    this.stallTimeout = const Duration(seconds: 120),
    this.startProcess,
  }) : _resolver = resolver ?? FfmpegBinaryResolver(),
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

  /// Streams FFmpeg `-progress` events for [job].
  ///
  /// Overwrite policy (`-y`, doc only — no behavior change): temporary
  /// outputs from [createTempPath] carry a uuid filename, so `-y` can never
  /// clobber an unrelated file; caller-chosen [FfmpegJob.outputPath] values
  /// overwrite deliberately because the caller selected that exact path.
  ///
  /// Lifecycle: single-flight (a second concurrent [run] throws
  /// [FfmpegBusyException]); a [cancel] during startup kills the
  /// late-arriving child and ends the stream with no events (the export
  /// use-case maps this via its cancelled flag); non-zero exit codes throw
  /// [FfmpegExitCodeException] so a partial output is never silent success.
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

    // Single-flight: the shared [_process] cancel target cannot serve two
    // concurrent runs — reject instead of clobbering. Synchronous with the
    // claim below, so two listeners racing to start resolve deterministically.
    if (_streamingBusy) {
      throw const FfmpegBusyException(
        'FFmpeg is busy — another export is already running',
      );
    }
    _streamingBusy = true;
    _cancelPending = false;

    try {
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

      // Cancel-during-startup race: [cancel] arriving while awaiting the
      // child above saw [_process] == null and could only set [_cancelPending].
      // Kill the late arrival immediately and end the stream with no events
      // (silent cancel, same as an active-run cancel) instead of leaking it.
      if (_cancelPending) {
        try {
          process.kill(ProcessSignal.sigint);
        } catch (_) {}
        return;
      }

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
            .timeout(
              stallTimeout,
              onTimeout: (sink) {
                sink.addError(
                  TimeoutException(
                    'FFmpeg stalled — no progress for ${stallTimeout.inSeconds}s',
                  ),
                );
              },
            );

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
        final exitCode = await process.exitCode;
        if (exitCode != 0) {
          // A deliberate [cancel] (SIGINT) also exits non-zero: end silently
          // and let the caller map it via its cancelled flag instead of
          // turning an intentional cancel into a failure.
          if (_cancelPending) return;
          throw FfmpegExitCodeException(
            'FFmpeg failed with exit code $exitCode — '
            'the output file "${job.outputPath}" may be incomplete',
          );
        }
      } on TimeoutException {
        // A deliberate [cancel] closes the pipes so the loop above ends
        // instead of stalling; if the pipes never close, still honor it.
        if (_cancelPending) return;
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
    } finally {
      _process = null;
      _streamingBusy = false;
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
        final stdoutFuture = process.stdout.transform(utf8.decoder).join();
        final stderrFuture = process.stderr.transform(utf8.decoder).join();
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
            error:
                'FFmpeg timed out after ${jobTimeout.inSeconds}s — '
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
        error:
            'FFmpeg timed out after ${jobTimeout.inSeconds}s — '
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

  /// Requests cancellation of an in-flight streaming [run].
  ///
  /// An already-running child is signalled (SIGINT). A cancel arriving in
  /// the startup window (run claimed busy, child not yet assigned) sets
  /// [_cancelPending] so the late-arriving child is killed immediately
  /// instead of leaking. Idle cancels are no-ops and never poison the
  /// next run.
  void cancel() {
    if (_streamingBusy) _cancelPending = true;
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

/// Typed single-flight failure for the streaming [FfmpegService.run] path.
/// Thrown synchronously when a second concurrent run starts while one is in
/// flight (the shared cancel handle cannot serve two children). Matches the
/// export UI's single-export reality. Surfaced via the consumer's `catch (e)`.
class FfmpegBusyException implements Exception {
  final String message;
  const FfmpegBusyException(this.message);

  @override
  String toString() => 'FfmpegBusyException: $message';
}

/// Typed exit-code failure for the streaming [FfmpegService.run] path.
/// Thrown when FFmpeg exits non-zero after a normally-completed progress
/// stream, so a partial output file is never mistaken for success via the
/// consumer's file-exists check. Surfaced via the consumer's `catch (e)`.
class FfmpegExitCodeException implements Exception {
  final String message;
  const FfmpegExitCodeException(this.message);

  @override
  String toString() => 'FfmpegExitCodeException: $message';
}
