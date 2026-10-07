import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/domain/agent/tools/project_command_gateway.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';

/// Fake gateway for executor/loop tests: validates through the real
/// [ProjectCommandExecutor] against an in-memory snapshot, records every
/// batch, and advances the snapshot on success (so sequenced calls like
/// create_tag → assign_tag behave like the live pipeline).
final class FakeProjectCommandGateway implements ProjectCommandGateway {
  FakeProjectCommandGateway({this.state});

  ProjectStateSnapshot? state;
  final List<List<ProjectCommand>> batches = [];
  Result<CommandExecution>? nextResult;

  List<ProjectCommand> get appliedCommands => [
    for (final batch in batches) ...batch,
  ];

  @override
  ProjectStateSnapshot? snapshot() => state;

  @override
  Future<Result<CommandExecution>> applyCommands(
    List<ProjectCommand> commands,
  ) async {
    batches.add(List.unmodifiable(commands));
    final override = nextResult;
    if (override != null) return override;
    final current = state;
    if (current == null) {
      return const Failure(ProjectValidationFailure('No project state'));
    }
    final result = ProjectCommandExecutor.standard().applyAll(
      current,
      commands,
    );
    if (result case Success<CommandExecution>(:final value)) {
      state = value.candidateState;
    }
    return result;
  }
}
