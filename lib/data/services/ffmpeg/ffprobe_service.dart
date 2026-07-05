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

  FfprobeService({FfmpegBinaryResolver? resolver})
      : _resolver = resolver ?? FfmpegBinaryResolver();

  Future<VideoMetadata?> extractMetadata(String filePath) async {
    final binary = _resolver.resolveFfprobe();
    if (binary == null) return null;

    final file = File(filePath);
    if (!file.existsSync()) return null;

    try {
      final result = await Process.run(binary, [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        filePath,
      ]);

      if (result.exitCode != 0) return null;

      final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      return _parseMetadata(data);
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
      final result = await Process.run(binary, [
        '-ss', (atMs / 1000).toStringAsFixed(3),
        '-i', filePath,
        '-vframes', '1',
        '-q:v', '2',
        '-y',
        out,
      ]);
      if (result.exitCode != 0) return null;
      if (!File(out).existsSync()) return null;
      return out;
    } catch (e, s) {
      debugPrint('FFprobe error: $e\n$s');
      return null;
    }
  }
}
