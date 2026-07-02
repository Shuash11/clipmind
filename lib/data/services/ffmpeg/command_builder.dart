class CommandBuilder {
  static List<String> trim(String input, String start, String end) {
    return ['-i', input, '-ss', start, '-to', end, '-c', 'copy'];
  }

  static List<String> cut(
      String input, String removeStart, String removeEnd) {
    return [
      '-i', input,
      '-vf',
      "select='not(between(t,$removeStart,$removeEnd))',"
          'setpts=N/FRAME_RATE/TB',
      '-af',
      "aselect='not(between(t,$removeStart,$removeEnd))',"
          'asetpts=N/SR/TB',
    ];
  }

  static List<String> merge(List<String> inputs) {
    final args = <String>[];
    for (final input in inputs) {
      args.addAll(['-i', input]);
    }
    final n = inputs.length;
    final streamSpecs = List.generate(n, (i) => '[$i:v:0][$i:a:0]').join();
    args.addAll([
      '-filter_complex',
      '${streamSpecs}concat=n=$n:v=1:a=1[outv][outa]',
      '-map', '[outv]',
      '-map', '[outa]',
    ]);
    return args;
  }

  static List<String> changeSpeed(String input, double factor) {
    final audioFilters = <String>[];
    var remaining = factor;
    while (remaining > 2.0) {
      audioFilters.add('atempo=2.0');
      remaining /= 2.0;
    }
    while (remaining < 0.5) {
      audioFilters.add('atempo=0.5');
      remaining /= 0.5;
    }
    audioFilters.add('atempo=$remaining');
    final audioFilterStr = audioFilters.join(',');

    return [
      '-i', input,
      '-filter_complex',
      '[0:v]setpts=PTS/$factor[vout];[0:a]$audioFilterStr[aout]',
      '-map', '[vout]',
      '-map', '[aout]',
    ];
  }

  static List<String> mute(String input) {
    return ['-i', input, '-an', '-c:v', 'copy'];
  }

  static List<String> overlayText(
    String input, {
    required String text,
    required String position,
    required String start,
    required String end,
    int fontSize = 48,
    String color = '#FFFFFF',
  }) {
    final escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll(':', '\\:');

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

    final enable = (start != '0' || end != '0')
        ? ":enable='between(t,$start,$end)'"
        : '';

    return [
      '-i', input,
      '-vf',
      "drawtext=text='$escaped':"
          'fontsize=$fontSize:'
          'fontcolor=$color:'
          'x=$x:'
          'y=$y'
          '$enable',
    ];
  }

  static List<String> resize(
      String input, int width, int height, String fit) {
    String scaleFilter;
    switch (fit) {
      case 'fill':
        scaleFilter =
            'scale=$width:$height:force_original_aspect_ratio=1,crop=$width:$height';
        break;
      case 'fit':
        scaleFilter =
            'scale=$width:$height:force_original_aspect_ratio=1,'
                'pad=$width:$height:(ow-iw)/2:(oh-ih)/2';
        break;
      case 'stretch':
        scaleFilter = 'scale=$width:$height';
        break;
      default:
        scaleFilter = 'scale=$width:$height:force_original_aspect_ratio=1';
    }
    return ['-i', input, '-vf', scaleFilter];
  }

  static List<String> rotate(String input, double degrees) {
    if (degrees == 90) return ['-i', input, '-vf', 'transpose=1'];
    if (degrees == 180) {
      return ['-i', input, '-vf', 'transpose=1,transpose=1'];
    }
    if (degrees == 270) return ['-i', input, '-vf', 'transpose=2'];
    return ['-i', input, '-vf', 'rotate=$degrees*PI/180'];
  }

  static List<String> extractAudio(String input, String outputFormat) {
    final codec = switch (outputFormat) {
      'mp3' => 'libmp3lame',
      'aac' => 'aac',
      'wav' => 'pcm_s16le',
      'ogg' => 'libvorbis',
      'flac' => 'flac',
      _ => 'libmp3lame',
    };
    return ['-i', input, '-vn', '-c:a', codec];
  }

  static List<String> generateThumbnail(String input, String timestamp) {
    return ['-ss', timestamp, '-i', input, '-vframes', '1', '-q:v', '2'];
  }

  static List<String> changeFormat(
      String input, String targetExt, String? codecPreset) {
    final (videoCodec, audioCodec) = switch (targetExt) {
      'mp4' => ('libx264', 'aac'),
      'webm' => ('libvpx-vp9', 'libopus'),
      'mov' => ('libx264', 'aac'),
      'gif' => ('gif', ''),
      'avi' => ('libxvid', 'mp3'),
      _ => (codecPreset ?? 'libx264', 'aac'),
    };
    final args = ['-i', input, '-c:v', videoCodec];
    if (audioCodec.isNotEmpty) {
      args.addAll(['-c:a', audioCodec]);
    }
    return args;
  }

  static List<String> adjustBrightness(String input, double value) {
    final clamped = value.clamp(-1.0, 1.0);
    return ['-i', input, '-vf', 'eq=brightness=$clamped'];
  }

  static List<String> changeVolume(String input, double factor) {
    return ['-i', input, '-af', 'volume=$factor'];
  }

  static List<String> overlayWatermark(
    String input,
    String watermarkPath,
    String position,
    double opacity,
  ) {
    final clampedOpacity = opacity.clamp(0.0, 1.0);
    String overlayPos;
    switch (position) {
      case 'top-left':
        overlayPos = '10:10';
        break;
      case 'top-right':
        overlayPos = 'W-w-10:10';
        break;
      case 'bottom-left':
        overlayPos = '10:H-h-10';
        break;
      case 'center':
        overlayPos = '(W-w)/2:(H-h)/2';
        break;
      default:
        overlayPos = 'W-w-10:H-h-10';
    }

    return [
      '-i', input,
      '-i', watermarkPath,
      '-filter_complex',
      '[1:v]format=rgba,colorchannelmixer=aa=$clampedOpacity[wm];'
          '[0:v][wm]overlay=$overlayPos[outv]',
      '-map', '[outv]',
      '-map', '0:a',
    ];
  }
}
