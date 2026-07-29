import '../entities/project_document.dart';
import 'project_file_write_outcome.dart';

export 'project_file_write_outcome.dart';

final class ProjectSaveOutcome {
  ProjectSaveOutcome({
    required this.document,
    List<ProjectSaveWarning> warnings = const [],
  }) : warnings = List.unmodifiable(warnings);
  final ProjectDocument document;
  final List<ProjectSaveWarning> warnings;
}
