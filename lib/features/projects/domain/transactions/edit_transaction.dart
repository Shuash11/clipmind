import '../commands/project_command.dart';
import '../entities/project_state_snapshot.dart';

final class EditTransaction {
  EditTransaction({
    required this.planId,
    required this.expectedRevision,
    required this.beforeState,
    required this.candidateState,
    required List<ProjectCommand> commands,
    required List<CanonicalCommandSummary> summaries,
    required this.sourceKind,
  }) : commands = List.unmodifiable(commands),
       summaries = List.unmodifiable(summaries);

  final String planId;
  final int expectedRevision;
  final ProjectStateSnapshot beforeState;
  final ProjectStateSnapshot candidateState;
  final List<ProjectCommand> commands;
  final List<CanonicalCommandSummary> summaries;
  final TransactionSourceKind sourceKind;
}
