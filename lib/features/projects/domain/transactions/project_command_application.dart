import '../commands/project_command.dart';
import 'project_save_outcome.dart';

/// Result of one successfully applied command batch: the validated
/// [CommandExecution] (candidate state + canonical summaries) plus the
/// persisted [ProjectSaveOutcome].
///
/// Shared by the manual tagging path (which consumes the save outcome)
/// and the agent gateway (which surfaces the execution to the tool
/// result) so both go through one validate → persist sequence.
final class ProjectCommandApplication {
  const ProjectCommandApplication({
    required this.execution,
    required this.outcome,
  });

  final CommandExecution execution;
  final ProjectSaveOutcome outcome;
}
