// The public dependency names intentionally map to private stored fields.
// ignore_for_file: prefer_initializing_formals

import '../domain/entities/project_document.dart';
import '../domain/repositories/project_document_locator.dart';
import '../domain/repositories/project_repository.dart';
import '../domain/transactions/project_file_write_outcome.dart';

final class ProjectIndexRepairResult {
  ProjectIndexRepairResult({
    required List<ProjectDocument> documents,
    required List<String> repairedPaths,
    required List<ProjectSaveWarning> warnings,
  }) : documents = List.unmodifiable(documents),
       repairedPaths = List.unmodifiable(repairedPaths),
       warnings = List.unmodifiable(warnings);

  final List<ProjectDocument> documents;
  final List<String> repairedPaths;
  final List<ProjectSaveWarning> warnings;
}

final class ProjectIndexRepairService {
  const ProjectIndexRepairService({
    required ProjectIndex index,
    required ProjectDocumentLocator documents,
  }) : _index = index,
       _documents = documents;

  final ProjectIndex _index;
  final ProjectDocumentLocator _documents;

  Future<ProjectIndexRepairResult> rebuildRecent() async {
    final warnings = <ProjectSaveWarning>[];
    try {
      await _index.clear();
    } catch (_) {
      warnings.add(
        const ProjectIndexWarning(
          'project_index_clear_failed',
          'Drift index clear failed',
        ),
      );
    }
    return _load(initialWarnings: warnings);
  }

  Future<ProjectIndexRepairResult> loadRecent() => _load();

  Future<ProjectIndexRepairResult> _load({
    List<ProjectSaveWarning> initialWarnings = const [],
  }) async {
    final paths = await _documents.listProjectPaths();
    final loaded = <ProjectDocument>[];
    final repaired = <String>[];
    final warnings = <ProjectSaveWarning>[...initialWarnings];
    for (final path in paths) {
      final document = await _documents.readDocument(path);
      loaded.add(document);
      try {
        await _index.upsert(document);
        repaired.add(path);
      } catch (_) {
        warnings.add(
          const ProjectIndexWarning(
            'project_index_upsert_failed',
            'Drift upsert failed',
          ),
        );
      }
    }
    return ProjectIndexRepairResult(
      documents: loaded,
      repairedPaths: repaired,
      warnings: warnings,
    );
  }
}
