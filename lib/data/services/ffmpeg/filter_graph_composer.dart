import 'package:uuid/uuid.dart';

import 'command_builder.dart';
import 'ffmpeg_service.dart';
import '../../models/edit_operation.dart';

class FilterGraphComposer {
  final _uuid = const Uuid();

  List<FfmpegJob> compose(
    List<EditOperation> operations,
    String inputPath,
    String outputPath,
  ) {
    final jobs = <FfmpegJob>[];
    final clipOps = <String, List<EditOperation>>{};

    for (final op in operations) {
      for (final clipId in op.targetClipIds) {
        clipOps.putIfAbsent(clipId, () => []).add(op);
      }
    }

    for (final entry in clipOps.entries) {
      for (final job in _composeClip(entry.value, inputPath, outputPath)) {
        jobs.add(job);
      }
    }

    return jobs;
  }

  List<FfmpegJob> _composeClip(
    List<EditOperation> ops,
    String inputPath,
    String outputPath,
  ) {
    final standalone = <EditOperation>[];
    final filterable = <EditOperation>[];
    EditOperation? trimOp;

    for (final op in ops) {
      if (op.type == EditOperationType.trim) {
        trimOp = op;
      } else if (op.type == EditOperationType.merge ||
          op.type == EditOperationType.extractAudio ||
          op.type == EditOperationType.generateThumbnail) {
        standalone.add(op);
      } else {
        filterable.add(op);
      }
    }

    final jobs = <FfmpegJob>[];

    if (filterable.isNotEmpty || trimOp != null) {
      final job = _buildFilterJob(trimOp, filterable, inputPath, outputPath);
      if (job != null) jobs.add(job);
    }

    for (final op in standalone) {
      final job = _buildStandaloneJob(op, inputPath);
      if (job != null) jobs.add(job);
    }

    return jobs;
  }

  FfmpegJob? _buildFilterJob(
    EditOperation? trimOp,
    List<EditOperation> filterOps,
    String inputPath,
    String outputPath,
  ) {
    if (filterOps.isEmpty && trimOp == null) return null;

    final args = <String>[];

    if (trimOp != null) {
      final start = _paramString(trimOp.params, 'start', '0');
      args.addAll(['-ss', start]);
    }

    args.addAll(['-i', inputPath]);

    if (trimOp != null) {
      final end = _paramString(trimOp.params, 'end', '0');
      args.addAll(['-to', end]);
    }

    final videoFilters = <String>[];
    final audioFilters = <String>[];

    for (final op in filterOps) {
      _accumulateFilter(op, videoFilters, audioFilters);
    }

    if (videoFilters.isNotEmpty && audioFilters.isNotEmpty) {
      final vChain = videoFilters.join(',');
      final aChain = audioFilters.join(',');
      args.addAll([
        '-filter_complex',
        '[0:v]$vChain[vout];[0:a]$aChain[aout]',
        '-map',
        '[vout]',
        '-map',
        '[aout]',
      ]);
    } else if (videoFilters.isNotEmpty) {
      args.addAll(['-vf', videoFilters.join(',')]);
    } else if (audioFilters.isNotEmpty) {
      args.addAll(['-af', audioFilters.join(',')]);
    }

    final label = filterOps.map((o) => o.type.name).join('+');

    return FfmpegJob(
      id: _uuid.v4(),
      args: args,
      expectedDurationMs: 0,
      inputPath: inputPath,
      outputPath: outputPath,
      label: label,
    );
  }

  void _accumulateFilter(
    EditOperation op,
    List<String> videoFilters,
    List<String> audioFilters,
  ) {
    final p = op.params;
    switch (op.type) {
      case EditOperationType.cut:
        final removeStart = _paramString(p, 'remove_start', '0');
        final removeEnd = _paramString(p, 'remove_end', '0');
        videoFilters.add("select='not(between(t,$removeStart,$removeEnd))'");
        videoFilters.add('setpts=N/FRAME_RATE/TB');
        audioFilters.add("aselect='not(between(t,$removeStart,$removeEnd))'");
        audioFilters.add('asetpts=N/SR/TB');
        break;

      case EditOperationType.changeSpeed:
        final factor = _paramNum(p, 'factor', 1.0);
        videoFilters.add('setpts=PTS/$factor');
        audioFilters.add(_atempoChain(factor));
        break;

      case EditOperationType.overlayText:
        {
          final text = _paramString(p, 'text', '');
          final escaped = text
              .replaceAll('\\', '\\\\')
              .replaceAll("'", "\\'")
              .replaceAll(':', '\\:');
          final position = _paramString(p, 'position', 'center');
          final start = (_paramNum(p, 'start', 0)).toStringAsFixed(3);
          final end = (_paramNum(p, 'end', 0)).toStringAsFixed(3);
          final fontSize = p['font_size']?.toString() ?? '48';
          final color = _paramString(p, 'color', '#FFFFFF');

          String x, y;
          switch (position) {
            case 'center':
              x = '(w-text_w)/2';
              y = '(h-text_h)/2';
              break;
            case 'top-right':
              x = 'W-w-10';
              y = '10';
              break;
            case 'bottom-left':
              x = '10';
              y = 'H-h-10';
              break;
            case 'bottom-right':
              x = 'W-w-10';
              y = 'H-h-10';
              break;
            default:
              x = '10';
              y = '10';
          }

          final enable = (start != '0.000' || end != '0.000')
              ? ":enable='between(t,$start,$end)'"
              : '';
          videoFilters.add(
            "drawtext=text='$escaped':"
            'fontsize=$fontSize:'
            'fontcolor=$color:'
            'x=$x:y=$y'
            '$enable',
          );
          break;
        }

      case EditOperationType.resize:
        {
          final width = _paramInt(p, 'width', 1920);
          final height = _paramInt(p, 'height', 1080);
          final fit = _paramString(p, 'fit', 'fill');
          switch (fit) {
            case 'fill':
              videoFilters.add(
                'scale=$width:$height:force_original_aspect_ratio=1,'
                'crop=$width:$height',
              );
              break;
            case 'fit':
              videoFilters.add(
                'scale=$width:$height:force_original_aspect_ratio=1,'
                'pad=$width:$height:(ow-iw)/2:(oh-ih)/2',
              );
              break;
            case 'stretch':
              videoFilters.add('scale=$width:$height');
              break;
            default:
              videoFilters.add(
                'scale=$width:$height:force_original_aspect_ratio=1',
              );
          }
          break;
        }

      case EditOperationType.rotate:
        {
          final degrees = _paramNum(p, 'degrees', 0);
          if (degrees == 90) {
            videoFilters.add('transpose=1');
          } else if (degrees == 180) {
            videoFilters.add('transpose=1,transpose=1');
          } else if (degrees == 270) {
            videoFilters.add('transpose=2');
          } else {
            videoFilters.add('rotate=$degrees*PI/180');
          }
          break;
        }

      case EditOperationType.adjustBrightness:
        {
          final value = _paramNum(p, 'value', 0).clamp(-1.0, 1.0);
          videoFilters.add('eq=brightness=$value');
          break;
        }

      case EditOperationType.changeVolume:
        final factor = _paramNum(p, 'factor', 1.0);
        audioFilters.add('volume=$factor');
        break;

      case EditOperationType.mute:
      case EditOperationType.trim:
      case EditOperationType.merge:
      case EditOperationType.extractAudio:
      case EditOperationType.generateThumbnail:
      case EditOperationType.changeFormat:
      case EditOperationType.overlayWatermark:
        break;
    }
  }

  String _atempoChain(double factor) {
    final filters = <String>[];
    var remaining = factor;
    while (remaining > 2.0) {
      filters.add('atempo=2.0');
      remaining /= 2.0;
    }
    while (remaining < 0.5) {
      filters.add('atempo=0.5');
      remaining /= 0.5;
    }
    filters.add('atempo=$remaining');
    return filters.join(',');
  }

  FfmpegJob? _buildStandaloneJob(EditOperation op, String inputPath) {
    final args = _buildOpArgs(op, inputPath);
    if (args == null) return null;

    final ext = _outputExtension(op);
    final outputPath = '${inputPath}_${op.id}.$ext';

    return FfmpegJob(
      id: op.id,
      args: args,
      expectedDurationMs: 0,
      inputPath: inputPath,
      outputPath: outputPath,
      label: op.type.name,
    );
  }

  List<String>? _buildOpArgs(EditOperation op, String inputPath) {
    final p = op.params;
    switch (op.type) {
      case EditOperationType.trim:
        return CommandBuilder.trim(
          inputPath,
          _paramString(p, 'start', '0'),
          _paramString(p, 'end', '0'),
        );
      case EditOperationType.cut:
        return CommandBuilder.cut(
          inputPath,
          _paramString(p, 'remove_start', '0'),
          _paramString(p, 'remove_end', '0'),
        );
      case EditOperationType.merge:
        final paths =
            (p['clip_ids'] as List<dynamic>?)?.cast<String>() ?? <String>[];
        return CommandBuilder.merge(paths);
      case EditOperationType.changeSpeed:
        return CommandBuilder.changeSpeed(
          inputPath,
          _paramNum(p, 'factor', 1.0),
        );
      case EditOperationType.mute:
        return CommandBuilder.mute(inputPath);
      case EditOperationType.overlayText:
        return CommandBuilder.overlayText(
          inputPath,
          text: _paramString(p, 'text', ''),
          position: _paramString(p, 'position', 'center'),
          start: _paramString(p, 'start', '0'),
          end: _paramString(p, 'end', '0'),
          fontSize: _paramInt(p, 'font_size', 48),
          color: _paramString(p, 'color', '#FFFFFF'),
        );
      case EditOperationType.resize:
        return CommandBuilder.resize(
          inputPath,
          _paramInt(p, 'width', 1920),
          _paramInt(p, 'height', 1080),
          _paramString(p, 'fit', 'fill'),
        );
      case EditOperationType.rotate:
        return CommandBuilder.rotate(inputPath, _paramNum(p, 'degrees', 0));
      case EditOperationType.extractAudio:
        return CommandBuilder.extractAudio(
          inputPath,
          _paramString(p, 'output_format', 'mp3'),
        );
      case EditOperationType.generateThumbnail:
        return CommandBuilder.generateThumbnail(
          inputPath,
          (_paramNum(p, 'timestamp', 0)).toString(),
        );
      case EditOperationType.changeFormat:
        return CommandBuilder.changeFormat(
          inputPath,
          _paramString(p, 'target_ext', 'mp4'),
          p['codec_preset'] as String?,
        );
      case EditOperationType.adjustBrightness:
        return CommandBuilder.adjustBrightness(
          inputPath,
          _paramNum(p, 'value', 0),
        );
      case EditOperationType.changeVolume:
        return CommandBuilder.changeVolume(
          inputPath,
          _paramNum(p, 'factor', 1.0),
        );
      case EditOperationType.overlayWatermark:
        return CommandBuilder.overlayWatermark(
          inputPath,
          _paramString(p, 'image_path', ''),
          _paramString(p, 'position', 'bottom-right'),
          _paramNum(p, 'opacity', 0.7),
        );
    }
  }

  String _outputExtension(EditOperation op) {
    return switch (op.type) {
      EditOperationType.extractAudio => _paramString(
        op.params,
        'output_format',
        'mp3',
      ),
      EditOperationType.generateThumbnail => 'jpg',
      EditOperationType.changeFormat => _paramString(
        op.params,
        'target_ext',
        'mp4',
      ),
      _ => 'mp4',
    };
  }

  String _paramString(Map<String, dynamic> p, String key, String fallback) {
    final v = p[key];
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  double _paramNum(Map<String, dynamic> p, String key, double fallback) {
    final v = p[key];
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  int _paramInt(Map<String, dynamic> p, String key, int fallback) {
    final v = p[key];
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }
}
