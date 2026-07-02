import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  const FfmpegResult({
    required this.success,
    required this.outputPath,
    required this.exitCode,
    this.stderr,
  });
}

class FfmpegService {
  final FfmpegBinaryResolver _resolver;
  final String _tempDir;
  final _uuid = const Uuid();

  Process? _process;

  FfmpegService({
    FfmpegBinaryResolver? resolver,
    String? tempDir,
  })  : _resolver = resolver ?? FfmpegBinaryResolver(),
        _tempDir = tempDir ?? Directory.systemTemp.path;

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

    final process = await Process.start(binary, [
      ...job.args,
      '-progress', 'pipe:1',
      '-nostats',
      '-y',
      job.outputPath,
    ]);

    _process = process;

    final lineStream = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());

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

    await process.exitCode;
    _process = null;
  }

  Future<FfmpegResult> runSync(FfmpegJob job) async {
    final binary = _resolver.resolveFfmpeg();
    if (binary == null) {
      return FfmpegResult(
        success: false,
        outputPath: job.outputPath,
        exitCode: -1,
        stderr: 'FFmpeg binary not found',
      );
    }

    try {
      final result = await Process.run(binary, [
        ...job.args,
        '-y',
        job.outputPath,
      ]);
      return FfmpegResult(
        success: result.exitCode == 0,
        outputPath: job.outputPath,
        exitCode: result.exitCode,
        stderr: (result.stderr as String?)?.isNotEmpty == true
            ? result.stderr as String?
            : null,
      );
    } catch (e) {
      return FfmpegResult(
        success: false,
        outputPath: job.outputPath,
        exitCode: -1,
        stderr: e.toString(),
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
