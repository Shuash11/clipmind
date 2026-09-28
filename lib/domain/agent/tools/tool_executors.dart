import 'dart:io';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/utils/timecode_utils.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/ffmpeg/filter_escaping.dart';
import 'package:clipmind/data/services/ffmpeg/srt_builder.dart';
import 'package:clipmind/data/services/ffmpeg/scene_detection_service.dart';
import 'package:clipmind/data/services/transcription/whisper_service.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
import 'package:clipmind/domain/agent/stage_6_execution.dart';
import 'tool_definition.dart';
import 'tool_registry.dart';

/// Live dependencies for tool execution (D6).
///
/// The project is read through [project] on every call so the agent edits
/// against live ground truth. Mirrors the [AgentEditApplier] pattern: the
/// domain never imports the state layer.
class ToolExecutionContext {
  final Project Function() project;
  final String outputDir;
  final String projectDir;
  final AgentEditApplier applier;
  final FfmpegService ffmpegService;
  final FfprobeService ffprobeService;
  final SceneDetectionService sceneDetectionService;
  final WhisperTranscriptionService whisperService;
  final int maxJobs;

  /// Cooperative cancellation: checked before each FFmpeg job starts.
  /// Mid-job kills go through [FfmpegService.cancel] directly.
  final CancellationToken? cancellation;

  /// Plan-preview mode: edit tools validate + map jobs and return
  /// `{'planned': true, ...}` without executing FFmpeg or touching the
  /// applier/journal. Read tools always run against the real project.
  final bool dryRun;

  /// Media-analysis cache (Phase 6a), wired by the state layer to the
  /// `MediaAnalysis` table. `kind` is namespaced (`scenes:<clipId>`,
  /// `transcript:<clipId>`); payloads carry a `source_path` stamp.
  final Map<String, dynamic>? Function(String kind)? readAnalysis;
  final void Function(String kind, Map<String, dynamic> payload)? writeAnalysis;

  /// whisper.cpp locations from Settings (`whisperBinaryPath` /
  /// `whisperModelPath`). Null (or null paths) = not configured → the
  /// executor falls back to PATH lookup, then degrades gracefully.
  /// Wired by the state layer; the middle-end agent owns the getters.
  final WhisperPaths? Function()? whisperConfig;

  int jobsUsed = 0;

  /// Run journal: every successfully applied edit lands here so the agent
  /// loop can report applied operations + outputs without new plumbing.
  final List<EditOperation> appliedOperations = [];
  final List<String> outputPaths = [];

  ToolExecutionContext({
    required this.project,
    required this.outputDir,
    required this.projectDir,
    required this.applier,
    required this.ffmpegService,
    required this.ffprobeService,
    SceneDetectionService? sceneDetectionService,
    WhisperTranscriptionService? whisperService,
    this.maxJobs = ToolRegistry.maxEditJobsPerRun,
    this.cancellation,
    this.dryRun = false,
    this.readAnalysis,
    this.writeAnalysis,
    this.whisperConfig,
  }) : sceneDetectionService =
           sceneDetectionService ?? SceneDetectionService(),
       whisperService = whisperService ?? WhisperTranscriptionService();

  void resetRun() {
    jobsUsed = 0;
    appliedOperations.clear();
    outputPaths.clear();
  }
}

/// Read tools: answer from project ground truth, never touch FFmpeg output.
class ReadToolExecutor implements ToolExecutor {
  final ToolExecutionContext _ctx;

  const ReadToolExecutor(this._ctx);

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      switch (call.name) {
        case 'list_project_clips':
          return _listClips();
        case 'probe_video':
          return await _probeVideo(call.args);
        case 'get_edit_history':
          return _editHistory();
        case 'detect_scenes':
          return await _detectScenes(call.args);
        case 'get_storyboard':
          return _storyboard(call.args);
        case 'get_transcript':
          return await _transcript(call.args);
        default:
          return ToolResult.fail(
            'Unknown read tool "${call.name}". '
            'Available: list_project_clips, probe_video, get_edit_history, '
            'detect_scenes, get_storyboard, get_transcript.',
          );
      }
    } catch (e) {
      return ToolResult.fail('Read tool "${call.name}" failed: $e');
    }
  }

  ToolResult _listClips() {
    final clips = <Map<String, dynamic>>[];
    for (final track in _ctx.project().tracks) {
      for (final clip in track.clips) {
        clips.add({
          'id': clip.id,
          'track_id': clip.trackId,
          'label': clip.label ?? clip.id,
          'start_ms': clip.startMs,
          'end_ms': clip.endMs,
          'position_ms': clip.positionMs,
        });
      }
    }
    return ToolResult.ok(
      data: {'clips': clips, 'count': clips.length},
      summary: '${clips.length} clip(s) in project.',
    );
  }

  Future<ToolResult> _probeVideo(Map<String, dynamic> args) async {
    final clipId = _stringArg(args, 'clip_id');
    if (clipId == null || clipId.isEmpty) {
      return ToolResult.fail(
        'probe_video needs a "clip_id" string. '
        'Call list_project_clips first to learn clip IDs.',
      );
    }
    final path = _clipPath(_ctx, clipId);
    if (path == null) {
      return ToolResult.fail(_unknownClip(clipId));
    }
    final meta = await _ctx.ffprobeService.extractMetadata(path);
    if (meta == null) {
      return ToolResult.fail(
        'Could not read metadata for clip "$clipId". '
        'The source file may be missing; try list_project_clips to verify.',
      );
    }
    return ToolResult.ok(
      data: {
        'clip_id': clipId,
        'duration_ms': meta.durationMs,
        'width': meta.width,
        'height': meta.height,
        'fps': meta.fps,
        'codec': meta.codec,
        'has_audio': meta.hasAudio,
      },
      summary: 'Metadata for clip "$clipId".',
    );
  }

  ToolResult _editHistory() {
    final ops = _ctx.project().editHistory.map((op) {
      return {
        'id': op.id,
        'type': op.type.name,
        'target_clip_ids': op.targetClipIds,
        'status': op.status.name,
      };
    }).toList();
    return ToolResult.ok(
      data: {'operations': ops, 'count': ops.length},
      summary: '${ops.length} applied operation(s).',
    );
  }

  /// Scene detection with DB-backed caching (stamp-invalidate on change).
  /// Read-only: never consumes the edit-job budget.
  Future<ToolResult> _detectScenes(Map<String, dynamic> args) async {
    final clipId = _stringArg(args, 'clip_id');
    if (clipId == null || clipId.isEmpty) {
      return ToolResult.fail(
        'detect_scenes needs a "clip_id" string. '
        'Call list_project_clips first to learn clip IDs.',
      );
    }
    final path = _clipPath(_ctx, clipId);
    if (path == null) {
      return ToolResult.fail(_unknownClip(clipId));
    }
    final rawThreshold =
        _numArg(args, 'threshold') ?? SceneDetectionService.thresholdDefault;
    final threshold = (rawThreshold.isFinite
            ? rawThreshold
            : SceneDetectionService.thresholdDefault)
        .clamp(0.0, 1.0);
    final rawMax = _numArg(args, 'max_scenes');
    final maxScenes = (rawMax != null && rawMax.isFinite
            ? rawMax.toInt()
            : SceneDetectionService.maxScenesDefault)
        .clamp(1, 500);
    final kind = 'scenes:$clipId';

    final cached = _ctx.readAnalysis?.call(kind);
    if (cached != null &&
        cached['source_path'] == path &&
        (cached['threshold'] as num?)?.toDouble() == threshold &&
        ((cached['max_scenes'] as num?)?.toInt() ?? 0) >= maxScenes) {
      final scenes = _intList(cached['scenes_ms']);
      return ToolResult.ok(
        data: {
          'clip_id': clipId,
          'scenes_ms': scenes,
          'count': scenes.length,
          'cached': true,
        },
        summary:
            '${scenes.length} scene(s) in clip "$clipId" (cached).',
      );
    }

    if (_ctx.cancellation?.isCancelled == true) {
      return ToolResult.fail(
        'Cancelled — scene detection did not run.',
      );
    }
    final detection = await _ctx.sceneDetectionService.detectScenes(
      path,
      threshold: threshold,
      maxScenes: maxScenes,
    );
    if (detection == null) {
      return ToolResult.fail(
        'Scene detection failed for clip "$clipId". '
        'FFmpeg may be missing or the file unreadable; '
        'try probe_video to verify the clip first.',
      );
    }
    _ctx.writeAnalysis?.call(kind, {
      'clip_id': clipId,
      'source_path': path,
      'threshold': threshold,
      'max_scenes': maxScenes,
      'scenes_ms': detection.scenesMs,
      'count': detection.count,
      'truncated': detection.truncated,
    });
    return ToolResult.ok(
      data: {
        'clip_id': clipId,
        'scenes_ms': detection.scenesMs,
        'count': detection.count,
        'truncated': detection.truncated,
        'cached': false,
      },
      summary: '${detection.count} scene(s) in clip "$clipId".',
    );
  }

  /// Storyboard summary: clip ranges + cached scenes + history count.
  /// Pure ground-truth read; never runs FFmpeg.
  ToolResult _storyboard(Map<String, dynamic> args) {
    final filterId = _stringArg(args, 'clip_id');
    if (filterId != null && filterId.isNotEmpty) {
      if (_clipPath(_ctx, filterId) == null) {
        return ToolResult.fail(_unknownClip(filterId));
      }
    }
    final project = _ctx.project();
    final clips = <Map<String, dynamic>>[];
    var scenesCovered = 0;
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        if (filterId != null &&
            filterId.isNotEmpty &&
            clip.id != filterId) {
          continue;
        }
        final cached = _ctx.readAnalysis?.call('scenes:${clip.id}');
        final scenes = (cached != null &&
                cached['source_path'] == clip.sourcePath)
            ? _intList(cached['scenes_ms'])
            : null;
        if (scenes != null) scenesCovered++;
        clips.add({
          'id': clip.id,
          'label': clip.label ?? clip.id,
          'start_ms': clip.startMs,
          'end_ms': clip.endMs,
          'position_ms': clip.positionMs,
          'scenes_ms': scenes,
          'scenes_cached': scenes != null,
        });
      }
    }
    final historyCount = project.editHistory.length;
    final data = <String, dynamic>{
      'clips': clips,
      'clip_count': clips.length,
      'edit_history_count': historyCount,
    };
    if (scenesCovered < clips.length) {
      final missing = [
        for (final c in clips)
          if (c['scenes_cached'] == false) c['id'] as String,
      ];
      data['hint'] =
          'No scene analysis for ${missing.join(', ')} — '
          'call detect_scenes for each clip first for scene-level detail.';
      return ToolResult.ok(
        data: data,
        summary:
            '${clips.length} clip(s), $historyCount edit(s); '
            'scene analysis missing — call detect_scenes first.',
      );
    }
    return ToolResult.ok(
      data: data,
      summary:
          '${clips.length} clip(s) with scene detail, $historyCount edit(s).',
    );
  }

  /// Optional transcription: degrades gracefully when whisper.cpp or its
  /// model is absent. Read-only: never consumes the edit-job budget.
  Future<ToolResult> _transcript(Map<String, dynamic> args) async {
    final clipId = _stringArg(args, 'clip_id');
    if (clipId == null || clipId.isEmpty) {
      return ToolResult.fail(
        'get_transcript needs a "clip_id" string. '
        'Call list_project_clips first to learn clip IDs.',
      );
    }
    final path = _clipPath(_ctx, clipId);
    if (path == null) {
      return ToolResult.fail(_unknownClip(clipId));
    }
    final rawMaxChars = _numArg(args, 'max_chars');
    final maxChars = (rawMaxChars != null && rawMaxChars.isFinite
            ? rawMaxChars.toInt()
            : 4000)
        .clamp(100, 20000);
    final kind = 'transcript:$clipId';

    final cached = _ctx.readAnalysis?.call(kind);
    if (cached != null && cached['source_path'] == path) {
      return _transcriptResult(
        clipId: clipId,
        text: (cached['text'] ?? '').toString(),
        segments: _segmentsFromCache(cached['segments']),
        maxChars: maxChars,
        cached: true,
      );
    }

    final config = _ctx.whisperConfig?.call();
    final binary = _ctx.whisperService.findBinary(
      configuredPath: config?.binaryPath,
    );
    if (binary == null) {
      return ToolResult.fail(
        'whisper.cpp not found — install it '
        '(https://github.com/ggml-org/whisper.cpp/releases, '
        'whisper-cli on PATH) or set the binary path in Settings, '
        'then retry get_transcript.',
      );
    }
    final model = config?.modelPath ?? '';
    if (model.isEmpty || !File(model).existsSync()) {
      return ToolResult.fail(
        'Whisper model file not configured — set whisperModelPath in '
        'Settings to a ggml .bin model file, then retry get_transcript.',
      );
    }
    if (_ctx.cancellation?.isCancelled == true) {
      return ToolResult.fail('Cancelled — transcription did not run.');
    }

    // whisper.cpp needs 16 kHz mono WAV: extract to a temp file first.
    final wavPath = _ctx.ffmpegService.createTempPath(suffix: '.wav');
    final extract = FfmpegJob(
      id: 'transcript-wav',
      args: ['-i', path, '-vn', '-ac', '1', '-ar', '16000', '-c:a', 'pcm_s16le'],
      expectedDurationMs: 0,
      inputPath: path,
      outputPath: wavPath,
    );
    try {
      final wav = await _ctx.ffmpegService.runSync(extract);
      if (!wav.success) {
        return ToolResult.fail(
          'Could not extract audio from clip "$clipId" for transcription. '
          'Try probe_video to verify the clip first.',
        );
      }
      final transcript = await _ctx.whisperService.transcribe(
        wavPath,
        model,
        binaryPath: binary,
      );
      if (transcript == null || transcript.isEmpty) {
        return ToolResult.fail(
          'Transcription failed for clip "$clipId" '
          '(empty result, CLI error, or 120s timeout). '
          'Check the whisper model file and retry.',
        );
      }
      _ctx.writeAnalysis?.call(kind, {
        'clip_id': clipId,
        'source_path': path,
        'text': transcript.text,
        'chars': transcript.charCount,
        // All segments persist (no cap); the tool result caps at 100.
        'segments': [
          for (final s in transcript.segments) s.toJson(),
        ],
      });
      return _transcriptResult(
        clipId: clipId,
        text: transcript.text,
        segments: transcript.segments,
        maxChars: maxChars,
        cached: false,
      );
    } finally {
      try {
        final f = File(wavPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Tool-result segments stay bounded (first 100) so the model context
  /// stays bounded; the cached payload keeps every segment (no data loss).
  static const maxTranscriptResultSegments = 100;

  /// Backward-compatible cache read: payloads written before segments
  /// existed carry no `segments` field → empty list. Stamp invalidation
  /// (`source_path`) is unchanged. Shared with [EditToolExecutor] (SRT
  /// generation reads the full cached set, not the capped tool view).
  List<TranscriptSegment> _segmentsFromCache(Object? raw) =>
      transcriptSegmentsFromCache(raw);

  ToolResult _transcriptResult({
    required String clipId,
    required String text,
    required List<TranscriptSegment> segments,
    required int maxChars,
    required bool cached,
  }) {
    final truncated = text.length > maxChars;
    final shown = segments.length > maxTranscriptResultSegments
        ? segments.sublist(0, maxTranscriptResultSegments)
        : segments;
    return ToolResult.ok(
      data: {
        'clip_id': clipId,
        'text': truncated ? text.substring(0, maxChars) : text,
        'segments': [for (final s in shown) s.toJson()],
        'count': segments.length,
        'chars': text.length,
        'truncated': truncated,
        'cached': cached,
      },
      summary: truncated
          ? 'Transcript for "$clipId" (${text.length} chars, truncated to $maxChars, ${segments.length} caption segments).'
          : 'Transcript for "$clipId" (${text.length} chars, ${segments.length} caption segments${cached ? ', cached' : ''}).',
    );
  }

  static List<int> _intList(dynamic raw) {
    if (raw is! List) return const [];
    return [for (final e in raw) if (e is num) e.toInt()];
  }
}

/// Edit tools: one tool call = one [EditOperationRequest] through the exact
/// Phase-1 path (CommandMapper → ExecutionEngine → AgentEditApplier).
class EditToolExecutor implements ToolExecutor {
  final ToolExecutionContext _ctx;

  const EditToolExecutor(this._ctx);

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      switch (call.name) {
        case 'trim_clip':
          return await _trim(call);
        case 'cut_segment':
          return await _cut(call);
        case 'merge_clips':
          return await _merge(call);
        case 'change_speed':
          return await _changeSpeed(call);
        case 'mute_clip':
          return await _mute(call);
        case 'overlay_text':
          return await _overlayText(call);
        case 'resize_clip':
          return await _resize(call);
        case 'rotate_clip':
          return await _rotate(call);
        case 'adjust_brightness':
          return await _brightness(call);
        case 'change_volume':
          return await _volume(call);
        case 'extract_audio':
          return await _extractAudio(call);
        case 'burn_captions':
          return await _burnCaptions(call);
        default:
          return ToolResult.fail(
            'Unknown edit tool "${call.name}".',
          );
      }
    } on CommandMappingException catch (e) {
      return ToolResult.fail(e.message);
    } on FilterValidationException catch (e) {
      return ToolResult.fail(e.message);
    } catch (e) {
      return ToolResult.fail('Tool "${call.name}" failed: $e');
    }
  }

  // --- Individual tools ---------------------------------------------------

  Future<ToolResult> _trim(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final start = _stringArg(call.args, 'start');
    final end = _stringArg(call.args, 'end');
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    final tcError =
        _requireTimecode(start, 'start') ?? _requireTimecode(end, 'end');
    if (tcError != null) return ToolResult.fail(tcError);
    final orderError = _requireOrder(start!, end!, 'start', 'end');
    if (orderError != null) return ToolResult.fail(orderError);
    return _runSingleOp(
      callId: call.id,
      opType: 'trim',
      clipId: clipId!,
      params: {'start': start, 'end': end},
      summary: 'Trimmed clip "$clipId" to $start–$end.',
    );
  }

  Future<ToolResult> _cut(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final start = _stringArg(call.args, 'remove_start');
    final end = _stringArg(call.args, 'remove_end');
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    final tcError = _requireTimecode(start, 'remove_start') ??
        _requireTimecode(end, 'remove_end');
    if (tcError != null) return ToolResult.fail(tcError);
    final orderError =
        _requireOrder(start!, end!, 'remove_start', 'remove_end');
    if (orderError != null) return ToolResult.fail(orderError);
    return _runSingleOp(
      callId: call.id,
      opType: 'cut',
      clipId: clipId!,
      params: {'remove_start': start, 'remove_end': end},
      summary: 'Cut $start–$end from clip "$clipId".',
    );
  }

  Future<ToolResult> _merge(ToolCall call) async {
    final raw = call.args['clip_ids'];
    if (raw is! List || raw.length < 2) {
      return ToolResult.fail(
        'merge_clips needs "clip_ids" with at least 2 clip IDs, '
        'e.g. {"clip_ids": ["clip_1", "clip_2"]}. '
        'Call list_project_clips first.',
      );
    }
    final ids = raw.map((e) => e.toString()).toList();
    for (final id in ids) {
      final clipError = _requireClip(id);
      if (clipError != null) return ToolResult.fail(clipError);
    }
    // merge resolves every ID through the live path map.
    final map = _clipPathMap(_ctx);
    final first = map[ids.first] ?? _defaultPath(_ctx);
    if (first == null) {
      return ToolResult.fail('No video file in project.');
    }
    if (_ctx.jobsUsed + 1 > _ctx.maxJobs) {
      return ToolResult.fail(_budgetMessage);
    }
    final set = EditOperationSet(
      operations: [
        EditOperationRequest(
          id: call.id,
          type: 'merge',
          targetClipId: ids.first,
          params: {'clip_ids': ids},
        ),
      ],
      summary: 'Merged ${ids.length} clips.',
    );
    return _executeSet(
      set: set,
      callId: call.id,
      clipIds: [ids.first],
      summary: 'Merged ${ids.length} clips starting with "${ids.first}".',
    );
  }

  Future<ToolResult> _changeSpeed(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final factor = _numArg(call.args, 'factor');
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    if (factor == null || factor <= 0) {
      return ToolResult.fail(
        'change_speed needs a positive "factor" number, '
        'e.g. {"clip_id": "$clipId", "factor": 2.0}. Got "$factor".',
      );
    }
    return _runSingleOp(
      callId: call.id,
      opType: 'change_speed',
      clipId: clipId!,
      params: {'factor': factor},
      summary: 'Changed speed of "$clipId" to ${factor}x.',
    );
  }

  Future<ToolResult> _mute(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    return _runSingleOp(
      callId: call.id,
      opType: 'mute',
      clipId: clipId!,
      params: {},
      summary: 'Muted clip "$clipId".',
    );
  }

  Future<ToolResult> _overlayText(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final text = _stringArg(call.args, 'text');
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    if (text == null || text.trim().isEmpty) {
      return ToolResult.fail(
        'overlay_text needs a non-empty "text" string.',
      );
    }
    if (_hasFilterBreakout(text)) {
      return ToolResult.fail(
        'overlay_text "text" contains characters that would break the '
        'video filter (quotes followed by filter syntax or newlines). '
        'Use plain text without \');\', \';\' sequences or line breaks.',
      );
    }
    final color = _stringArg(call.args, 'color') ?? '#FFFFFF';
    try {
      FilterEscaping.validateColor(color);
    } on FilterValidationException catch (e) {
      return ToolResult.fail('${e.message} Retry with e.g. "#FFFFFF".');
    }
    return _runSingleOp(
      callId: call.id,
      opType: 'overlay_text',
      clipId: clipId!,
      params: {
        'text': text,
        'position': _stringArg(call.args, 'position') ?? 'center',
        'font_size': _numArg(call.args, 'font_size') ?? 48,
        'color': color,
        'start': _stringArg(call.args, 'start') ?? '0',
        'end': _stringArg(call.args, 'end') ?? '0',
      },
      summary: 'Added text overlay on "$clipId".',
    );
  }

  Future<ToolResult> _resize(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final width = _numArg(call.args, 'width')?.toInt();
    final height = _numArg(call.args, 'height')?.toInt();
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    if (width == null || width <= 0 || height == null || height <= 0) {
      return ToolResult.fail(
        'resize_clip needs positive "width"/"height" numbers, '
        'e.g. {"clip_id": "$clipId", "width": 1920, "height": 1080}.',
      );
    }
    return _runSingleOp(
      callId: call.id,
      opType: 'resize',
      clipId: clipId!,
      params: {
        'width': width,
        'height': height,
        'fit': _stringArg(call.args, 'fit') ?? 'fill',
      },
      summary: 'Resized "$clipId" to ${width}x$height.',
    );
  }

  Future<ToolResult> _rotate(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final degrees = _numArg(call.args, 'degrees');
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    if (degrees != 90 && degrees != 180 && degrees != 270) {
      return ToolResult.fail(
        'rotate_clip "degrees" must be 90, 180 or 270. Got "$degrees".',
      );
    }
    return _runSingleOp(
      callId: call.id,
      opType: 'rotate',
      clipId: clipId!,
      params: {'degrees': degrees},
      summary: 'Rotated "$clipId" by $degrees°.',
    );
  }

  Future<ToolResult> _brightness(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final value = _numArg(call.args, 'value');
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    if (value == null || value < -1.0 || value > 1.0) {
      return ToolResult.fail(
        'adjust_brightness "value" must be between -1.0 and 1.0. '
        'Got "$value".',
      );
    }
    return _runSingleOp(
      callId: call.id,
      opType: 'adjust_brightness',
      clipId: clipId!,
      params: {'value': value},
      summary: 'Adjusted brightness of "$clipId".',
    );
  }

  Future<ToolResult> _volume(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final factor = _numArg(call.args, 'factor');
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    if (factor == null || factor <= 0) {
      return ToolResult.fail(
        'change_volume needs a positive "factor" number, '
        'e.g. {"clip_id": "$clipId", "factor": 0.5}. Got "$factor".',
      );
    }
    return _runSingleOp(
      callId: call.id,
      opType: 'change_volume',
      clipId: clipId!,
      params: {'factor': factor},
      summary: 'Changed volume of "$clipId".',
    );
  }

  Future<ToolResult> _extractAudio(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    final format = _stringArg(call.args, 'output_format') ?? 'mp3';
    if (format != 'mp3' && format != 'aac' && format != 'wav') {
      return ToolResult.fail(
        'extract_audio "output_format" must be mp3, aac or wav. '
        'Got "$format".',
      );
    }
    return _runSingleOp(
      callId: call.id,
      opType: 'extract_audio',
      clipId: clipId!,
      params: {'output_format': format},
      summary: 'Extracted audio from "$clipId" as $format.',
    );
  }

  /// Burn the cached transcript as timed captions (SRT via libass).
  ///
  /// The SRT is generated app-side from the FULL cached segment set and
  /// written to a temp file (cleaned up in `finally`); the model never
  /// passes paths. Consumes one edit-job budget unit via [_executeSet].
  Future<ToolResult> _burnCaptions(ToolCall call) async {
    final clipId = _stringArg(call.args, 'clip_id');
    final clipError = _requireClip(clipId);
    if (clipError != null) return ToolResult.fail(clipError);
    final path = _clipPath(_ctx, clipId!)!;

    final rawColor = _stringArg(call.args, 'font_color');
    String? assColor;
    if (rawColor != null && rawColor.trim().isNotEmpty) {
      try {
        assColor = FilterEscaping.assColorFromHex(rawColor.trim());
      } on FilterValidationException catch (e) {
        return ToolResult.fail('${e.message} Retry with e.g. "#FFFFFF".');
      }
    }
    // Style hint, not a safety value: unknown positions fall back to
    // bottom without error. bottom → omit Alignment; top → 8
    // (numpad top-center); center → 5 (numpad middle-center).
    // TO-VERIFY-LIVE: numpad (modern `\an`) vs legacy (`\a`) semantics.
    final rawPosition =
        (_stringArg(call.args, 'position') ?? 'bottom').trim().toLowerCase();
    final position =
        rawPosition == 'top' || rawPosition == 'center' ? rawPosition : 'bottom';
    final alignment = position == 'top' ? 8 : position == 'center' ? 5 : null;
    final fontSize = _numArg(call.args, 'font_size')?.toInt() ?? 24;

    final cached = _ctx.readAnalysis?.call('transcript:$clipId');
    if (cached == null || cached['source_path'] != path) {
      return ToolResult.fail(
        'No transcript cached for clip "$clipId" — call get_transcript '
        'first, then retry burn_captions.',
      );
    }
    final segments = transcriptSegmentsFromCache(cached['segments']);
    if (segments.isEmpty) {
      return ToolResult.fail(
        'The transcript for clip "$clipId" has no timed segments — '
        're-run get_transcript.',
      );
    }
    if (_ctx.cancellation?.isCancelled == true) {
      return ToolResult.fail(
        'Cancelled — captions were not burned. Already-applied edits remain.',
      );
    }
    if (_ctx.jobsUsed + 1 > _ctx.maxJobs) {
      return ToolResult.fail(_budgetMessage);
    }

    final srtPath = _ctx.ffmpegService.createTempPath(suffix: '.srt');
    try {
      await File(srtPath).writeAsString(SrtBuilder.buildSrt(segments));
      final opParams = <String, dynamic>{
        'srt_path': srtPath,
        'font_size': fontSize,
      };
      if (assColor != null) opParams['ass_color'] = assColor;
      if (alignment != null) opParams['alignment'] = alignment;
      final result = await _executeSet(
        set: EditOperationSet(
          operations: [
            EditOperationRequest(
              id: call.id,
              type: 'burn_captions',
              targetClipId: clipId,
              params: opParams,
            ),
          ],
          summary: 'Burn captions into "$clipId".',
        ),
        callId: call.id,
        clipIds: [clipId],
        summary: 'Burn captions into "$clipId".',
        ffmpegFailureHint:
            'The FFmpeg build may lack libass (subtitles filter). '
            'Check the bundled FFmpeg installation.',
      );
      if (_ctx.dryRun) return result;
      if (!result.success) return result;
      return ToolResult.ok(
        data: {
          ...result.data,
          'segments_burned': segments.length,
        },
        summary: 'Burned ${segments.length} caption(s) into clip "$clipId".',
      );
    } finally {
      try {
        final f = File(srtPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  // --- Shared Phase-1 execution -------------------------------------------

  Future<ToolResult> _runSingleOp({
    required String callId,
    required String opType,
    required String clipId,
    required Map<String, dynamic> params,
    required String summary,
  }) {
    return _executeSet(
      set: EditOperationSet(
        operations: [
          EditOperationRequest(
            id: callId,
            type: opType,
            targetClipId: clipId,
            params: params,
          ),
        ],
        summary: summary,
      ),
      callId: callId,
      clipIds: [clipId],
      summary: summary,
    );
  }

  Future<ToolResult> _executeSet({
    required EditOperationSet set,
    required String callId,
    required List<String> clipIds,
    required String summary,
    String? ffmpegFailureHint,
  }) async {
    if (_ctx.cancellation?.isCancelled == true) {
      return ToolResult.fail(
        'Cancelled — this edit did not run. Already-applied edits remain.',
      );
    }
    if (_ctx.jobsUsed + 1 > _ctx.maxJobs) {
      return ToolResult.fail(_budgetMessage);
    }
    final map = _clipPathMap(_ctx);
    final defaultPath = _defaultPath(_ctx);
    if (defaultPath == null && map.isEmpty) {
      return ToolResult.fail('No video file in project.');
    }
    final jobs = CommandMapper.mapOperations(
      set,
      map,
      _ctx.outputDir,
      defaultPath: defaultPath,
      projectDir: _ctx.projectDir,
    );
    if (_ctx.jobsUsed + jobs.length > _ctx.maxJobs) {
      return ToolResult.fail(_budgetMessage);
    }
    if (_ctx.dryRun) {
      // Plan-preview: validated + mapped, but never executed, journaled,
      // or counted against the budget. Replay happens via
      // [Nl2VecPipeline.executePlanned] with a real context.
      final first = set.operations.first;
      return ToolResult.ok(
        data: {
          'planned': true,
          'op_type': first.type,
          'target_clip_ids': clipIds,
          'params': Map<String, dynamic>.from(first.params),
        },
        summary: 'Would ${_lowerFirst(summary)}',
      );
    }
    _ctx.jobsUsed += jobs.length;

    final engine = ExecutionEngine(_ctx.ffmpegService);
    try {
      final result = await engine.execute(jobs, '');
      if (!result.success) {
        return ToolResult.fail(
          'FFmpeg failed: ${result.errorMessage ?? result.summary} '
          '${ffmpegFailureHint ?? 'Check the timecodes and clip IDs, then retry.'}',
        );
      }
      final outputPath = result.outputPaths.isNotEmpty
          ? result.outputPaths.first
          : jobs.first.outputPath;
      final op = EditOperation(
        id: callId,
        type: _operationType(set.operations.first.type),
        targetClipIds: clipIds,
        params: Map<String, dynamic>.from(set.operations.first.params),
        createdAt: DateTime.now(),
        status: OperationStatus.applied,
        ffmpegCommand: jobs.first.args.join(' '),
      );
      await _ctx.applier.apply(op, outputPath);
      _ctx.appliedOperations.add(op);
      _ctx.outputPaths.add(outputPath);
      return ToolResult.ok(
        data: {'output_path': outputPath, 'operation_id': op.id},
        summary: summary,
      );
    } finally {
      engine.dispose();
    }
  }

  // --- Validation helpers (actionable messages, never throws) --------------

  static final RegExp _strictTimecode = RegExp(r'^\d+:\d{2}:\d{2}\.\d{3}$');

  static String? _requireTimecode(String? value, String field) {
    if (value == null ||
        value.trim().isEmpty ||
        !_strictTimecode.hasMatch(value.trim())) {
      return 'Invalid "$field" timecode. Expected HH:MM:SS.mmm '
          '(e.g. "00:00:05.000"), got "$value". Retry with that format.';
    }
    return null;
  }

  static String? _requireOrder(
    String start,
    String end,
    String startField,
    String endField,
  ) {
    final startMs = TimecodeUtils.parseToMilliseconds(start);
    final endMs = TimecodeUtils.parseToMilliseconds(end);
    if (startMs != null && endMs != null && endMs <= startMs) {
      return '"$endField" ($end) must be after "$startField" ($start).';
    }
    return null;
  }

  static bool _hasFilterBreakout(String text) {
    if (text.contains('\n') || text.contains('\r')) return true;
    return RegExp(r'''['"]\s*[);]''').hasMatch(text);
  }

  String? _requireClip(String? clipId) {
    if (clipId == null || clipId.trim().isEmpty) {
      return 'Missing "clip_id". Call list_project_clips first to learn '
          'clip IDs, then retry with a valid ID.';
    }
    if (_clipPath(_ctx, clipId) == null) {
      return _unknownClip(clipId);
    }
    return null;
  }

  static String get _budgetMessage =>
      'Edit budget exceeded (max ${ToolRegistry.maxEditJobsPerRun} FFmpeg '
      'jobs per run). Summarise what was done so far instead.';

  static EditOperationType _operationType(String type) {
    switch (type) {
      case 'trim':
        return EditOperationType.trim;
      case 'cut':
        return EditOperationType.cut;
      case 'merge':
        return EditOperationType.merge;
      case 'change_speed':
        return EditOperationType.changeSpeed;
      case 'mute':
        return EditOperationType.mute;
      case 'overlay_text':
        return EditOperationType.overlayText;
      case 'resize':
        return EditOperationType.resize;
      case 'rotate':
        return EditOperationType.rotate;
      case 'extract_audio':
        return EditOperationType.extractAudio;
      case 'burn_captions':
        return EditOperationType.burnCaptions;
      case 'adjust_brightness':
        return EditOperationType.adjustBrightness;
      case 'change_volume':
        return EditOperationType.changeVolume;
      default:
        return EditOperationType.changeFormat;
    }
  }
}

/// Default registry wiring every tool name to the read/edit executors
/// bound to [ctx]. Used by [ToolCallingAgent] and the state providers.
ToolRegistry createToolRegistry(ToolExecutionContext ctx) {
  final read = ReadToolExecutor(ctx);
  final edit = EditToolExecutor(ctx);
  return ToolRegistry(executors: {
    'list_project_clips': read,
    'probe_video': read,
    'get_edit_history': read,
    'detect_scenes': read,
    'get_storyboard': read,
    'get_transcript': read,
    'trim_clip': edit,
    'cut_segment': edit,
    'merge_clips': edit,
    'change_speed': edit,
    'mute_clip': edit,
    'overlay_text': edit,
    'resize_clip': edit,
    'rotate_clip': edit,
    'adjust_brightness': edit,
    'change_volume': edit,
    'extract_audio': edit,
    'burn_captions': edit,
  });
}

// --- Shared arg + project helpers -------------------------------------------

/// Read cached transcript segments defensively (Phase 1 + Phase 2 share).
///
/// Payloads written before segments existed carry no `segments` field →
/// empty list; malformed entries are skipped silently (degradation).
List<TranscriptSegment> transcriptSegmentsFromCache(Object? raw) {
  if (raw is! List) return const [];
  final segments = <TranscriptSegment>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    try {
      final segment = TranscriptSegment.fromJson(
        Map<String, dynamic>.from(entry),
      );
      if (segment != null) segments.add(segment);
    } catch (_) {
      // Malformed cache entries are skipped silently (degradation).
    }
  }
  return segments;
}

String? _stringArg(Map<String, dynamic> args, String key) {
  final value = args[key];
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

String _lowerFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toLowerCase() + text.substring(1);
}

double? _numArg(Map<String, dynamic> args, String key) {
  final value = args[key];
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _unknownClip(String clipId) {
  return 'Unknown clip ID "$clipId". Call list_project_clips to see '
      'available IDs, then retry with a valid one.';
}

// --- Live project helpers --------------------------------------------------

Map<String, String> _clipPathMap(ToolExecutionContext ctx) {
  final map = <String, String>{};
  for (final track in ctx.project().tracks) {
    for (final clip in track.clips) {
      if (clip.sourcePath.trim().isNotEmpty) {
        map[clip.id] = clip.sourcePath;
      }
    }
  }
  return map;
}

String? _clipPath(ToolExecutionContext ctx, String clipId) {
  return _clipPathMap(ctx)[clipId];
}

String? _defaultPath(ToolExecutionContext ctx) {
  final project = ctx.project();
  if (project.sourceMediaPaths.isNotEmpty) {
    return project.sourceMediaPaths.first;
  }
  final map = _clipPathMap(ctx);
  return map.values.isEmpty ? null : map.values.first;
}
