import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'operation_schema.dart';

class CommandMapper {
  static const _composableTypes = {
    'trim', 'cut', 'change_speed', 'mute', 'overlay_text',
    'resize', 'rotate', 'adjust_brightness', 'change_volume',
    'overlay_watermark',
  };

  static const _singlePassTypes = {
    'extract_audio', 'generate_thumbnail', 'change_format', 'merge',
  };

  static List<FfmpegJob> mapOperations(
    EditOperationSet operationSet,
    String inputPath,
  ) {
    final jobs = <FfmpegJob>[];

    final byClip = <String, List<EditOperationRequest>>{};
    final standaloneOps = <EditOperationRequest>[];

    for (final op in operationSet.operations) {
      if (_singlePassTypes.contains(op.type) || op.type == 'merge') {
        standaloneOps.add(op);
      } else {
        final clipId = op.targetClipId?.toString() ?? '_default';
        byClip.putIfAbsent(clipId, () => []).add(op);
      }
    }

    for (final entry in byClip.entries) {
      final ops = entry.value;
      if (ops.isEmpty) continue;

      final composable = ops
          .where((o) => _composableTypes.contains(o.type))
          .toList();
      if (composable.length >= 2) {
        jobs.addAll(_composeMultiOp(composable, inputPath));
      } else {
        for (final op in ops) {
          jobs.add(_buildSingleJob(op, inputPath));
        }
      }
    }

    for (final op in standaloneOps) {
      jobs.add(_buildSingleJob(op, inputPath));
    }

    return jobs;
  }

  static List<FfmpegJob> _composeMultiOp(
    List<EditOperationRequest> ops,
    String inputPath,
  ) {
    final hasOverlayWatermark = ops.any((o) => o.type == 'overlay_watermark');
    final hasMute = ops.any((o) => o.type == 'mute');
    final hasOverlayText = ops.any((o) => o.type == 'overlay_text');

    if (hasOverlayWatermark && (hasOverlayText || hasMute)) {
      return ops.map((o) => _buildSingleJob(o, inputPath)).toList();
    }

    return [_composeFilterGraph(ops, inputPath)];
  }

  static FfmpegJob _composeFilterGraph(
    List<EditOperationRequest> ops,
    String inputPath,
  ) {
    final filters = <String>[];
    final audioFilters = <String>[];
    bool hasAudio = true;

    filters.add('[0:v]null[v0]');

    for (int i = 0; i < ops.length; i++) {
      final op = ops[i];
      final params = op.params;
      final prev = 'v$i';
      final next = 'v${i + 1}';

      switch (op.type) {
        case 'trim':
          final start = params['start'] as String? ?? '0';
          final end = params['end'] as String?;
          if (end != null) {
            filters.add('[$prev]trim=$start:$end,setpts=PTS-STARTPTS[$next]');
            audioFilters.add('[0:a]atrim=$start:$end,asetpts=PTS-STARTPTS[a$i]');
          } else {
            filters.add('[$prev]trim=$start,setpts=PTS-STARTPTS[$next]');
            audioFilters.add('[0:a]atrim=$start,asetpts=PTS-STARTPTS[a$i]');
          }
          break;

        case 'change_speed':
          final factor = (params['factor'] as num?)?.toDouble() ?? 1.0;
          filters.add('[$prev]setpts=PTS/$factor[$next]');
          var af = factor;
          final atempoParts = <String>[];
          while (af > 2.0) {
            atempoParts.add('atempo=2.0');
            af /= 2.0;
          }
          while (af < 0.5) {
            atempoParts.add('atempo=0.5');
            af /= 0.5;
          }
          atempoParts.add('atempo=$af');
          audioFilters.add('[0:a]${atempoParts.join(',')}[a$i]');
          break;

        case 'resize':
          final w = (params['width'] as num?)?.toInt() ?? 1920;
          final h = (params['height'] as num?)?.toInt() ?? 1080;
          filters.add(
            '[$prev]scale=$w:$h:force_original_aspect_ratio=1,crop=$w:$h[$next]',
          );
          break;

        case 'rotate':
          final degrees = (params['degrees'] as num?)?.toDouble() ?? 0;
          if (degrees == 90) {
            filters.add('[$prev]transpose=1[$next]');
          } else if (degrees == 180) {
            filters.add('[$prev]transpose=1,transpose=1[$next]');
          } else if (degrees == 270) {
            filters.add('[$prev]transpose=2[$next]');
          } else {
            filters.add('[$prev]rotate=$degrees*PI/180[$next]');
          }
          break;

        case 'adjust_brightness':
          final value = (params['value'] as num?)?.toDouble() ?? 0.0;
          filters.add(
            '[$prev]eq=brightness=${value.clamp(-1.0, 1.0)}[$next]',
          );
          break;

        case 'overlay_text':
          final text = params['text'] as String? ?? '';
          final pos = params['position'] as String? ?? 'center';
          final fs = (params['font_size'] as num?)?.toInt() ?? 48;
          final color = params['color'] as String? ?? '#FFFFFF';
          final start = params['start'] as String? ?? '0';
          final end = params['end'] as String? ?? '0';
          final x = pos == 'center' ? '(w-text_w)/2' : '10';
          final y = pos == 'center' ? '(h-text_h)/2' : '10';
          final enable = (start == '0' && end == '0')
              ? ''
              : ':enable=\'between(t,$start,$end)\'';
          filters.add(
            '[$prev]drawtext=text=\'$text\':fontsize=$fs:fontcolor=$color:x=$x:y=$y$enable[$next]',
          );
          break;

        case 'change_volume':
          final factor = (params['factor'] as num?)?.toDouble() ?? 1.0;
          audioFilters.add('[0:a]volume=$factor[a$i]');
          break;

        case 'mute':
          hasAudio = false;
          break;

        case 'cut':
          final removeStart = params['remove_start'] as String? ?? '0';
          final removeEnd = params['remove_end'] as String? ?? '0';
          filters.add(
            '[$prev]select=\'not(between(t,$removeStart,$removeEnd))\',setpts=N/FRAME_RATE/TB[$next]',
          );
          audioFilters.add(
            '[0:a]aselect=\'not(between(t,$removeStart,$removeEnd))\',asetpts=N/SR/TB[a$i]',
          );
          break;

        case 'overlay_watermark':
        default:
          break;
      }
    }

    final lastVideoLabel = 'v${ops.length}';
    final filterStr = filters.join(';');
    final audioStr = audioFilters.isNotEmpty ? ';${audioFilters.last}' : '';

    final args = <String>[
      '-i', inputPath,
      '-filter_complex', '$filterStr$audioStr',
      '-map', '[$lastVideoLabel]',
    ];

    if (hasAudio && audioFilters.isNotEmpty) {
      final lastAudioLabel = 'a${ops.length - 1}';
      args.addAll(['-map', '[$lastAudioLabel]']);
    } else if (!hasAudio) {
      args.add('-an');
    } else {
      args.addAll(['-map', '0:a']);
    }

    return FfmpegJob(
      id: ops.first.id,
      args: args,
      expectedDurationMs: 0,
      inputPath: inputPath,
      outputPath: '${inputPath}_composed.mp4',
    );
  }

  static FfmpegJob _buildSingleJob(
    EditOperationRequest op,
    String inputPath,
  ) {
    final params = op.params;
    final List<String> args;

    switch (op.type) {
      case 'trim':
        args = CommandBuilder.trim(
          inputPath,
          params['start'] as String,
          params['end'] as String,
        );
        break;
      case 'cut':
        args = CommandBuilder.cut(
          inputPath,
          params['remove_start'] as String,
          params['remove_end'] as String,
        );
        break;
      case 'merge':
        final clipIds = (params['clip_ids'] as List<dynamic>).cast<String>();
        args = CommandBuilder.merge(clipIds);
        break;
      case 'change_speed':
        args = CommandBuilder.changeSpeed(
          inputPath,
          (params['factor'] as num).toDouble(),
        );
        break;
      case 'mute':
        args = CommandBuilder.mute(inputPath);
        break;
      case 'overlay_text':
        args = CommandBuilder.overlayText(
          inputPath,
          text: params['text'] as String,
          position: params['position'] as String? ?? 'center',
          start: (params['start'] as num?)?.toString() ?? '0',
          end: (params['end'] as num?)?.toString() ?? '0',
          fontSize: (params['font_size'] as num?)?.toInt() ?? 48,
          color: params['color'] as String? ?? '#FFFFFF',
        );
        break;
      case 'resize':
        args = CommandBuilder.resize(
          inputPath,
          (params['width'] as num).toInt(),
          (params['height'] as num).toInt(),
          params['fit'] as String? ?? 'fill',
        );
        break;
      case 'rotate':
        args = CommandBuilder.rotate(
          inputPath,
          (params['degrees'] as num).toDouble(),
        );
        break;
      case 'extract_audio':
        args = CommandBuilder.extractAudio(
          inputPath,
          params['output_format'] as String? ?? 'mp3',
        );
        break;
      case 'generate_thumbnail':
        args = CommandBuilder.generateThumbnail(
          inputPath,
          (params['timestamp'] as num?)?.toString() ?? '0',
        );
        break;
      case 'change_format':
        args = CommandBuilder.changeFormat(
          inputPath,
          params['target_ext'] as String,
          params['codec_preset'] as String?,
        );
        break;
      case 'adjust_brightness':
        args = CommandBuilder.adjustBrightness(
          inputPath,
          (params['value'] as num).toDouble(),
        );
        break;
      case 'change_volume':
        args = CommandBuilder.changeVolume(
          inputPath,
          (params['factor'] as num?)?.toDouble() ?? 1.0,
        );
        break;
      case 'overlay_watermark':
        args = CommandBuilder.overlayWatermark(
          inputPath,
          params['image_path'] as String,
          params['position'] as String? ?? 'bottom-right',
          (params['opacity'] as num?)?.toDouble() ?? 0.7,
        );
        break;
      default:
        args = ['-i', inputPath, '-c', 'copy'];
    }

    final ext = op.type == 'extract_audio'
        ? '.${params['output_format'] as String? ?? 'mp3'}'
        : op.type == 'generate_thumbnail'
            ? '.jpg'
            : '.mp4';

    return FfmpegJob(
      id: op.id,
      args: args,
      expectedDurationMs: 0,
      inputPath: inputPath,
      outputPath: '${inputPath}_${op.id}$ext',
    );
  }
}
