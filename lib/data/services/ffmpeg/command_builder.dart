import 'dart:math' as math;

import 'package:clipmind/core/utils/timecode_utils.dart';

import 'filter_escaping.dart';

class CommandBuilder {
  static List<String> trim(String input, String start, String end) {
    return ['-i', input, '-ss', start, '-to', end, '-c', 'copy'];
  }

  /// Cut out `[removeStart, removeEnd]` via `select`/`aselect`.
  ///
  /// Ranged-cut fix: when the clip's range is known, pass [clipStartSec]
  /// (the clip's in-point in seconds) and [clipDurationSec] (the clip span
  /// in seconds). The input is then restricted with input-seeking
  /// `-ss clipStartSec -i input -t clipDurationSec` and the remove times
  /// are shifted (`remove − clipStartSec`) inside `between()`, so the
  /// output length is `clipLen − removedLen` — exactly the propagated
  /// `_cutNewRange` new range — for every clip state. When the range is
  /// unknown both stay null and the legacy whole-file path runs unchanged.
  /// `-t` (duration) is used instead of `-to` to avoid the input-seek
  /// origin ambiguity. Audio-less inputs still fail on `-af aselect`
  /// exactly as before.
  static List<String> cut(
    String input,
    String removeStart,
    String removeEnd, {
    double? clipStartSec,
    double? clipDurationSec,
  }) {
    if (clipStartSec != null && clipDurationSec != null) {
      final shiftedStart = shiftedCutTime(removeStart, clipStartSec);
      final shiftedEnd = shiftedCutTime(removeEnd, clipStartSec);
      return [
        '-ss',
        clipStartSec.toString(),
        '-i',
        input,
        '-t',
        clipDurationSec.toString(),
        '-vf',
        "select='not(between(t,$shiftedStart,$shiftedEnd))',"
            'setpts=N/FRAME_RATE/TB',
        '-af',
        "aselect='not(between(t,$shiftedStart,$shiftedEnd))',"
            'asetpts=N/SR/TB',
      ];
    }
    return [
      '-i',
      input,
      '-vf',
      "select='not(between(t,$removeStart,$removeEnd))',"
          'setpts=N/FRAME_RATE/TB',
      '-af',
      "aselect='not(between(t,$removeStart,$removeEnd))',"
          'asetpts=N/SR/TB',
    ];
  }

  /// Shift a `cut` remove time from file time to clip-span-relative time.
  ///
  /// `removeTime` accepts both `HH:MM:SS.mmm` timecodes (the AI path) and
  /// plain decimal seconds (the manual path, e.g. `15.000`). The result is
  /// rounded to the millisecond so binary float noise never leaks into the
  /// filter. Unparseable inputs fall back to the original string.
  static String shiftedCutTime(String removeTime, double clipStartSec) {
    final seconds = _cutTimeToSeconds(removeTime);
    if (seconds == null) return removeTime;
    final shiftedMs = ((seconds - clipStartSec) * 1000).round();
    return (shiftedMs / 1000).toString();
  }

  /// Parse a `cut` time to seconds (timecode or plain seconds).
  static double? _cutTimeToSeconds(String time) {
    final trimmed = time.trim();
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null) return asDouble;
    final ms = TimecodeUtils.parseToMilliseconds(trimmed);
    if (ms != null) return ms / 1000.0;
    return null;
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
      '-map',
      '[outv]',
      '-map',
      '[outa]',
    ]);
    return args;
  }

  /// Re-time a clip by [factor] via `setpts` + an `atempo` chain.
  ///
  /// Ranged-input restriction (same shape as [cut]): when the clip's range
  /// is known, pass [clipStartSec] (the clip's in-point in seconds) and
  /// [clipDurationSec] (the clip span in seconds). The input is then
  /// restricted with input-seeking `-ss clipStartSec -i input -t
  /// clipDurationSec` and the `setpts`/`atempo` filters apply after the
  /// restriction — no time shifting is needed (correct by construction).
  /// When the range is unknown both stay null and the legacy whole-file
  /// path runs byte-identical.
  static List<String> changeSpeed(
    String input,
    double factor, {
    double? clipStartSec,
    double? clipDurationSec,
  }) {
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

    final filterArgs = <String>[
      '-filter_complex',
      '[0:v]setpts=PTS/$factor[vout];[0:a]$audioFilterStr[aout]',
      '-map',
      '[vout]',
      '-map',
      '[aout]',
    ];
    if (clipStartSec != null && clipDurationSec != null) {
      return [
        '-ss',
        clipStartSec.toString(),
        '-i',
        input,
        '-t',
        clipDurationSec.toString(),
        ...filterArgs,
      ];
    }
    return ['-i', input, ...filterArgs];
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
    String? fontFile,
  }) {
    final escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll(':', '\\:')
        .replaceAll('%', '\\%');

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

    // `fontFile` is app-resolved (bundled-font extraction path) — never
    // model-provided (the srt_path pattern).
    final fontPart = (fontFile != null && fontFile.isNotEmpty)
        ? ':fontfile=${FilterEscaping.escapeFontFilePath(fontFile)}'
        : '';

    return [
      '-i',
      input,
      '-vf',
      "drawtext=text='$escaped':"
          'fontsize=$fontSize:'
          'fontcolor=$color:'
          'x=$x:'
          'y=$y'
          '$fontPart'
          '$enable',
    ];
  }

  static List<String> resize(String input, int width, int height, String fit) {
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

  /// Burn an SRT file into the video via the libass `subtitles` filter.
  ///
  /// [assColor] is an ASS `&H00BBGGRR` color (see
  /// [FilterEscaping.assColorFromHex]); [alignment] is an ASS Style
  /// `Alignment` in legacy `\a` numbering (6 = top-center,
  /// 10 = middle-center, 2 = bottom-center, null = bottom default).
  /// `force_style` carries only non-default keys and is omitted entirely
  /// when everything is default.
  ///
  /// Live-verified 2026-10-01 on FFmpeg 8.1.1-essentials (+libass):
  /// `force_style='Alignment=N'` follows legacy `\a` semantics, NOT the
  /// modern `\an` numpad — numpad 8 rendered middle-center while legacy 6
  /// rendered top-center (luminance-probed top/bottom thirds).
  static List<String> burnCaptions(
    String input,
    String srtPath, {
    int fontSize = 24,
    String? assColor,
    int? alignment,
  }) {
    return [
      '-i',
      input,
      '-vf',
      burnCaptionsFilter(
        srtPath,
        fontSize: fontSize,
        assColor: assColor,
        alignment: alignment,
      ),
    ];
  }

  /// The `subtitles` filter string alone (shared with the composed
  /// filter-graph path).
  static String burnCaptionsFilter(
    String srtPath, {
    int fontSize = 24,
    String? assColor,
    int? alignment,
  }) {
    final escaped = FilterEscaping.escapeSubtitlePath(srtPath);
    final styles = <String>[];
    if (fontSize != 24) styles.add('FontSize=$fontSize');
    if (assColor != null && assColor.isNotEmpty) {
      styles.add('PrimaryColour=$assColor');
    }
    if (alignment != null) styles.add('Alignment=$alignment');
    var filter = "subtitles=filename='$escaped'";
    if (styles.isNotEmpty) {
      filter += ":force_style='${styles.join(',')}'";
    }
    return filter;
  }

  /// Cross-fade two clips into one output via `xfade` + `acrossfade`.
  ///
  /// [offset] is the fade start relative to the FIRST input in seconds
  /// (for an end-of-first-clip transition: `max(0, dur_first - duration)`).
  /// [duration] is clamped to the doc-verified 0–60s range (default 0.5).
  /// When neither input [hasAudio], the audio crossfade is skipped and the
  /// output maps video only (`-an`).
  ///
  /// Live-verified 2026-10-01 on FFmpeg 8.1.1: the 44100+44100 pair exits
  /// 0, and the mismatched 44100+48000 pair ALSO exits 0 — `acrossfade`
  /// auto-resamples to the first input's rate, so no pre-resample is
  /// needed. Both inputs must still share resolution/pixel-format/frame
  /// rate/timebase (the executor enforces resolution+fps via ffprobe).
  static List<String> transition(
    String firstPath,
    String secondPath, {
    String transition = 'fade',
    double duration = 0.5,
    double offset = 0,
    String audioMode = 'crossfade',
  }) {
    final d = duration.clamp(0.0, 60.0);
    final o = offset < 0 ? 0.0 : offset;
    final video =
        '[0:v][1:v]xfade=transition=$transition:duration=$d:offset=$o[outv]';
    // Asymmetric audio is live-verified on FFmpeg 8.1.1: one-sided inputs
    // must map the bearing track directly — `[0:a][1:a]acrossfade` with
    // one audio-less input fails the whole graph (exit −22).
    final graph = audioMode == 'crossfade'
        ? '$video;[0:a][1:a]acrossfade=d=$d[outa]'
        : video;
    final args = [
      '-i',
      firstPath,
      '-i',
      secondPath,
      '-filter_complex',
      graph,
      '-map',
      '[outv]',
    ];
    switch (audioMode) {
      case 'crossfade':
        args.addAll(['-map', '[outa]']);
        break;
      case 'first':
        args.addAll(['-map', '0:a']);
        break;
      case 'second':
        args.addAll(['-map', '1:a']);
        break;
      default:
        args.add('-an');
        break;
    }
    return args;
  }

  /// Creative look filter for one clip (shared with the composed path).
  ///
  /// - `vignette`: strength 0–1 → lens angle 0–PI/2 radians; 0.4 ≡ the
  ///   FFmpeg default PI/5. There is no 0–1 "strength" param in the
  ///   filter — this mapping is app-side.
  /// - `blur`: strength 0–1 → `gblur` sigma 0–20 (app-chosen cap).
  /// - `grayscale`: `eq=saturation=0` (no standalone `grayscale` filter
  ///   exists in the FFmpeg docs).
  /// - `contrast` / `saturation`: `eq` multipliers clamped to 0–3.
  ///
  /// All mappings live-verified 2026-09-28 on FFmpeg 8.1.1 (exit 0).
  /// Live-verified 2026-10-01: the full cap `gblur=sigma=20.0`
  /// (strength 1.0) renders exit 0 — gblur documents no upper cap, so the
  /// 20 cap stays a compute-cost choice, not a validity limit. Unknown
  /// effects yield the `null` passthrough.
  static String effectFilter({
    required String effect,
    double? strength,
    double? contrast,
    double? saturation,
  }) {
    switch (effect) {
      case 'vignette':
        final s = (strength ?? 0.4).clamp(0.0, 1.0);
        return 'vignette=angle=${s * math.pi / 2}';
      case 'blur':
        final s = (strength ?? 0.3).clamp(0.0, 1.0);
        return 'gblur=sigma=${s * 20}';
      case 'grayscale':
        return 'eq=saturation=0';
      case 'contrast':
        return 'eq=contrast=${(contrast ?? 1.0).clamp(0.0, 3.0)}';
      case 'saturation':
        return 'eq=saturation=${(saturation ?? 1.0).clamp(0.0, 3.0)}';
      default:
        return 'null';
    }
  }

  /// Single-op job for [effectFilter].
  static List<String> effect(
    String input, {
    required String effect,
    double? strength,
    double? contrast,
    double? saturation,
  }) =>
      [
        '-i',
        input,
        '-vf',
        effectFilter(
          effect: effect,
          strength: strength,
          contrast: contrast,
          saturation: saturation,
        ),
      ];

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
    String input,
    String targetExt,
    String? codecPreset,
  ) {
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

  /// Maps a watermark position name to an FFmpeg overlay expression.
  ///
  /// Pure helper shared by [overlayWatermark] and the composed
  /// filter-graph path. Unknown names fall back to bottom-right.
  static String overlayPosition(String position) {
    switch (position) {
      case 'top-left':
        return '10:10';
      case 'top-right':
        return 'W-w-10:10';
      case 'bottom-left':
        return '10:H-h-10';
      case 'center':
        return '(W-w)/2:(H-h)/2';
      default:
        return 'W-w-10:H-h-10';
    }
  }

  static List<String> overlayWatermark(
    String input,
    String watermarkPath,
    String position,
    double opacity,
  ) {
    final clampedOpacity = opacity.clamp(0.0, 1.0);
    final overlayPos = overlayPosition(position);

    return [
      '-i',
      input,
      '-i',
      watermarkPath,
      '-filter_complex',
      '[1:v]format=rgba,colorchannelmixer=aa=$clampedOpacity[wm];'
          '[0:v][wm]overlay=$overlayPos[outv]',
      '-map',
      '[outv]',
      '-map',
      '0:a',
    ];
  }

  /// Layer a sound file over a clip's audio (`addSound` op).
  ///
  /// [soundPath] is app-generated (procedural temp wav or a bundled asset)
  /// — never model-provided (the srt_path pattern). [volume] scales the
  /// sound leg only via `volume=<v>` on the sound input chain.
  ///
  /// One-sided nuance (same rule as the `transition` acrossfade path,
  /// live-verified in Cycle 3): `amix` requires BOTH inputs to carry audio.
  /// When the clip has audio ([hasClipAudio]) the legs mix with
  /// `amix=inputs=2:duration=first:dropout_transition=2`; otherwise the
  /// sound becomes the ONLY audio track (`-map 1:a`, no amix graph).
  static List<String> addAudio(
    String clipPath,
    String soundPath, {
    double volume = 1.0,
    bool hasClipAudio = true,
  }) {
    if (hasClipAudio) {
      if (volume == 1.0) {
        return [
          '-i',
          clipPath,
          '-i',
          soundPath,
          '-filter_complex',
          '[0:a][1:a]amix=inputs=2:duration=first:dropout_transition=2[aout]',
          '-map',
          '0:v',
          '-map',
          '[aout]',
        ];
      }
      return [
        '-i',
        clipPath,
        '-i',
        soundPath,
        '-filter_complex',
        '[1:a]volume=$volume[snd];'
            '[0:a][snd]amix=inputs=2:duration=first:dropout_transition=2[aout]',
        '-map',
        '0:v',
        '-map',
        '[aout]',
      ];
    }
    if (volume == 1.0) {
      return ['-i', clipPath, '-i', soundPath, '-map', '0:v', '-map', '1:a'];
    }
    return [
      '-i',
      clipPath,
      '-i',
      soundPath,
      '-filter_complex',
      '[1:a]volume=$volume[aout]',
      '-map',
      '0:v',
      '-map',
      '[aout]',
    ];
  }

  /// Lavfi source string for a procedural sound preset id, or null when
  /// unknown. Pure mapping (mirrors [effectFilter]); the
  /// [ProceduralSoundService] executes it via [lavfiToWav].
  ///
  /// The 6 presets follow the verified mcp-video pattern (no external
  /// files): `sine` tones and `anoisesrc` noise. The chime layers two
  /// sine tones (880 + 1320 Hz) via `aevalsrc` — a single lavfi source so
  /// generation stays a one-input job.
  static String? proceduralSoundSource(String presetId) {
    return switch (presetId) {
      'beep' => 'sine=frequency=880:duration=0.3',
      'drone-low' => 'sine=frequency=80:duration=10',
      'drone-mid' => 'sine=frequency=180:duration=10',
      'hum' => 'sine=frequency=60:duration=10',
      'static-noise' => 'anoisesrc=duration=10',
      'alert-chime' =>
        'aevalsrc=0.5*sin(2*PI*880*t)+0.5*sin(2*PI*1320*t):s=44100:d=0.6',
      _ => null,
    };
  }

  /// Args turning a lavfi [source] (see [proceduralSoundSource]) into a
  /// wav file. The caller appends `-y <outputPath>`.
  static List<String> lavfiToWav(String source) {
    return ['-f', 'lavfi', '-i', source, '-c:a', 'pcm_s16le'];
  }
}
