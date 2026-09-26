import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/state/settings_providers.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return ProjectRepository(db);
});

final projectProvider = StateNotifierProvider<ProjectNotifier, AsyncValue<Project?>>((ref) {
  return ProjectNotifier();
});

final recentProjectsProvider = FutureProvider<List<Project>>((ref) async {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.listRecent();
});

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
  void applyEdit(EditOperation operation, String newSourcePath) {
    final project = state.valueOrNull;
    if (project == null) return;

    final targets = operation.targetClipIds.isNotEmpty
        ? operation.targetClipIds
        : const ['_default'];

    final updatedTracks = project.tracks.map((track) {
      final updatedClips = track.clips.map((clip) {
        final matches = targets.contains(clip.id) ||
            (targets.contains('_default') && _isFirstClip(project, clip.id));
        if (!matches) return clip;
        return clip.copyWith(sourcePath: newSourcePath);
      }).toList();
      return track.copyWith(clips: updatedClips);
    }).toList();

    state = AsyncValue.data(project.copyWith(
      tracks: updatedTracks,
      editHistory: [...project.editHistory, operation],
      updatedAt: DateTime.now(),
    ));
  }

  bool _isFirstClip(Project project, String clipId) {
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        return clip.id == clipId;
      }
    }
    return false;
  }
}
