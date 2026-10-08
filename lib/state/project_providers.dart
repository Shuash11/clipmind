import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/domain/usecases/structural_edit_usecase.dart';
import 'package:clipmind/state/settings_providers.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return ProjectRepository(db);
});

final projectProvider =
    StateNotifierProvider<ProjectNotifier, AsyncValue<Project?>>((ref) {
      return ProjectNotifier();
    });

final recentProjectsProvider = FutureProvider<List<Project>>((ref) async {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.listRecent();
});

/// Honest record of the last failed project save.
class ProjectSaveFailure {
  const ProjectSaveFailure({required this.message, required this.failedAt});

  /// User-facing explanation of why the save failed.
  final String message;

  /// When the failure was observed.
  final DateTime failedAt;
}

/// The last failed project save, or null when persistence is known-healthy.
/// Cleared by the next successful save.
final projectSaveFailureProvider = StateProvider<ProjectSaveFailure?>(
  (ref) => null,
);

/// Single save entry point: persists [project] through
/// [projectRepositoryProvider] and records the outcome in
/// [projectSaveFailureProvider] instead of swallowing failures.
///
/// Returns true when the project was durably saved; false when the save
/// failed, with [ProjectSaveFailure.message] carrying the reason (the
/// repository's `PersistenceFailure.message`, or a generic fallback for any
/// other error type).
Future<bool> persistProject(Ref ref, Project project) async {
  try {
    await ref.read(projectRepositoryProvider).save(project);
    ref.read(projectSaveFailureProvider.notifier).state = null;
    return true;
  } on PersistenceFailure catch (e) {
    _recordSaveFailure(ref, e.message);
    return false;
  } catch (_) {
    _recordSaveFailure(ref, _genericSaveFailureMessage);
    return false;
  }
}

/// [persistProject] bound to a provider [Ref], for callers that hold a
/// `WidgetRef` instead (e.g. timeline manual edits).
final persistProjectProvider = Provider<Future<bool> Function(Project)>(
  (ref) => (project) => persistProject(ref, project),
);

void _recordSaveFailure(Ref ref, String message) {
  ref.read(projectSaveFailureProvider.notifier).state = ProjectSaveFailure(
    message: message,
    failedAt: DateTime.now(),
  );
}

const _genericSaveFailureMessage = 'The project could not be saved to disk.';

class ProjectNotifier extends StateNotifier<AsyncValue<Project?>> {
  ProjectNotifier() : super(const AsyncValue.data(null));

  void setProject(Project project) {
    state = AsyncValue.data(project);
  }

  void clearProject() {
    state = const AsyncValue.data(null);
  }

  /// Single mutation path for AI (and future manual) edits.
  ///
  /// Appends [operation] to [Project.editHistory] and points the affected
  /// clip(s) at [newSourcePath] so [TimelineView] (which watches
  /// [projectProvider]) re-renders immediately.
  ///
  /// [removeClipIds] drops the listed clips from their tracks (pair
  /// replacement for `add_transition` / fixed `merge_clips`: the first clip
  /// is repointed at the merged output, the rest are removed). Removed
  /// clips are NOT restored by undo (null-inverse in the domain); the
  /// [Project.editHistory] row keeps `clip_ids` traceability.
  ///
  /// Range normalization (the post-cut stale-range fix): cut/trim ops carry
  /// the additive `new_start_ms`/`new_end_ms` params (computed by the
  /// executor — and by `ManualEditController.submitCut` for the manual
  /// path — from the new output file's length). The repointed clip's
  /// `startMs`/`endMs` are replaced from those params instead of staying
  /// stale against the shorter output file, so the display duration, the
  /// `list_project_clips` model view, and subsequent cut mappings all see
  /// the true range. Absent (or unparseable) keys mean no range update —
  /// every other op repoints exactly as before. Normalized clips land on
  /// `startMs = 0`, which unifies the local→file time mapping
  /// (`fileTime = clip.startMs + local`) for every clip state.
  ///
  /// Cut repin (the timeline/export agreement): a range update shortens
  /// the clip, so the follower positions computed from the original
  /// lengths would leave gaps/overlaps. Tracks with a range-updated clip
  /// are repinned cumulatively from 0 (mirroring the structural ripple),
  /// while tracks without one keep their positions untouched.
  void applyEdit(
    EditOperation operation,
    String newSourcePath, {
    List<String> removeClipIds = const [],
  }) {
    final project = state.value;
    if (project == null) return;

    final targets = operation.targetClipIds.isNotEmpty
        ? operation.targetClipIds
        : const ['_default'];
    final newRange = _newRange(operation);

    final updatedTracks = project.tracks.map((track) {
      final updatedClips = <Clip>[];
      var rangeUpdated = false;
      for (final clip in track.clips) {
        if (removeClipIds.contains(clip.id)) continue;
        final matches = targets.contains(clip.id) ||
            (targets.contains('_default') && _isFirstClip(project, clip.id));
        if (!matches) {
          updatedClips.add(clip);
          continue;
        }
        if (newRange != null) {
          rangeUpdated = true;
          updatedClips.add(clip.copyWith(
            sourcePath: newSourcePath,
            startMs: newRange.$1,
            endMs: newRange.$2,
          ));
        } else {
          updatedClips.add(clip.copyWith(sourcePath: newSourcePath));
        }
      }
      // The wiring applies the repin when the op carries a range update.
      return track.copyWith(
        clips: rangeUpdated ? _repinned(updatedClips) : updatedClips,
      );
    }).toList();

    state = AsyncValue.data(project.copyWith(
      tracks: updatedTracks,
      editHistory: [...project.editHistory, operation],
      updatedAt: DateTime.now(),
    ));
  }

  /// Local structural mutation (delete/copy/move): no FFmpeg, no repoint.
  ///
  /// Runs the pure [StructuralEditUseCase] transform, replaces the project
  /// state and appends [operation] to [Project.editHistory]. Returns false
  /// (graceful no-op, state untouched) for unknown clips or non-structural
  /// op types. Mirrors [applyEdit]'s state update + timestamp.
  bool applyStructuralEdit(EditOperation operation) {
    final project = state.value;
    if (project == null) return false;

    final updated =
        const StructuralEditUseCase().apply(operation, project);
    if (updated == null) return false;

    state = AsyncValue.data(updated.copyWith(
      editHistory: [...updated.editHistory, operation],
      updatedAt: DateTime.now(),
    ));
    return true;
  }

  /// The `(startMs, endMs)` carried by cut/trim op params, or null when
  /// the keys are absent (no range update — all other ops) or fail closed
  /// (unparseable, negative, or inverted). Mirrors the backend's
  /// `_trimNewRange`/`_cutNewRange` omit-when-invalid contract.
  (int, int)? _newRange(EditOperation operation) {
    if (!operation.params.containsKey('new_start_ms') ||
        !operation.params.containsKey('new_end_ms')) {
      return null;
    }
    final startMs = _asInt(operation.params['new_start_ms']);
    final endMs = _asInt(operation.params['new_end_ms']);
    if (startMs == null || endMs == null) return null;
    if (startMs < 0 || endMs < startMs) return null;
    return (startMs, endMs);
  }

  /// Timeline-pin clips cumulatively from 0 (mirrors the structural
  /// use case's repin ripple).
  List<Clip> _repinned(List<Clip> clips) {
    var position = 0;
    final pinned = <Clip>[];
    for (final clip in clips) {
      pinned.add(clip.copyWith(positionMs: position));
      final duration = clip.endMs - clip.startMs;
      position += duration < 0 ? 0 : duration;
    }
    return pinned;
  }

  int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.isFinite ? value.toInt() : null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool _isFirstClip(Project project, String clipId) {
    return _firstClipId(project) == clipId;
  }

  /// The very first clip across all tracks (track order, then clip order),
  /// or null when the project has no clips.
  String? _firstClipId(Project project) {
    for (final track in project.tracks) {
      if (track.clips.isNotEmpty) {
        return track.clips.first.id;
      }
    }
    return null;
  }
}
