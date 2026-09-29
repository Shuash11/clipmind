import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
import 'package:clipmind/domain/agent/stage_6_execution.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/project_providers.dart';

/// Typed outcome of a manual cut (mirrors the `SubmitResult` pattern).
class ManualCutResult {
  final bool success;
  final String message;
  final String? outputPath;

  const ManualCutResult({
    required this.success,
    required this.message,
    this.outputPath,
  });

  factory ManualCutResult.ok(String outputPath) => ManualCutResult(
        success: true,
        message: 'Cut applied.',
        outputPath: outputPath,
      );

  factory ManualCutResult.fail(String message) => ManualCutResult(
        success: false,
        message: message,
      );
}

/// Manual-FFmpeg cut controller (D4): single `cut_segment` op executed
/// through the existing `CommandMapper` → `ExecutionEngine` →
/// `agentEditApplierProvider` chain, so the cut is undoable, journaled
/// and persisted exactly like an agent edit.
///
/// Package C reads `ref.read(manualEditControllerProvider)` and calls
/// [submitCut] with plain params (clip id + timeline ruler times); the
/// controller validates, converts to clip-local times and builds the op.
/// No presentation types cross this boundary.
class ManualEditController {
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  const ManualEditController(this._ref);

  /// Cut out `[startMs, endMs)` (timeline ruler times) from [clipId].
  Future<ManualCutResult> submitCut({
    required String clipId,
    required int startMs,
    required int endMs,
  }) async {
    final project = _ref.read(projectProvider).valueOrNull;
    if (project == null) {
      return ManualCutResult.fail('No project open. Open a project first.');
    }

    final target = _findClip(project, clipId);
    if (target == null) {
      return ManualCutResult.fail(
        'Unknown clip "$clipId". Select a timeline clip and retry.',
      );
    }
    final spanStart = target.positionMs;
    final spanEnd =
        target.positionMs + (target.endMs - target.startMs);
    if (startMs < spanStart || endMs > spanEnd || startMs >= endMs) {
      return ManualCutResult.fail(
        'Invalid cut range [$startMs, $endMs): must lie inside clip '
        '"$clipId" ($spanStart–$spanEnd) with start before end.',
      );
    }
    final localStart = startMs - spanStart;
    final localEnd = endMs - spanStart;

    final opId = _uuid.v4();
    final params = {
      'remove_start': _toSeconds(localStart),
      'remove_end': _toSeconds(localEnd),
    };
    final clipPathMap = <String, String>{};
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        if (clip.sourcePath.trim().isNotEmpty) {
          clipPathMap[clip.id] = clip.sourcePath;
        }
      }
    }
    final defaultPath = project.sourceMediaPaths.isNotEmpty
        ? project.sourceMediaPaths.first
        : (clipPathMap.values.isNotEmpty ? clipPathMap.values.first : null);
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
