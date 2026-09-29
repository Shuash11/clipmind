import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';

/// Pure structural transforms for manual timeline editing.
///
/// `deleteClip` / `copyClip` / `moveClip` are LOCAL ops: no FFmpeg job,
/// no sourcePath repoint, never model tools. Package B executes them via
/// the structural applier (`ProjectNotifier.applyStructuralEdit`), which
/// snapshots the pre-edit project for the Phase-1 memento stacks, so
/// undo/DB/history work uniformly.
///
/// Timeline model: a track's clips play sequentially. [moveClip]
/// recomputes `positionMs` cumulatively from 0; deletion leaves gaps as
/// artifacts (documented, not normalized).
///
/// Returns null for unknown clips or non-structural op types (graceful;
/// Package B decides the error surface).
class StructuralEditUseCase {
  const StructuralEditUseCase();

  /// Apply a structural [op] to [project], returning the updated project.
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
}
