import 'dart:io';
import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/filter_escaping.dart';
import 'operation_schema.dart';

/// Thrown when a clip ID cannot be resolved to a real file path or when
/// an LLM-provided filter value is rejected.
class CommandMappingException implements Exception {
  final String message;
  const CommandMappingException(this.message);

  @override
  String toString() => message;
}

class CommandMapper {
  static const _composableTypes = {
    'trim', 'cut', 'change_speed', 'mute', 'overlay_text',
    'resize', 'rotate', 'adjust_brightness', 'change_volume',
    'overlay_watermark', 'apply_effect',
  };

  static const _singlePassTypes = {
    'extract_audio', 'generate_thumbnail', 'change_format', 'merge',
    'add_transition', 'add_sound',
  };

  /// Manual structural ops: local transforms via the structural applier,
  /// never FFmpeg jobs and never model tools. Skipped defensively here —
  /// without this they would fall into `_buildSingleJob`'s copy default.
  static const _structuralTypes = {
    'delete_clip',
    'copy_clip',
    'move_clip',
    'trim_clip',
    'split_clip',
  };

  /// Map an LLM operation set to FFmpeg jobs using real file paths.
  ///
  /// [clipPathMap] maps clip ID -> absolute source file path.
  /// [outputDir] is the project output directory; when empty the input
  /// file's parent directory is used. [defaultPath] is the fallback input
  /// for `_default` targets. [projectDir] scopes watermark validation.
  ///
  /// Ranged-input restriction (first ranged op wins, any composable type):
  /// per clip group the FIRST op carrying `clip_start_s`/`clip_len_s`
  /// fixes the job's input window (`-ss`/`-t`); cut ops additionally
  /// shift their `between()` times to that window while non-cut ops
  /// (setpts/atempo apply after the restriction) need no shift — correct
  /// by construction. Groups with no ranged op run the legacy whole-file
  /// path unchanged.
  ///
  /// [sourceHasAudio] is the caller-probed audio presence of the composed
  /// source (ffprobe `hasAudio`, the transition-path probe convention):
  /// `false` emits `-an` instead of `-map 0:a` so silent sources (screen
  /// recordings) no longer hard-fail with "Stream map '0:a' matches no
  /// streams". Null (probing unavailable) → the legacy `-map 0:a`
  /// fallback, unchanged behavior. Mute ops emit `-an` regardless.
  static List<FfmpegJob> mapOperations(
    EditOperationSet operationSet,
    Map<String, String> clipPathMap,
    String outputDir, {
    String? defaultPath,
    String? projectDir,
    bool? sourceHasAudio,
  }) {
    final jobs = <FfmpegJob>[];
    final effectiveDefault = defaultPath ??
        clipPathMap['_default'] ??
        (clipPathMap.values.isNotEmpty ? clipPathMap.values.first : null);
    if (effectiveDefault == null) {
      throw const CommandMappingException('No video file in project');
    }

    String resolve(String? clipId) {
      if (clipId == null || clipId == '_default') return effectiveDefault;
      final path = clipPathMap[clipId];
      if (path == null || path.isEmpty) {
        throw CommandMappingException(
          'Unknown clip "$clipId": no source file in project.',
        );
      }
      return path;
    }

    final byClip = <String, List<EditOperationRequest>>{};
    final standaloneOps = <EditOperationRequest>[];

    for (final op in operationSet.operations) {
      if (_structuralTypes.contains(op.type)) {
        continue;
      } else if (_singlePassTypes.contains(op.type) || op.type == 'merge') {
        standaloneOps.add(op);
      } else {
        final clipId = op.targetClipId?.toString() ?? '_default';
        byClip.putIfAbsent(clipId, () => []).add(op);
      }
    }

    for (final entry in byClip.entries) {
      final ops = entry.value;
      if (ops.isEmpty) continue;
      final inputPath = resolve(entry.key);

      // Walk-order detection: the first op carrying the range wins for
      // the whole group, regardless of op type.
      final restriction = _firstRangedRestriction(ops);
      final rangedStart = restriction?.$1;
      final rangedLen = restriction?.$2;

      final composable =
          ops.where((o) => _composableTypes.contains(o.type)).toList();
      if (composable.length >= 2) {
        jobs.addAll(
          _composeMultiOp(composable, inputPath, outputDir,
              projectDir: projectDir,
              rangedStart: rangedStart,
              rangedLen: rangedLen,
              sourceHasAudio: sourceHasAudio),
        );
      } else {
        for (final op in ops) {
          jobs.add(_buildSingleJob(op, resolve(_clipIdOf(op)), outputDir,
              projectDir: projectDir,
              rangedStart: rangedStart,
              rangedLen: rangedLen));
        }
      }
    }

    for (final op in standaloneOps) {
      if (op.type == 'merge') {
        jobs.add(_buildMergeJob(op, clipPathMap, outputDir));
      } else if (op.type == 'add_transition') {
        jobs.add(_buildTransitionJob(op, clipPathMap, outputDir));
      } else {
        jobs.add(_buildSingleJob(op, resolve(_clipIdOf(op)), outputDir,
            projectDir: projectDir));
      }
    }

    return jobs;
  }

  static String? _clipIdOf(EditOperationRequest op) {
    return op.targetClipId?.toString();
  }

  /// [sourceHasAudio] threads straight through to [_composeFilterGraph]
  /// (the composed filter-graph job); the watermark+text/mute split path
  /// maps each op singly, so the flag does not apply there.
  static List<FfmpegJob> _composeMultiOp(
    List<EditOperationRequest> ops,
    String inputPath,
    String outputDir, {
    String? projectDir,
    double? rangedStart,
    double? rangedLen,
    bool? sourceHasAudio,
  }) {
    final hasOverlayWatermark = ops.any((o) => o.type == 'overlay_watermark');
    final hasMute = ops.any((o) => o.type == 'mute');
    final hasOverlayText = ops.any((o) => o.type == 'overlay_text');

    if (hasOverlayWatermark && (hasOverlayText || hasMute)) {
      return ops
          .map((o) => _buildSingleJob(o, inputPath, outputDir,
              projectDir: projectDir,
              rangedStart: rangedStart,
              rangedLen: rangedLen))
          .toList();
    }

    return [
      _composeFilterGraph(ops, inputPath, outputDir,
          projectDir: projectDir,
          rangedStart: rangedStart,
          rangedLen: rangedLen,
          sourceHasAudio: sourceHasAudio)
    ];
  }

  /// Compose one filter-graph job from same-clip ops.
  ///
  /// [rangedStart]/[rangedLen] is the walk-order first-wins restriction
  /// pre-detected by [mapOperations] (any composable type may carry it):
  /// the whole composed input is restricted with `-ss`/`-t`, cut ops
  /// additionally shift their `between()` times to that window, and
  /// non-cut carriers ignore the shift. Both null → legacy whole-file.
  ///
  /// Watermark inputs: each unique `overlay_watermark` image becomes an
  /// extra `-i` input at index 1..N (the main input stays index 0;
  /// repeated paths reuse one index). The image leg is pre-chained as
  /// `[N:v]format=rgba,colorchannelmixer=aa=<opacity>[wmN]` and composited
  /// with `[$prev][wmN]overlay=<pos>[$next]`; the audio map is unaffected.
  /// Single-frame PNGs are safe: framesync `eof_action` defaults to
  /// `repeat`, so the still holds for the whole output.
  ///
  /// [sourceHasAudio] is the caller-probed audio presence of [inputPath]
  /// (ffprobe `hasAudio`, the transition-path probe convention): `false`
  /// emits `-an` instead of `-map 0:a` so silent sources (screen
  /// recordings) no longer hard-fail with "Stream map '0:a' matches no
  /// streams". Null (probing unavailable) → the legacy `-map 0:a`
  /// fallback, unchanged behavior. Mute ops emit `-an` regardless.
  static FfmpegJob _composeFilterGraph(
    List<EditOperationRequest> ops,
    String inputPath,
    String outputDir, {
    String? projectDir,
    double? rangedStart,
    double? rangedLen,
    bool? sourceHasAudio,
  }) {
    final filters = <String>[];
    // Flat audio fragments in op order, chained once as
    // `[0:a]f1,f2,…[aout]` (mirrors the video side's op-order chain and
    // the FilterGraphComposer `[0:a]$aChain[aout]` convention).
    final audioFragments = <String>[];
    // Unique watermark image paths in op order (deduped so a repeated
    // image reuses one `-i` index) plus their pre-chained image legs.
    final extraInputs = <String>[];
    final wmChains = <String>[];
    // True only when a mute op drops the audio side (never a statement
    // about the source file — probe that via [sourceHasAudio]).
    bool mutedByOp = false;
    // Hoisted first-wins window (both-or-neither): the input restriction
    // applies to the whole composed graph; only cut ops shift times.
    final double? rangedClipStart =
        (rangedStart != null && rangedLen != null) ? rangedStart : null;
    final double? rangedClipLen =
        (rangedStart != null && rangedLen != null) ? rangedLen : null;

    filters.add('[0:v]null[v0]');

    for (int i = 0; i < ops.length; i++) {
      final op = ops[i];
      final params = op.params;
      final prev = 'v$i';
      final next = 'v${i + 1}';

      switch (op.type) {
        case 'trim':
          final start = _str(params, 'start', '0');
          final end = params.containsKey('end') && params['end'] != null
              ? _str(params, 'end', '')
              : null;
          if (end != null && end.isNotEmpty) {
            filters.add('[$prev]trim=$start:$end,setpts=PTS-STARTPTS[$next]');
            audioFragments.add('atrim=$start:$end,asetpts=PTS-STARTPTS');
          } else {
            filters.add('[$prev]trim=$start,setpts=PTS-STARTPTS[$next]');
            audioFragments.add('atrim=$start,asetpts=PTS-STARTPTS');
          }
          break;

        case 'change_speed':
          final factor = _num(params, 'factor', 1.0);
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
          audioFragments.add(atempoParts.join(','));
          break;

        case 'resize':
          final w = _int(params, 'width', 1920);
          final h = _int(params, 'height', 1080);
          filters.add(
            '[$prev]scale=$w:$h:force_original_aspect_ratio=1,crop=$w:$h[$next]',
          );
          break;

        case 'rotate':
          final degrees = _num(params, 'degrees', 0);
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
          final value = _num(params, 'value', 0.0).clamp(-1.0, 1.0);
          filters.add(
            '[$prev]eq=brightness=$value[$next]',
          );
          break;

      case 'apply_effect':
        filters.add(
          '[$prev]${CommandBuilder.effectFilter(
            effect: _str(params, 'effect', ''),
            strength: _numOrNull(params, 'strength'),
            contrast: _numOrNull(params, 'contrast'),
            saturation: _numOrNull(params, 'saturation'),
          )}[$next]',
        );
        break;

      case 'overlay_text':
        final rawText = _str(params, 'text', '');
          final text = FilterEscaping.escapeDrawtext(rawText);
          final pos = _str(params, 'position', 'center');
          final fs = _int(params, 'font_size', 48);
          final color = _validatedColor(_str(params, 'color', '#FFFFFF'));
          final start = _str(params, 'start', '0');
          final end = _str(params, 'end', '0');
          final x = pos == 'center' ? '(w-text_w)/2' : '10';
          final y = pos == 'center' ? '(h-text_h)/2' : '10';
          final fontFileRaw = params['font_file']?.toString() ?? '';
          if (fontFileRaw.contains('..')) {
            throw CommandMappingException(
              'Operation "${op.id}": invalid font_file '
              '(path traversal is not allowed).',
            );
          }
          // Interpolated unquoted, so `escapeFontFilePath` emits the
          // two-level escaped form.
          final fontPart = fontFileRaw.isNotEmpty
              ? ':fontfile=${FilterEscaping.escapeFontFilePath(fontFileRaw)}'
              : '';
          final enable = (start == '0' && end == '0')
              ? ''
              : ":enable='between(t,$start,$end)'";
          filters.add(
            '[$prev]drawtext=text=\'$text\':fontsize=$fs:fontcolor=$color:x=$x:y=$y$fontPart$enable[$next]',
          );
          break;

        case 'change_volume':
          final factor = _num(params, 'factor', 1.0);
          // Audio-only op: keep the v-chain continuous with a passthrough
          // so the next video op's [$prev] input label stays defined
          // (mirrors the `[0:v]null[v0]` convention above).
          filters.add('[$prev]null[$next]');
          audioFragments.add('volume=$factor');
          break;

        case 'mute':
          // Audio-only op (same passthrough rule as change_volume); the
          // audio side is dropped via `-an`, so no fragment is recorded.
          filters.add('[$prev]null[$next]');
          mutedByOp = true;
          break;

        case 'cut':
          final removeStart = _str(params, 'remove_start', '0');
          final removeEnd = _str(params, 'remove_end', '0');
          if (rangedClipStart != null && rangedClipLen != null) {
            // Shift to the hoisted first-wins window (same composition
            // as CommandBuilder.cut): file times minus the window start.
            final shiftedStart =
                CommandBuilder.shiftedCutTime(removeStart, rangedClipStart);
            final shiftedEnd =
                CommandBuilder.shiftedCutTime(removeEnd, rangedClipStart);
            filters.add(
              '[$prev]select=\'not(between(t,$shiftedStart,$shiftedEnd))\',setpts=N/FRAME_RATE/TB[$next]',
            );
            audioFragments.add(
              'aselect=\'not(between(t,$shiftedStart,$shiftedEnd))\',asetpts=N/SR/TB',
            );
          } else {
            filters.add(
              '[$prev]select=\'not(between(t,$removeStart,$removeEnd))\',setpts=N/FRAME_RATE/TB[$next]',
            );
            audioFragments.add(
              'aselect=\'not(between(t,$removeStart,$removeEnd))\',asetpts=N/SR/TB',
            );
          }
          break;

        case 'overlay_watermark':
          // Lexical validation only (no IO — the mapper stays pure),
          // exactly as `_buildSingleJob` does: empty, traversal, and
          // out-of-project absolute paths throw before any job is built.
          final imagePath = FilterEscaping.validateImagePath(
            _str(params, 'image_path', ''),
            projectDir: projectDir ?? _dirOf(outputDir),
          );
          final isNewImage = !extraInputs.contains(imagePath);
          if (isNewImage) extraInputs.add(imagePath);
          final n = extraInputs.indexOf(imagePath) + 1;
          final opacity = _num(params, 'opacity', 0.7).clamp(0.0, 1.0);
          if (isNewImage) {
            wmChains.add(
              '[$n:v]format=rgba,colorchannelmixer=aa=$opacity[wm$n]',
            );
          }
          final overlayPos = CommandBuilder.overlayPosition(
            _str(params, 'position', 'bottom-right'),
          );
          filters.add('[$prev][wm$n]overlay=$overlayPos[$next]');
          break;
        default:
          break;
      }
    }

    final lastVideoLabel = 'v${ops.length}';
    final videoStr = filters.join(';');
    // Image legs first, then the op-order v-chain (every [$prev] input
    // label stays defined, so `-map [vN]` below always resolves).
    final filterStr =
        wmChains.isEmpty ? videoStr : '${wmChains.join(';')};$videoStr';
    // One chained audio segment, mapped once and exactly once below.
    // Muted groups drop the audio side entirely (no dangling [aout]);
    // known-silent sources drop it too — chaining `[0:a]` fragments
    // (trim/cut/speed/volume all record them) would still reference a
    // stream that does not exist.
    final hasChainedAudio =
        !mutedByOp && sourceHasAudio != false && audioFragments.isNotEmpty;
    final audioStr =
        hasChainedAudio ? ';[0:a]${audioFragments.join(',')}[aout]' : '';

    final args = <String>[];
    if (rangedClipStart != null && rangedClipLen != null) {
      args.addAll(['-ss', rangedClipStart.toString(), '-i', inputPath]);
      for (final extra in extraInputs) {
        args.addAll(['-i', extra]);
      }
      args.addAll(['-t', rangedClipLen.toString()]);
    } else {
      args.addAll(['-i', inputPath]);
      for (final extra in extraInputs) {
        args.addAll(['-i', extra]);
      }
    }
    args.addAll([
      '-filter_complex',
      '$filterStr$audioStr',
      '-map',
      '[$lastVideoLabel]',
    ]);

    if (hasChainedAudio) {
      args.addAll(['-map', '[aout]']);
    } else if (mutedByOp || sourceHasAudio == false) {
      // Mute ops drop the audio side; audio-less sources (screen
      // recordings) map nothing instead of `-map 0:a`, which would
      // hard-fail with "Stream map '0:a' matches no streams". Null
      // (probing unavailable) keeps the legacy `-map 0:a` fallback.
      args.add('-an');
    } else {
      args.addAll(['-map', '0:a']);
    }

    // Intermediate output re-encoded again on final export: encode speed
    // beats compression (measured 25.5s vs 33.8s on a 60s 1080p source).
    args.addAll(['-preset', 'veryfast']);

    return FfmpegJob(
      id: ops.first.id,
      args: args,
      expectedDurationMs: 0,
      inputPath: inputPath,
      outputPath: _outputPathFor(outputDir, inputPath, '${ops.first.id}_composed', '.mp4'),
    );
  }

  /// Merge resolves clip IDs to real file paths (never passes IDs to FFmpeg).
  ///
  /// Audio-aware tri-state (the transition-path `audio_mode` convention):
  /// the executor stamps the ffprobe results as internal params
  /// (`inputs_have_audio` + `input_durations_s` — never model-provided)
  /// and they thread straight into [CommandBuilder.merge]. Absent flags
  /// → the legacy all-audio path, unchanged behavior. A silent leg with
  /// an unknown duration fails here naming the clip (fail-loud — the
  /// builder cannot pad without a duration, and guessing would desync
  /// A/V); [ArgumentError] from the builder converts to the same
  /// actionable failure.
  static FfmpegJob _buildMergeJob(
    EditOperationRequest op,
    Map<String, String> clipPathMap,
    String outputDir,
  ) {
    final raw = op.params['clip_ids'];
    if (raw is! List) {
      throw CommandMappingException(
        'Operation "${op.id}": merge requires clip_ids array.',
      );
    }
    final paths = <String>[];
    for (final item in raw) {
      final id = item.toString();
      final path = clipPathMap[id];
      if (path == null || path.isEmpty) {
        throw CommandMappingException(
          'Operation "${op.id}": unknown clip "$id" in merge list.',
        );
      }
      paths.add(path);
    }
    if (paths.length < 2) {
      throw CommandMappingException(
        'Operation "${op.id}": merge requires at least 2 clips.',
      );
    }
    final flags = _mergeAudioFlags(op.params['inputs_have_audio'], paths.length, op.id);
    final durations = _mergeDurations(op.params['input_durations_s'], paths.length, op.id);
    if (flags != null) {
      for (var i = 0; i < paths.length; i++) {
        if (!flags[i]) {
          final d = durations != null ? durations[i] : null;
          if (d == null || d <= 0) {
            throw CommandMappingException(
              'Operation "${op.id}": cannot merge — clip "${raw[i]}" '
              'has no audio track and its duration is unknown, so silence '
              'cannot be padded. Remove the silent clip from the merge '
              'list, or retry once its duration can be probed.',
            );
          }
        }
      }
    }
    List<String> args;
    try {
      args = CommandBuilder.merge(
        paths,
        inputsHaveAudio: flags,
        inputDurationsSec: durations,
      );
    } on ArgumentError catch (e) {
      throw CommandMappingException('Operation "${op.id}": ${e.message}');
    }
    return FfmpegJob(
      id: op.id,
      args: args,
      expectedDurationMs: 0,
      inputPath: paths.first,
      outputPath: _outputPathFor(outputDir, paths.first, '${op.id}_merged', '.mp4'),
    );
  }

  /// Internal per-input merge audio flags (stamped by the executor via
  /// ffprobe — never model-provided, the `audio_mode` convention):
  /// absent → null → the legacy all-audio path; present → must be [n]
  /// booleans or the op is rejected fail-loud (caller contract).
  static List<bool>? _mergeAudioFlags(Object? raw, int n, String opId) {
    if (raw == null) return null;
    if (raw is! List || raw.length != n || raw.any((e) => e is! bool)) {
      throw CommandMappingException(
        'Operation "$opId": internal inputs_have_audio is malformed '
        '(expected $n booleans).',
      );
    }
    return raw.cast<bool>();
  }

  /// Internal per-input merge durations in seconds (stamped alongside
  /// [inputs_have_audio]): absent → null; present → must be [n]
  /// numbers-or-null or the op is rejected fail-loud (caller contract).
  static List<double?>? _mergeDurations(Object? raw, int n, String opId) {
    if (raw == null) return null;
    if (raw is! List ||
        raw.length != n ||
        raw.any((e) => e != null && e is! num)) {
      throw CommandMappingException(
        'Operation "$opId": internal input_durations_s is malformed '
        '(expected $n numbers).',
      );
    }
    return [for (final e in raw) (e as num?)?.toDouble()];
  }

  /// Two-input cross-fade: resolves both clip IDs via the live path map
  /// (never passes IDs to FFmpeg). Style params were validated by the
  /// executor; safe fallbacks apply on replay.
  static FfmpegJob _buildTransitionJob(
    EditOperationRequest op,
    Map<String, String> clipPathMap,
    String outputDir,
  ) {
    final firstId = op.targetClipId?.toString() ?? '';
    final secondId = op.params['second_clip_id']?.toString() ?? '';
    final first = clipPathMap[firstId];
    if (first == null || first.isEmpty) {
      throw CommandMappingException(
        'Operation "${op.id}": unknown clip "$firstId" in transition pair.',
      );
    }
    final second = clipPathMap[secondId];
    if (second == null || second.isEmpty) {
      throw CommandMappingException(
        'Operation "${op.id}": unknown clip "$secondId" in transition pair.',
      );
    }
    // audio_mode with legacy has_audio fallback: pre-Phase-4 stored ops
    // carry {'has_audio': bool} and replay unchanged.
    final modeRaw = op.params['audio_mode'];
    final hasAudioRaw = op.params['has_audio'];
    final audioMode = modeRaw is String
        ? modeRaw
        : hasAudioRaw is bool
            ? (hasAudioRaw ? 'crossfade' : 'none')
            : 'crossfade';
    final args = CommandBuilder.transition(
      first,
      second,
      transition: _str(op.params, 'transition', 'fade'),
      duration: _num(op.params, 'duration', 0.5),
      offset: _num(op.params, 'offset', 0),
      audioMode: audioMode,
    );
    return FfmpegJob(
      id: op.id,
      args: args,
      expectedDurationMs: 0,
      inputPath: first,
      outputPath:
          _outputPathFor(outputDir, first, '${op.id}_transition', '.mp4'),
    );
  }

  /// Build one single-op job.
  ///
  /// [rangedStart]/[rangedLen] is the walk-order first-wins restriction
  /// pre-detected by [mapOperations]; when both are set they are passed
  /// through to the ranged-input builders ([CommandBuilder.cut],
  /// [CommandBuilder.changeSpeed]) and restrict the single-op
  /// `apply_effect`/`adjust_brightness` jobs to the clip extent
  /// (`-ss`/`-t`, the cut-path shape). Both null → each op falls back to
  /// its own params (single-op groups: identical to the hoisted pair).
  static FfmpegJob _buildSingleJob(
    EditOperationRequest op,
    String inputPath,
    String outputDir, {
    String? projectDir,
    double? rangedStart,
    double? rangedLen,
  }) {
    final params = op.params;
    final List<String> args;
    // Both-or-neither: a half-set hoisted pair defers to the op's own
    // params, exactly like an absent restriction.
    final hasHoistedRange = rangedStart != null && rangedLen != null;
    double? rangeStartOf(Map<String, dynamic> p) => hasHoistedRange
        ? rangedStart
        : _cutRangeParam(p, 'clip_start_s');
    double? rangeLenOf(Map<String, dynamic> p) => hasHoistedRange
        ? rangedLen
        : _cutRangeParam(p, 'clip_len_s');

    switch (op.type) {
      case 'trim':
        args = CommandBuilder.trim(
          inputPath,
          _str(params, 'start', '0'),
          _str(params, 'end', _str(params, 'start', '0')),
        );
        break;
      case 'cut':
        args = CommandBuilder.cut(
          inputPath,
          _str(params, 'remove_start', '0'),
          _str(params, 'remove_end', '0'),
          clipStartSec: rangeStartOf(params),
          clipDurationSec: rangeLenOf(params),
        );
        break;
      case 'change_speed':
        args = CommandBuilder.changeSpeed(
          inputPath,
          _num(params, 'factor', 1.0),
          clipStartSec: rangeStartOf(params),
          clipDurationSec: rangeLenOf(params),
        );
        break;
      case 'mute':
        args = CommandBuilder.mute(inputPath);
        break;
      case 'apply_effect': {
        final base = CommandBuilder.effect(
          inputPath,
          effect: _str(params, 'effect', ''),
          strength: _numOrNull(params, 'strength'),
          contrast: _numOrNull(params, 'contrast'),
          saturation: _numOrNull(params, 'saturation'),
        );
        // Range-restrict effect jobs to the clip extent (the cut-path
        // shape): without this the whole source file is re-encoded.
        final rs = rangeStartOf(params);
        final rl = rangeLenOf(params);
        args = (rs != null && rl != null)
            ? ['-ss', rs.toString(), '-i', inputPath, '-t', rl.toString(), ...base.sublist(2)]
            : base;
        break;
      }
      case 'overlay_text':
        // `font_file` is app-resolved (bundled-font extraction) — never
        // model-provided. Defense-in-depth: reject traversal even on this
        // internal param.
        final fontFileRaw = params['font_file']?.toString();
        final fontFile =
            (fontFileRaw != null && fontFileRaw.isNotEmpty) ? fontFileRaw : null;
        if (fontFile != null && fontFile.contains('..')) {
          throw CommandMappingException(
            'Operation "${op.id}": invalid font_file '
            '(path traversal is not allowed).',
          );
        }
        args = CommandBuilder.overlayText(
          inputPath,
          text: _str(params, 'text', ''),
          position: _str(params, 'position', 'center'),
          start: _str(params, 'start', '0'),
          end: _str(params, 'end', '0'),
          fontSize: _int(params, 'font_size', 48),
          color: _validatedColor(_str(params, 'color', '#FFFFFF')),
          fontFile: fontFile,
        );
        break;
      case 'add_sound':
        // The sound path is generated app-side (procedural temp wav or a
        // bundled asset) and passed as a param — never model-provided.
        // Defense-in-depth: reject traversal even on this internal param.
        final soundPath = _str(params, 'sound_path', '');
        if (soundPath.isEmpty || soundPath.contains('..')) {
          throw CommandMappingException(
            'Operation "${op.id}": invalid sound_path '
            '(path traversal is not allowed).',
          );
        }
        final hasClipAudio = params['has_clip_audio'] is bool
            ? params['has_clip_audio'] as bool
            : true;
        args = CommandBuilder.addAudio(
          inputPath,
          soundPath,
          volume: _num(params, 'volume', 1.0),
          hasClipAudio: hasClipAudio,
        );
        break;
      case 'resize':
        args = CommandBuilder.resize(
          inputPath,
          _int(params, 'width', 1920),
          _int(params, 'height', 1080),
          _str(params, 'fit', 'fill'),
        );
        break;
      case 'rotate':
        args = CommandBuilder.rotate(
          inputPath,
          _num(params, 'degrees', 0),
        );
        break;
      case 'extract_audio':
        args = CommandBuilder.extractAudio(
          inputPath,
          _str(params, 'output_format', 'mp3'),
        );
        break;
      case 'burn_captions':
        // The SRT path is generated app-side by the executor from the
        // cached transcript and passed as a param — never model-provided.
        // Defense-in-depth: reject traversal even on this internal param.
        final srtPath = _str(params, 'srt_path', '');
        if (srtPath.contains('..')) {
          throw CommandMappingException(
            'Operation "${op.id}": invalid srt_path '
            '(path traversal is not allowed).',
          );
        }
        final alignRaw = params['alignment'];
        args = CommandBuilder.burnCaptions(
          inputPath,
          srtPath,
          fontSize: _int(params, 'font_size', 24),
          assColor: params['ass_color']?.toString(),
          alignment: alignRaw is num ? alignRaw.toInt() : null,
        );
        break;
      case 'generate_thumbnail':
        args = CommandBuilder.generateThumbnail(
          inputPath,
          _str(params, 'timestamp', '0'),
        );
        break;
      case 'change_format':
        args = CommandBuilder.changeFormat(
          inputPath,
          _str(params, 'target_ext', 'mp4'),
          params['codec_preset']?.toString(),
        );
        break;
      case 'adjust_brightness': {
        final base = CommandBuilder.adjustBrightness(
          inputPath,
          _num(params, 'value', 0.0),
        );
        // Same range restriction as `apply_effect` above.
        final rs = rangeStartOf(params);
        final rl = rangeLenOf(params);
        args = (rs != null && rl != null)
            ? ['-ss', rs.toString(), '-i', inputPath, '-t', rl.toString(), ...base.sublist(2)]
            : base;
        break;
      }
      case 'change_volume':
        args = CommandBuilder.changeVolume(
          inputPath,
          _num(params, 'factor', 1.0),
        );
        break;
      case 'overlay_watermark':
        final imagePath = FilterEscaping.validateImagePath(
          _str(params, 'image_path', ''),
          projectDir: projectDir ?? _dirOf(outputDir),
        );
        args = CommandBuilder.overlayWatermark(
          inputPath,
          imagePath,
          _str(params, 'position', 'bottom-right'),
          _num(params, 'opacity', 0.7),
        );
        break;
      default:
        args = ['-i', inputPath, '-c', 'copy'];
    }

    final ext = op.type == 'extract_audio'
        ? '.${_str(params, 'output_format', 'mp3')}'
        : op.type == 'generate_thumbnail'
            ? '.jpg'
            : '.mp4';

    return FfmpegJob(
      id: op.id,
      args: args,
      expectedDurationMs: 0,
      inputPath: inputPath,
      outputPath: _outputPathFor(outputDir, inputPath, op.id, ext),
    );
  }

  // --- Safe param readers (LLM may return numbers for string fields) ---

  static String _str(Map<String, dynamic> params, String key, String fallback) {
    final value = params[key];
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  static double _num(Map<String, dynamic> params, String key, double fallback) {
    final value = params[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _int(Map<String, dynamic> params, String key, int fallback) {
    final value = params[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Null-safe double read for optional effect params (builder defaults).
  static double? _numOrNull(Map<String, dynamic> params, String key) {
    final value = params[key];
    if (value is num) return value.toDouble();
    return null;
  }

  /// Walk-order first-wins range: the `clip_start_s`/`clip_len_s` pair
  /// from the FIRST op in [ops] that carries both (any composable type —
  /// cut, change_speed, or a future ranged op), or null when no op does.
  ///
  /// The params stay internal (never model-provided — the `font_file`
  /// convention): the executor stamps them when the clip's range is
  /// known. Absent/unparseable/half-set → null → legacy whole-file.
  static (double, double)? _firstRangedRestriction(
    List<EditOperationRequest> ops,
  ) {
    for (final op in ops) {
      final start = _cutRangeParam(op.params, 'clip_start_s');
      final len = _cutRangeParam(op.params, 'clip_len_s');
      if (start != null && len != null) return (start, len);
    }
    return null;
  }

  /// Null-safe double read for the ranged-input `clip_start_s`/
  /// `clip_len_s` params (the executor writes doubles; the manual path
  /// may write decimal strings). Absent/unparseable → null → the legacy
  /// whole-file path, unchanged behavior.
  static double? _cutRangeParam(Map<String, dynamic> params, String key) {
    final value = params[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static String _validatedColor(String color) {
    try {
      return FilterEscaping.validateColor(color);
    } on FilterValidationException catch (e) {
      throw CommandMappingException(e.message);
    }
  }

  static String _outputPathFor(
    String outputDir,
    String inputPath,
    String opId,
    String ext,
  ) {
    final dir = outputDir.trim().isNotEmpty ? outputDir.trim() : _dirOf(inputPath);
    final sep = dir.endsWith('/') || dir.endsWith(r'\') ? '' : '/';
    return '$dir$sep$opId$ext';
  }

  static String _dirOf(String path) {
    try {
      final parent = File(path).parent.path;
      if (parent.isNotEmpty && parent != '.' && parent != '') return parent;
    } catch (_) {}
    final normalized = path.replaceAll(r'\', '/');
    final idx = normalized.lastIndexOf('/');
    if (idx > 0) return path.substring(0, idx);
    return '.';
  }
}
