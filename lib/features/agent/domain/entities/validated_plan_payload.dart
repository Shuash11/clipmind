import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';

/// Local candidate data produced only after command validation and execution.
/// Deliberately has no JSON conversion because it must never cross to a model.
final class ValidatedPlanPayload {
  ValidatedPlanPayload({
    required Iterable<ProjectCommand> commands,
    required this.candidateState,
    required Iterable<CanonicalCommandSummary> summaries,
  }) : commands = List<ProjectCommand>.unmodifiable(commands),
       summaries = List<CanonicalCommandSummary>.unmodifiable(summaries);

  final List<ProjectCommand> commands;
  final ProjectStateSnapshot candidateState;
  final List<CanonicalCommandSummary> summaries;
}
