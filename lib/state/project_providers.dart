import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/models/project.dart';
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
}
