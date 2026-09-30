import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';

/// Pure structural transforms for manual timeline editing.
///
/// `deleteClip` / `copyClip` / `moveClip` / `trimClip` / `splitClip` are
/// LOCAL ops: no FFmpeg job, no sourcePath repoint, never model tools.
/// Package B executes them via the structural applier
/// (`ProjectNotifier.applyStructuralEdit`), which snapshots the pre-edit
/// project for the Phase-1 memento stacks, so undo/DB/history work
/// uniformly.
///
/// Timeline model: a track's clips play sequentially. [moveClip],
/// [trimClip] and [splitClip] recompute `positionMs` cumulatively from 0
/// (ripple); deletion leaves gaps as artifacts (documented, not
/// normalized).
///
/// Trim bounds: the first trim stamps the pre-trim range into the clip's
/// `transformations` map (`original_start_ms` / `original_end_ms`);
/// handles may move outward up to that range, never beyond (growing beyond
/// returns null — undo restores instead).
///
/// Split: the clip becomes `[start, at]` (keeps id + transformations) plus
/// a new clip `[at, end]` (fresh id via the copy-naming pattern,
/// inheriting track/source/transformations). Both clips share the same
/// `sourcePath`; the export slices each clip's range.
///
/// Returns null for unknown clips or non-structural op types (graceful;
/// Package B decides the error surface).
class StructuralEditUseCase {
  const StructuralEditUseCase();

  /// Minimum clip duration and split edge margin. Matches the timeline's
  /// deliberate-selection threshold.
  static const int minClipDurationMs = 50;

  /// `transformations` keys stamping the pre-first-trim source range.
  static const String originalStartKey = 'original_start_ms';
  static const String originalEndKey = 'original_end_ms';

  /// Apply a structural [op] to [project], returning the updated project.
  ///
  /// Op-params API (for the middle-end's submitTrim/submitSplit):
  /// - `trimClip`: `{'clip_id': String, 'start_ms': int, 'end_ms': int}`
  ///   (source offsets replacing the clip's range).
  /// - `splitClip`: `{'clip_id': String, 'at_local_ms': int}` (source
  ///   offset where the clip divides; the second clip gets a fresh id).
  Project? apply(EditOperation op, Project project) {
    switch (op.type) {
      case EditOperationType.deleteClip:
        return _delete(_stringParam(op, 'clip_id'), project);
      case EditOperationType.copyClip:
        return _copy(
          _stringParam(op, 'clip_id'),
          _stringParam(op, 'new_clip_id'),
          project,
        );
      case EditOperationType.moveClip:
        return _move(
          _stringParam(op, 'clip_id'),
          _stringParam(op, 'after_clip_id'),
          project,
        );
      case EditOperationType.trimClip:
        return _trim(
          _stringParam(op, 'clip_id'),
          _intParam(op, 'start_ms'),
          _intParam(op, 'end_ms'),
          project,
        );
      case EditOperationType.splitClip:
        return _split(
          _stringParam(op, 'clip_id'),
          _intParam(op, 'at_local_ms'),
          project,
        );
      default:
        return null;
    }
  }

  Project? _delete(String? clipId, Project project) {
    if (clipId == null || clipId.isEmpty) return null;
    final found = _locate(project, clipId);
    if (found == null) return null;
    // Positions of the remaining clips are left as-is: gaps are
    // deletion artifacts by design.
    final clips = List<Clip>.of(project.tracks[found.$1].clips)
      ..removeAt(found.$2);
    return _withClips(project, found.$1, clips);
  }

  Project? _copy(String? clipId, String? newClipId, Project project) {
    if (clipId == null || clipId.isEmpty) return null;
    final found = _locate(project, clipId);
    if (found == null) return null;
    final original = project.tracks[found.$1].clips[found.$2];
    final id = (newClipId != null && newClipId.isNotEmpty)
        ? newClipId
        : _freshCopyId(project, clipId);
    if (_locate(project, id) != null) return null;
    final copy = original.copyWith(
      id: id,
      positionMs: original.positionMs + _durationMs(original),
    );
    final clips = List<Clip>.of(project.tracks[found.$1].clips)
      ..insert(found.$2 + 1, copy);
    return _withClips(project, found.$1, clips);
  }

  Project? _move(String? clipId, String? afterClipId, Project project) {
    if (clipId == null || clipId.isEmpty) return null;
    final found = _locate(project, clipId);
    if (found == null) return null;
    if (afterClipId == clipId) return project;
    if (afterClipId != null && afterClipId.isNotEmpty) {
      final anchor = _locate(project, afterClipId);
      // The anchor must live on the same track (tracks are typed).
      if (anchor == null || anchor.$1 != found.$1) return null;
    }
    final clips = List<Clip>.of(project.tracks[found.$1].clips);
    final moving = clips.removeAt(found.$2);
    if (afterClipId == null || afterClipId.isEmpty) {
      clips.insert(0, moving);
    } else {
      // Validated above: the anchor is on this track and is not the
      // moved clip, so it survived the removal.
      final anchorIndex = clips.indexWhere((c) => c.id == afterClipId);
      clips.insert(anchorIndex + 1, moving);
    }
    return _withClips(project, found.$1, _repinned(clips));
  }

  /// Local non-destructive trim: replace the clip's source range, then
  /// ripple-pin the track. The first trim stamps the pre-trim range into
  /// `transformations`; later trims may move outward up to it, never
  /// beyond (null = growing beyond the original).
  Project? _trim(
    String? clipId,
    int? startMs,
    int? endMs,
    Project project,
  ) {
    if (clipId == null || clipId.isEmpty) return null;
    if (startMs == null || endMs == null) return null;
    // In/out validation: non-negative source offsets, positive range.
    if (startMs < 0 || endMs <= startMs) return null;
    if (endMs - startMs < minClipDurationMs) return null;
    final found = _locate(project, clipId);
    if (found == null) return null;
    final clip = project.tracks[found.$1].clips[found.$2];
    final origStart = _originalBound(clip, originalStartKey, clip.startMs);
    final origEnd = _originalBound(clip, originalEndKey, clip.endMs);
    if (origStart == null || origEnd == null) return null;
    if (origStart < 0 || origEnd <= origStart) return null;
    // Outward limits: start in [origStart, end-min],
    // end in [start+min, origEnd].
    if (startMs < origStart || endMs > origEnd) return null;
    final updated = clip.copyWith(
      startMs: startMs,
      endMs: endMs,
      transformations: {
        ...clip.transformations,
        originalStartKey: origStart,
        originalEndKey: origEnd,
      },
    );
    final clips = List<Clip>.of(project.tracks[found.$1].clips)
      ..[found.$2] = updated;
    return _withClips(project, found.$1, _repinned(clips));
  }

  /// Local non-destructive split: the clip becomes `[start, at]` (keeps
  /// id + transformations) plus a new clip `[at, end]` (fresh id via the
  /// copy-naming pattern). Both share the clip's `sourcePath`.
  Project? _split(String? clipId, int? atMs, Project project) {
    if (clipId == null || clipId.isEmpty) return null;
    if (atMs == null) return null;
    final found = _locate(project, clipId);
    if (found == null) return null;
    final clip = project.tracks[found.$1].clips[found.$2];
    // Edge margin: the split point must clear both edges.
    if (atMs - clip.startMs < minClipDurationMs) return null;
    if (clip.endMs - atMs < minClipDurationMs) return null;
    final newId = _freshCopyId(project, clipId);
    final first = clip.copyWith(endMs: atMs);
    final second = clip.copyWith(id: newId, startMs: atMs);
    final clips = List<Clip>.of(project.tracks[found.$1].clips)
      ..removeAt(found.$2)
      ..insertAll(found.$2, [first, second]);
    return _withClips(project, found.$1, _repinned(clips));
  }

  /// The stamped original bound, or the live [fallback] on first trim.
  /// Null when the stamped value is corrupt (fail closed).
  int? _originalBound(Clip clip, String key, int fallback) {
    if (!clip.transformations.containsKey(key)) return fallback;
    return _asInt(clip.transformations[key]);
  }

  /// Timeline-pin every clip cumulatively from 0.
  List<Clip> _repinned(List<Clip> clips) {
    var position = 0;
    final pinned = <Clip>[];
    for (final clip in clips) {
      pinned.add(clip.copyWith(positionMs: position));
      position += _durationMs(clip);
    }
    return pinned;
  }

  int _durationMs(Clip clip) {
    final duration = clip.endMs - clip.startMs;
    return duration < 0 ? 0 : duration;
  }

  /// (trackIndex, clipIndex) of a clip id, or null.
  (int, int)? _locate(Project project, String clipId) {
    for (var t = 0; t < project.tracks.length; t++) {
      final clips = project.tracks[t].clips;
      for (var c = 0; c < clips.length; c++) {
        if (clips[c].id == clipId) return (t, c);
      }
    }
    return null;
  }

  String _freshCopyId(Project project, String clipId) {
    var n = 1;
    while (_locate(project, '${clipId}_copy_$n') != null) {
      n++;
    }
    return '${clipId}_copy_$n';
  }

  Project _withClips(Project project, int trackIndex, List<Clip> clips) {
    final tracks = List.of(project.tracks);
    tracks[trackIndex] = tracks[trackIndex].copyWith(clips: clips);
    return project.copyWith(tracks: tracks);
  }

  String? _stringParam(EditOperation op, String key) {
    final value = op.params[key];
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  int? _intParam(EditOperation op, String key) => _asInt(op.params[key]);

  int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.isFinite ? value.toInt() : null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
