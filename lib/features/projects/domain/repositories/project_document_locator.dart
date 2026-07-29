import '../entities/project_document.dart';

abstract interface class ProjectDocumentLocator {
  Future<List<String>> listProjectPaths();
  Future<ProjectDocument> readDocument(String path);
}
