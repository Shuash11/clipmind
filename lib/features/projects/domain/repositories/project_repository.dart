import 'package:clipmind/core/results/result.dart';
import '../entities/project_document.dart';
import '../transactions/project_save_outcome.dart';

abstract interface class ProjectRepository {
  Future<Result<ProjectSaveOutcome>> save(ProjectDocument candidate);
  Future<Result<ProjectSaveOutcome>> load(String path);
}

abstract interface class ProjectIndex {
  Future<void> upsert(ProjectDocument document);
  Future<void> clear();
  Future<List<String>> projectPaths();
}
