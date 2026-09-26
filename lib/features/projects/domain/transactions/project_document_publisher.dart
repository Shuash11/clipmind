import '../entities/project_document.dart';
import 'project_file_write_outcome.dart';

abstract interface class ProjectDocumentPublisher {
  void publish(
    ProjectDocument document, {
    List<ProjectSaveWarning> warnings = const [],
  });
}
