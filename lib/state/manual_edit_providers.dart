import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:clipmind/core/constants/effect_presets.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/procedural_sound_service.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
import 'package:clipmind/domain/agent/stage_6_execution.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/structural_edit_providers.dart';

/// Typed outcome of a manual panel edit (cut, effect recipe, text overlay,
/// sound). Mirrors the `SubmitResult` pattern.
class ManualCutResult {
  final bool success;
  final String message;
  final String? outputPath;

  const ManualCutResult({
    required this.success,
    required this.message,
    this.outputPath,
  });

  factory ManualCutResult.ok(String outputPath) => ManualCutResult.okWith(
        outputPath,
        'Cut applied.',
      );

  factory ManualCutResult.okWith(String outputPath, String message) =>
      ManualCutResult(
        success: true,
        message: message,
        outputPath: outputPath,
      );

  factory ManualCutResult.fail(String message) => ManualCutResult(
        success: false,
        message: message,
      );

  /// Structural success (trim/split): no FFmpeg runs, so there is no
  /// output file — [outputPath] stays null and Track 3 reads
  /// `success`/`message` only.
  factory ManualCutResult.okStructural(String message) => ManualCutResult(
        success: true,
        message: message,
      );
}

/// Manual-FFmpeg edit controller (D4): panel submits executed through the
/// existing `CommandMapper` → `ExecutionEngine` →
/// `agentEditApplierProvider` chain, so every edit is undoable, journaled
/// and persisted exactly like an agent edit.
///
/// Package C (the CapCut-style panels, Track 3) reads
/// `ref.read(manualEditControllerProvider)` and calls the plain-param
/// submits below; no presentation types cross this boundary.
///
/// Expose-points for Track 3:
/// - `submitCut({clipId, startMs, endMs})` — ruler range-cut (existing).
/// - `submitRecipe(presetId, {clipId})` — one-click effect preset; ids and
///   labels come from `effectPresets` (`noir`, `vintage`, `cinematic`,
///   `warm`, `cool`, `brighten`, `soften`, `dramatic`).
/// - `submitOverlayText({clipId, text, fontFamily, position, fontSize,
///   color, start, end})` — text overlay; `fontFamily` is a bundled family
///   id/label (`Inter` … `EB Garamond`) or null for the system default.
/// - `submitSound({clipId, soundSource, volume})` — sound-source
///   convention (auto-detect): a known procedural preset id (`beep`,
///   `drone-low`, `drone-mid`, `hum`, `static-noise`, `alert-chime`)
///   renders a temp wav via `ProceduralSoundService`; anything else is a
///   local file path (frontend passes the file_picker result).
/// - `submitTrim({clipId, startMs, endMs})` — trim handles: LOCAL source
///   times (the clip's new in/out); runs through
///   `structuralEditApplierProvider` (`trimClip`), so no FFmpeg and no
///   output file (success has `outputPath == null`).
/// - `submitSplit({clipId, atProjectMs})` — split button: PROJECT timeline
///   time (the playhead position, passed straight through); the controller
///   converts to the SOURCE split point
///   (`atProjectMs − clip.positionMs + clip.startMs`) and runs `splitClip`
///   through the same structural applier (no output file on success).
class ManualEditController {
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  const ManualEditController(this._ref);

  /// Cut out `[startMs, endMs)` (timeline ruler times) from [clipId].
  ///
  /// Time mapping: the ruler times are TIMELINE times, so subtracting the
  /// clip's `positionMs` gives the SPAN-relative local time — but the
  /// FFmpeg `cut`'s `t` is the FILE (source) time. For handle-trimmed
  /// clips (`startMs > 0`) the file time needs the in-point back:
  /// `fileTime = clip.startMs + local`. Combined with the applier's
  /// range normalization (repointed clips land on `startMs = 0`), the
  /// mapping is exact for every clip state. The journaled op also carries
  /// the `new_start_ms`/`new_end_ms` output range (mirroring the backend
  /// executor's `_cutNewRange`: `[0, clipLen − removedLen]`, omitted when
  /// degenerate) so `applyEdit` normalizes the clip's range and repins
  /// the track on the manual path too.
  Future<ManualCutResult> submitCut({
    required String clipId,
    required int startMs,
    required int endMs,
  }) async {
    final target = _resolveTarget(clipId);
    if (target.failure != null) {
      return ManualCutResult.fail(target.failure!);
    }
    final project = target.project!;
    final found = target.clip!;
    final spanStart = found.positionMs;
    final spanEnd =
        found.positionMs + (found.endMs - found.startMs);
    if (startMs < spanStart || endMs > spanEnd || startMs >= endMs) {
      return ManualCutResult.fail(
        'Invalid cut range [$startMs, $endMs): must lie inside clip '
        '"$clipId" ($spanStart–$spanEnd) with start before end.',
      );
    }
    final localStart = startMs - spanStart;
    final localEnd = endMs - spanStart;
    // Span-relative → file time: add the clip's in-point back.
    final fileStart = found.startMs + localStart;
    final fileEnd = found.startMs + localEnd;

    final opId = _uuid.v4();
    final params = <String, dynamic>{
      'remove_start': _toSeconds(fileStart),
      'remove_end': _toSeconds(fileEnd),
    };
    final clipLen = found.endMs - found.startMs;
    final newLen = clipLen - (localEnd - localStart);
    if (clipLen > 0 && newLen >= 0) {
      params['new_start_ms'] = 0;
      params['new_end_ms'] = newLen;
    }
    final clipPathMap = _clipPathMap(project);
    final defaultPath = _defaultPath(project, clipPathMap);
    if (defaultPath == null) {
      return ManualCutResult.fail('No video file in project.');
    }

    late final List<FfmpegJob> jobs;
    try {
      jobs = CommandMapper.mapOperations(
        EditOperationSet(
          operations: [
            EditOperationRequest(
              id: opId,
              type: 'cut',
              targetClipId: clipId,
              params: params,
            ),
          ],
          summary: 'Manual cut',
        ),
        clipPathMap,
        project.outputDir,
        defaultPath: defaultPath,
      );
    } catch (e) {
      return ManualCutResult.fail('Could not map the cut: $e');
    }
    if (jobs.length != 1) {
      return ManualCutResult.fail(
        'Cut mapping produced ${jobs.length} jobs; expected 1.',
      );
    }

    final engine = ExecutionEngine(_ref.read(ffmpegServiceProvider));
    try {
      final result = await engine.execute(jobs, '');
      if (!result.success) {
        return ManualCutResult.fail(
          'FFmpeg failed: ${result.errorMessage ?? result.summary}',
        );
      }
      final outputPath = result.outputPaths.isNotEmpty
          ? result.outputPaths.first
          : jobs.first.outputPath;
      final applied = EditOperation(
        id: opId,
        type: EditOperationType.cut,
        targetClipIds: [clipId],
        params: Map<String, dynamic>.from(params),
        createdAt: DateTime.now(),
        ffmpegCommand: jobs.first.args.join(' '),
      );
      await _ref.read(agentEditApplierProvider).apply(applied, outputPath);
      return ManualCutResult.ok(outputPath);
    } finally {
      engine.dispose();
    }
  }

  /// Apply the one-click effect preset [presetId] to [clipId].
  ///
  /// The recipe steps expand directly into op requests over the same clip,
  /// so `CommandMapper` composes them into ONE job. Each step is journaled
  /// as its own `EditOperation` (the legacy pipeline pattern), all
  /// pointing at the composed output, so history replay stays faithful.
  Future<ManualCutResult> submitRecipe(
    String presetId, {
    required String clipId,
  }) async {
    EffectPreset? preset;
    for (final candidate in effectPresets) {
      if (candidate.id == presetId) {
        preset = candidate;
        break;
      }
    }
    if (preset == null) {
      return ManualCutResult.fail(
        'Unknown effect preset "$presetId". Available: '
        '${effectPresets.map((p) => p.id).join(', ')}.',
      );
    }
    if (preset.recipe.isEmpty) {
      return ManualCutResult.fail(
        'Effect preset "$presetId" has no steps.',
      );
    }
    for (final step in preset.recipe) {
      if (_recipeJournalType(step.opType) == null) {
        return ManualCutResult.fail(
          'Effect preset "$presetId" uses unsupported op "${step.opType}".',
        );
      }
    }

    final target = _resolveTarget(clipId);
    if (target.failure != null) {
      return ManualCutResult.fail(target.failure!);
    }
    final project = target.project!;

    final clipPathMap = _clipPathMap(project);
    final defaultPath = _defaultPath(project, clipPathMap);
    if (defaultPath == null) {
      return ManualCutResult.fail('No video file in project.');
    }

    final requests = [
      for (final step in preset.recipe)
        EditOperationRequest(
          id: _uuid.v4(),
          type: step.opType,
          targetClipId: clipId,
          params: Map<String, dynamic>.from(step.params),
        ),
    ];
    late final List<FfmpegJob> jobs;
    try {
      jobs = CommandMapper.mapOperations(
        EditOperationSet(
          operations: requests,
          summary: 'Effect preset "${preset.label}"',
        ),
        clipPathMap,
        project.outputDir,
        defaultPath: defaultPath,
      );
    } catch (e) {
      return ManualCutResult.fail(
        'Could not map effect "${preset.label}": $e',
      );
    }
    if (jobs.length != 1) {
      return ManualCutResult.fail(
        'Effect mapping produced ${jobs.length} jobs; expected 1.',
      );
    }

    final engine = ExecutionEngine(_ref.read(ffmpegServiceProvider));
    try {
      final result = await engine.execute(jobs, '');
      if (!result.success) {
        return ManualCutResult.fail(
          'FFmpeg failed: ${result.errorMessage ?? result.summary}',
        );
      }
      final outputPath = result.outputPaths.isNotEmpty
          ? result.outputPaths.first
          : jobs.first.outputPath;
      final ffmpegCommand = jobs.first.args.join(' ');
      for (final request in requests) {
        await _ref.read(agentEditApplierProvider).apply(
              EditOperation(
                id: request.id,
                type: _recipeJournalType(request.type)!,
                targetClipIds: [clipId],
                params: Map<String, dynamic>.from(request.params),
                createdAt: DateTime.now(),
                ffmpegCommand: ffmpegCommand,
              ),
              outputPath,
            );
      }
      return ManualCutResult.okWith(
        outputPath,
        'Effect "${preset.label}" applied.',
      );
    } finally {
      engine.dispose();
    }
  }

  /// Overlay [text] on [clipId], resolving [fontFamily] through
  /// `fontResolverProvider` when given (null/empty = system default).
  ///
  /// `fontFamily` accepts a catalogued id (`source_code_pro`) or its
  /// display label (`Source Code Pro`); unknown families fail actionably.
  /// The resolved `.ttf` path lands in the op params as `font_file`
  /// (app-generated, never model-provided).
  Future<ManualCutResult> submitOverlayText({
    required String clipId,
    required String text,
    String? fontFamily,
    String position = 'center',
    int fontSize = 48,
    String color = '#FFFFFF',
    String start = '0',
    String end = '0',
  }) async {
    if (text.trim().isEmpty) {
      return ManualCutResult.fail(
        'Text must not be empty.',
      );
    }
    final target = _resolveTarget(clipId);
    if (target.failure != null) {
      return ManualCutResult.fail(target.failure!);
    }
    final project = target.project!;

    final params = <String, dynamic>{
      'text': text,
      'position': position,
      'font_size': fontSize,
      'color': color,
      'start': start,
      'end': end,
    };
    final familyRaw = fontFamily?.trim() ?? '';
    if (familyRaw.isNotEmpty) {
      // Same normalization as the agent-loop executor: display labels
      // resolve like ids.
      final family =
          familyRaw.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final fontFile =
          await _ref.read(fontResolverProvider).resolve(family);
      if (fontFile == null) {
        return ManualCutResult.fail(
          'Unknown font "$familyRaw" — pick one of the bundled fonts '
          '(Inter, Montserrat, Roboto, Lato, Source Code Pro, EB Garamond), '
          'or omit the font for the system default.',
        );
      }
      params['font'] = family;
      params['font_file'] = fontFile;
    }

    final clipPathMap = _clipPathMap(project);
    final defaultPath = _defaultPath(project, clipPathMap);
    if (defaultPath == null) {
      return ManualCutResult.fail('No video file in project.');
    }

    final opId = _uuid.v4();
    late final List<FfmpegJob> jobs;
    try {
      jobs = CommandMapper.mapOperations(
        EditOperationSet(
          operations: [
            EditOperationRequest(
              id: opId,
              type: 'overlay_text',
              targetClipId: clipId,
              params: params,
            ),
          ],
          summary: 'Manual text overlay',
        ),
        clipPathMap,
        project.outputDir,
        defaultPath: defaultPath,
      );
    } catch (e) {
      return ManualCutResult.fail('Could not map the text overlay: $e');
    }
    if (jobs.length != 1) {
      return ManualCutResult.fail(
        'Overlay mapping produced ${jobs.length} jobs; expected 1.',
      );
    }

    final engine = ExecutionEngine(_ref.read(ffmpegServiceProvider));
    try {
      final result = await engine.execute(jobs, '');
      if (!result.success) {
        return ManualCutResult.fail(
          'FFmpeg failed: ${result.errorMessage ?? result.summary}',
        );
      }
      final outputPath = result.outputPaths.isNotEmpty
          ? result.outputPaths.first
          : jobs.first.outputPath;
      await _ref.read(agentEditApplierProvider).apply(
            EditOperation(
              id: opId,
              type: EditOperationType.overlayText,
              targetClipIds: [clipId],
              params: Map<String, dynamic>.from(params),
              createdAt: DateTime.now(),
              ffmpegCommand: jobs.first.args.join(' '),
            ),
            outputPath,
          );
      return ManualCutResult.okWith(outputPath, 'Text overlay applied.');
    } finally {
      engine.dispose();
    }
  }

  /// Layer [soundSource] over [clipId]'s audio via the `add_sound` op.
  ///
  /// Sound-source convention (auto-detect, no extra flag needed): when
  /// [soundSource] is a known procedural preset id
  /// (`ProceduralSoundService.isKnownPreset`), it is rendered to a temp wav
  /// first; otherwise it is treated as a local file path (the frontend
  /// passes the file_picker result), which must exist — `..` traversal is
  /// rejected. The clip is probed via `ffprobeService`: clips with audio
  /// mix (`amix`), clips without map the sound as the only track.
  Future<ManualCutResult> submitSound({
    required String clipId,
    required String soundSource,
    double volume = 1.0,
  }) async {
    if (!volume.isFinite || volume < 0) {
      return ManualCutResult.fail(
        'Volume must be a non-negative number. Got "$volume".',
      );
    }
    final target = _resolveTarget(clipId);
    if (target.failure != null) {
      return ManualCutResult.fail(target.failure!);
    }
    final project = target.project!;
    final clip = target.clip!;

    final String soundPath;
    if (ProceduralSoundService.isKnownPreset(soundSource)) {
      final generated = await _ref
          .read(proceduralSoundServiceProvider)
          .generate(soundSource);
      if (generated == null) {
        return ManualCutResult.fail(
          'Could not generate sound "$soundSource". '
          'Check the FFmpeg installation and retry.',
        );
      }
      soundPath = generated;
    } else {
      if (soundSource.contains('..')) {
        return ManualCutResult.fail(
          'Invalid sound path (path traversal is not allowed).',
        );
      }
      if (!File(soundSource).existsSync()) {
        return ManualCutResult.fail(
          'Sound file not found: "$soundSource". Pick an audio file or a '
          'built-in preset '
          '(${ProceduralSoundService.presets.map((p) => p.id).join(', ')}).',
        );
      }
      soundPath = soundSource;
    }

    final clipPathMap = _clipPathMap(project);
    final clipPath = clip.sourcePath.trim().isNotEmpty
        ? clip.sourcePath
        : _defaultPath(project, clipPathMap);
    if (clipPath == null) {
      return ManualCutResult.fail('No video file in project.');
    }
    // Unverified probe degrades to mixing (fail-loud) rather than the
    // one-sided path, which would silently drop existing clip audio.
    final metadata =
        await _ref.read(ffprobeServiceProvider).extractMetadata(clipPath);
    final hasClipAudio = metadata?.hasAudio ?? true;

    final params = <String, dynamic>{
      'sound_path': soundPath,
      'volume': volume,
      'has_clip_audio': hasClipAudio,
    };
    final opId = _uuid.v4();
    late final List<FfmpegJob> jobs;
    try {
      jobs = CommandMapper.mapOperations(
        EditOperationSet(
          operations: [
            EditOperationRequest(
              id: opId,
              type: 'add_sound',
              targetClipId: clipId,
              params: params,
            ),
          ],
          summary: 'Manual sound layer',
        ),
        clipPathMap,
        project.outputDir,
        defaultPath: clipPath,
      );
    } catch (e) {
      return ManualCutResult.fail('Could not map the sound layer: $e');
    }
    if (jobs.length != 1) {
      return ManualCutResult.fail(
        'Sound mapping produced ${jobs.length} jobs; expected 1.',
      );
    }

    final engine = ExecutionEngine(_ref.read(ffmpegServiceProvider));
    try {
      final result = await engine.execute(jobs, '');
      if (!result.success) {
        return ManualCutResult.fail(
          'FFmpeg failed: ${result.errorMessage ?? result.summary}',
        );
      }
      final outputPath = result.outputPaths.isNotEmpty
          ? result.outputPaths.first
          : jobs.first.outputPath;
      await _ref.read(agentEditApplierProvider).apply(
            EditOperation(
              id: opId,
              type: EditOperationType.addSound,
              targetClipIds: [clipId],
              params: Map<String, dynamic>.from(params),
              createdAt: DateTime.now(),
              ffmpegCommand: jobs.first.args.join(' '),
            ),
            outputPath,
          );
      return ManualCutResult.okWith(outputPath, 'Sound added.');
    } finally {
      engine.dispose();
    }
  }

  /// Trim [clipId] to the LOCAL source range `[startMs, endMs)` through
  /// the structural applier (`trimClip`: in/out validation, the
  /// original-range outward limits, and the repin ripple live in the
  /// backend use case — no FFmpeg, no output file).
  ///
  /// Time convention: [startMs]/[endMs] are LOCAL source times — the
  /// clip's new in/out points, i.e. what the trim handles drag. (This
  /// differs from [submitSplit], which takes PROJECT time straight from
  /// the playhead.)
  Future<ManualCutResult> submitTrim({
    required String clipId,
    required int startMs,
    required int endMs,
  }) async {
    final target = _resolveTarget(clipId);
    if (target.failure != null) {
      return ManualCutResult.fail(target.failure!);
    }
    if (startMs >= endMs) {
      return ManualCutResult.fail(
        'Invalid trim range [$startMs, $endMs): start must be before end.',
      );
    }
    final applied = await _ref.read(structuralEditApplierProvider).apply(
          EditOperation(
            id: _uuid.v4(),
            type: EditOperationType.trimClip,
            targetClipIds: [clipId],
            params: {
              'clip_id': clipId,
              'start_ms': startMs,
              'end_ms': endMs,
            },
            createdAt: DateTime.now(),
          ),
        );
    if (!applied) {
      return ManualCutResult.fail(
        'Could not trim clip "$clipId" to [$startMs, $endMs): the range is '
        'invalid or outside the clip. Adjust the trim handles and retry.',
      );
    }
    return ManualCutResult.okStructural('Trimmed clip "$clipId".');
  }

  /// Split [clipId] at the playhead through the structural applier
  /// (`splitClip`: ≥50ms from the edges, two clips sharing the source,
  /// repin — all in the backend use case; no FFmpeg, no output file).
  ///
  /// Time convention: [atProjectMs] is PROJECT timeline time — the
  /// playhead position, passed straight through by the frontend. The
  /// controller converts to the SOURCE split point
  /// (`atProjectMs − clip.positionMs + clip.startMs`) for the
  /// `at_local_ms` op param.
  Future<ManualCutResult> submitSplit({
    required String clipId,
    required int atProjectMs,
  }) async {
    final target = _resolveTarget(clipId);
    if (target.failure != null) {
      return ManualCutResult.fail(target.failure!);
    }
    final clip = target.clip!;
    final spanStart = clip.positionMs;
    final spanEnd = clip.positionMs + (clip.endMs - clip.startMs);
    if (atProjectMs <= spanStart || atProjectMs >= spanEnd) {
      return ManualCutResult.fail(
        'Cannot split clip "$clipId" at ${atProjectMs}ms: outside the clip '
        '($spanStart–$spanEnd). Move the playhead over the clip and retry.',
      );
    }
    final applied = await _ref.read(structuralEditApplierProvider).apply(
          EditOperation(
            id: _uuid.v4(),
            type: EditOperationType.splitClip,
            targetClipIds: [clipId],
            params: {
              'clip_id': clipId,
              'at_local_ms': atProjectMs - spanStart + clip.startMs,
            },
            createdAt: DateTime.now(),
          ),
        );
    if (!applied) {
      return ManualCutResult.fail(
        'Could not split clip "$clipId" at the playhead: too close to the '
        'clip edges (splits need 50ms each side). Nudge the playhead and '
        'retry.',
      );
    }
    return ManualCutResult.okStructural(
      'Split clip "$clipId" at the playhead.',
    );
  }

  /// Journal type for a recipe step op. Null when the recipe references an
  /// op outside the preset contract (`apply_effect`/`adjust_brightness`).
  static EditOperationType? _recipeJournalType(String opType) {
    switch (opType) {
      case 'apply_effect':
        return EditOperationType.applyEffect;
      case 'adjust_brightness':
        return EditOperationType.adjustBrightness;
      default:
        return null;
    }
  }

  /// Open-project + clip lookup shared by the panel submits.
  ({Project? project, Clip? clip, String? failure}) _resolveTarget(
    String clipId,
  ) {
    final project = _ref.read(projectProvider).valueOrNull;
    if (project == null) {
      return (
        project: null,
        clip: null,
        failure: 'No project open. Open a project first.',
      );
    }
    final clip = _findClip(project, clipId);
    if (clip == null) {
      return (
        project: project,
        clip: null,
        failure: 'Unknown clip "$clipId". Select a timeline clip and retry.',
      );
    }
    return (project: project, clip: clip, failure: null);
  }

  /// Clip-id → source-file map for `CommandMapper`.
  static Map<String, String> _clipPathMap(Project project) {
    final clipPathMap = <String, String>{};
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        if (clip.sourcePath.trim().isNotEmpty) {
          clipPathMap[clip.id] = clip.sourcePath;
        }
      }
    }
    return clipPathMap;
  }

  /// Fallback input file for `CommandMapper` (project source, else any
  /// clip path).
  static String? _defaultPath(
    Project project,
    Map<String, String> clipPathMap,
  ) {
    if (project.sourceMediaPaths.isNotEmpty) {
      return project.sourceMediaPaths.first;
    }
    return clipPathMap.values.isNotEmpty
        ? clipPathMap.values.first
        : null;
  }

  /// Clip lookup by id across all tracks.
  Clip? _findClip(Project project, String clipId) {
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        if (clip.id == clipId) return clip;
      }
    }
    return null;
  }

  /// Milliseconds → decimal seconds for `between(t, …)`.
  static String _toSeconds(int ms) => (ms / 1000).toStringAsFixed(3);
}

final manualEditControllerProvider = Provider<ManualEditController>((ref) {
  return ManualEditController(ref);
});
