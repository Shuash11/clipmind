import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'ffmpeg_binary_resolver.dart';

class VideoMetadata {
  final int durationMs;
  final int width;
  final int height;
  final double fps;
  final String codec;
  final bool hasAudio;
  final int bitrate;
  final double? audioSampleRate;

  const VideoMetadata({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.fps,
    required this.codec,
    required this.hasAudio,
    required this.bitrate,
    this.audioSampleRate,
  });
}

class FfprobeService {
  final FfmpegBinaryResolver _resolver;

  /// Test seam: replaces the real probe execution. When null the internal
  /// `Process.start` implementation runs (with timeout + kill). Tests
  /// inject a never-completing future plus a short [probeTimeout] to
  /// verify the timeout → null contract without spawning processes.
  final Future<ProcessResult?> Function(String binary, List<String> args)?
      runProbe;

  /// Hung probes resolve to null within this window; the child is KILLED
  /// on timeout so the UI can never wedge on a wedged ffprobe/ffmpeg.
  final Duration probeTimeout;

  FfprobeService({
    FfmpegBinaryResolver? resolver,
    this.runProbe,
    this.probeTimeout = const Duration(seconds: 10),
  }) : _resolver = resolver ?? FfmpegBinaryResolver();

  /// Real probe execution: `Process.start` with immediate stdout/stderr
  /// drains (an unread pipe blocks the child once the OS buffer fills),
  /// then `exitCode.timeout` — on timeout the child is KILLED and the
  /// [TimeoutException] propagates to the caller, which maps it to null.
  Future<ProcessResult> _realRunProbe(
    String binary,
    List<String> args,
  ) async {
    final process = await Process.start(binary, args);
    // Drain both pipes immediately so a chatty child never blocks.
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(probeTimeout);
    } on TimeoutException {
      process.kill();
      rethrow;
    }
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    return ProcessResult(process.pid, exitCode, stdout, stderr);
  }

  Future<VideoMetadata?> extractMetadata(String filePath) async {
    final binary = _resolver.resolveFfprobe();
    if (binary == null) return null;

    final file = File(filePath);
    if (!file.existsSync()) return null;

    try {
      final ProcessResult? result;
      final probe = runProbe;
      if (probe != null) {
        result = await probe(binary, [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          filePath,
        ]).timeout(probeTimeout);
      } else {
        result = await _realRunProbe(binary, [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          filePath,
        ]);
      }
      if (result == null) return null;

      if (result.exitCode != 0) return null;

      final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      return _parseMetadata(data);
    } on TimeoutException catch (e, s) {
      debugPrint('FFprobe timed out: $e\n$s');
      return null;
    } catch (e, s) {
      debugPrint('FFprobe error: $e\n$s');
      return null;
    }
  }

  VideoMetadata _parseMetadata(Map<String, dynamic> data) {
    final format = data['format'] as Map<String, dynamic>? ?? {};
    final durationStr = format['duration'] as String? ?? '0';
    final durationMs = (double.tryParse(durationStr) ?? 0.0) * 1000;
    final bitrateStr = format['bit_rate'] as String? ?? '0';
    final bitrate = int.tryParse(bitrateStr) ?? 0;

    final streams = data['streams'] as List<dynamic>? ?? [];
    int width = 0, height = 0;
    double fps = 0;
    String codec = '';
    bool hasAudio = false;
    double? audioSampleRate;

    for (final s in streams) {
      final stream = s as Map<String, dynamic>;
      final codecType = stream['codec_type'] as String?;
      if (codecType == 'video' && width == 0) {
        width = stream['width'] as int? ?? 0;
        height = stream['height'] as int? ?? 0;
        codec = stream['codec_name'] as String? ?? '';
        final rFrameRate = stream['r_frame_rate'] as String? ?? '0/1';
        final parts = rFrameRate.split('/');
        if (parts.length == 2) {
          final num = double.tryParse(parts[0]) ?? 0;
          final den = double.tryParse(parts[1]) ?? 1;
          fps = den > 0 ? num / den : 0;
        }
      } else if (codecType == 'audio') {
        hasAudio = true;
        final sampleRateStr = stream['sample_rate'] as String?;
        audioSampleRate = double.tryParse(sampleRateStr ?? '');
      }
    }

    return VideoMetadata(
      durationMs: durationMs.round(),
      width: width,
      height: height,
      fps: fps,
      codec: codec,
      hasAudio: hasAudio,
      bitrate: bitrate,
      audioSampleRate: audioSampleRate,
    );
  }

  Future<String?> generateThumbnail(
    String filePath, {
    int atMs = 0,
    String? outputPath,
  }) async {
    final binary = _resolver.resolveFfmpeg();
    if (binary == null) return null;

    final file = File(filePath);
    if (!file.existsSync()) return null;

    final out = outputPath ?? '${filePath}_thumb.jpg';

    try {
      final args = [
        '-ss',
        (atMs / 1000).toStringAsFixed(3),
        '-i',
        filePath,
        '-vframes',
        '1',
        '-q:v',
        '2',
        '-y',
        out,
      ];
      final ProcessResult? result;
      final probe = runProbe;
      if (probe != null) {
        result = await probe(binary, args).timeout(probeTimeout);
      } else {
        result = await _realRunProbe(binary, args);
      }
      if (result == null) return null;
      if (result.exitCode != 0) return null;
      if (!File(out).existsSync()) return null;
      return out;
    } on TimeoutException catch (e, s) {
      debugPrint('FFprobe timed out: $e\n$s');
      return null;
    } catch (e, s) {
      debugPrint('FFprobe error: $e\n$s');
      return null;
    }
  }
}
