import 'dart:async';
import 'dart:io';

import 'package:clipmind/data/models/export_options.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:uuid/uuid.dart';

class ExportResult {
  final bool success;
  final String outputPath;
  final String? error;

  const ExportResult({
    required this.success,
    required this.outputPath,
    this.error,
  });
}

class ExportProjectUseCase {
  final FfmpegService _ffmpegService;
  final _uuid = const Uuid();
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();
  bool _cancelled = false;

  ExportProjectUseCase({FfmpegService? ffmpegService})
      : _ffmpegService = ffmpegService ?? FfmpegService();

  Stream<double> get progressStream => _progressController.stream;

  void cancel() {
    _cancelled = true;
    _ffmpegService.cancel();
  }

  Future<ExportResult> execute(
    Project project, {
    ExportOptions options = const ExportOptions(
      format: 'mp4',
      resolution: 'source',
      quality: 'high',
      crf: 18,
      outputPath: '',
    ),
  }) async {
    _cancelled = false;

    try {
      final allClips =
          project.tracks.expand((track) => track.clips).toList();
      if (allClips.isEmpty) {
        _progressController.add(1.0);
        return ExportResult(
          success: false,
          outputPath: options.outputPath,
          error: 'No clips to export',
        );
      }

      final outputPath = options.outputPath.isNotEmpty
          ? options.outputPath
          : _ffmpegService.createTempPath(suffix: '.${options.format}');

      final args = _buildExportArgs(project, options);
      if (_cancelled) {
        return ExportResult(
          success: false,
          outputPath: outputPath,
          error: 'Export cancelled',
        );
      }

      final job = FfmpegJob(
        id: _uuid.v4(),
        args: args,
        expectedDurationMs: project.durationMs > 0
            ? project.durationMs
            : 30000,
        inputPath: allClips.first.sourcePath,
        outputPath: outputPath,
        label: 'Export ${project.name}',
      );

      await for (final progress in _ffmpegService.run(job)) {
        if (_cancelled) break;
        _progressController.add(progress.percent);
        if (progress.status == 'complete') {
          _progressController.add(1.0);
        }
      }

      if (_cancelled) {
        return ExportResult(
          success: false,
          outputPath: outputPath,
          error: 'Export cancelled',
        );
      }

      if (!File(outputPath).existsSync()) {
        return ExportResult(
          success: false,
          outputPath: outputPath,
          error: 'Output file was not created',
        );
      }

      _progressController.add(1.0);
      return ExportResult(
        success: true,
        outputPath: outputPath,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        outputPath: options.outputPath,
        error: e.toString(),
      );
    }
  }

  List<String> _buildExportArgs(Project project, ExportOptions options) {
    final args = <String>[];
    final allClips =
        project.tracks.expand((track) => track.clips).toList();

    final inputPaths = <String>[];
    for (final clip in allClips) {
      if (!inputPaths.contains(clip.sourcePath)) {
        inputPaths.add(clip.sourcePath);
      }
    }

    for (final path in inputPaths) {
      args.addAll(['-i', path]);
    }

    final filterParts = <String>[];
    final concatInputLabels = <String>[];

    for (var i = 0; i < allClips.length; i++) {
      final clip = allClips[i];
      final inputIndex = inputPaths.indexOf(clip.sourcePath);
      final startSec = clip.startMs / 1000.0;
      final endSec = clip.endMs / 1000.0;
      final durSec = (clip.endMs - clip.startMs) / 1000.0;

      if (startSec <= 0 && durSec <= 0) {
        final vLabel = 'c${i}v';
        final aLabel = 'c${i}a';
        filterParts.add('[$inputIndex:v:0]setpts=PTS-STARTPTS[$vLabel]');
        if (!clip.muted) {
          filterParts
              .add('[$inputIndex:a:0]asetpts=PTS-STARTPTS[$aLabel]');
        } else {
          filterParts.add('anullsrc=r=44100:d=1[$aLabel]');
        }
        concatInputLabels.add('[$vLabel]');
        concatInputLabels.add('[$aLabel]');
      } else {
        final vLabel = 'c${i}v';
        final aLabel = 'c${i}a';
        filterParts.add(
          '[$inputIndex:v:0]trim=start=$startSec:end=$endSec,'
          'setpts=PTS-STARTPTS[$vLabel]',
        );
        if (!clip.muted) {
          filterParts.add(
            '[$inputIndex:a:0]atrim=start=$startSec:end=$endSec,'
            'asetpts=PTS-STARTPTS[$aLabel]',
          );
        } else {
          filterParts.add('anullsrc=r=44100:d=$durSec[$aLabel]');
        }
        concatInputLabels.add('[$vLabel]');
        concatInputLabels.add('[$aLabel]');
      }
    }

    final n = allClips.length;
    final concatInputStr = concatInputLabels.join('');

    if (options.resolution != 'source') {
      final (targetW, targetH) = _resolutionDims(options.resolution);
      filterParts.add(
        '${concatInputStr}concat=n=$n:v=1:a=1[outv][outa];'
        '[outv]scale=$targetW:$targetH:force_original_aspect_ratio=1,'
        'pad=$targetW:$targetH:(ow-iw)/2:(oh-ih)/2[finalv]',
      );
      args.addAll(['-filter_complex', filterParts.join(';')]);
      args.addAll(['-map', '[finalv]', '-map', '[outa]']);
    } else {
      filterParts.add(
        '${concatInputStr}concat=n=$n:v=1:a=1[outv][outa]',
      );
      args.addAll(['-filter_complex', filterParts.join(';')]);
      args.addAll(['-map', '[outv]', '-map', '[outa]']);
    }

    final (videoCodec, audioCodec) = _codecsForFormat(options.format);
    final pixFmt = options.format == 'gif' ? '' : '-pix_fmt yuv420p';

    args.addAll(['-c:v', videoCodec]);
    if (videoCodec == 'libx264' || videoCodec == 'libx265') {
      args.addAll(['-crf', options.crf.toString()]);
    }
    if (pixFmt.isNotEmpty) {
      args.addAll(pixFmt.split(' '));
    }
    if (audioCodec.isNotEmpty && options.format != 'gif') {
      args.addAll(['-c:a', audioCodec]);
    }

    if (options.format == 'gif') {
      args.addAll(['-r', '10']);
    }

    return args;
  }

  (String, String) _codecsForFormat(String format) {
    switch (format) {
      case 'mp4':
        return ('libx264', 'aac');
      case 'mov':
        return ('libx264', 'aac');
      case 'webm':
        return ('libvpx-vp9', 'libopus');
      case 'gif':
        return ('gif', '');
      default:
        return ('libx264', 'aac');
    }
  }

  (int, int) _resolutionDims(String resolution) {
    switch (resolution) {
      case '480p':
        return (854, 480);
      case '720p':
        return (1280, 720);
      case '1080p':
        return (1920, 1080);
      case '4K':
        return (3840, 2160);
      default:
        return (1920, 1080);
    }
  }
}
