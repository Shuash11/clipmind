import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';

/// Agent-facing port for the live project command pipeline (tag/marker
/// tools).
///
/// The domain never imports the state layer: the state layer implements
/// this port on top of the same validate → persist sequence the tagging
/// panel uses for manual edits ([TaggingProviders.applyManual]), so agent
/// and manual edits share one mutation path (undo, revision guard, DB and
/// file persistence) and only the recorded [TransactionSourceKind] differs.
abstract interface class ProjectCommandGateway {
  /// Current project state for the read tool, or null when no live
  /// document is available (no project open / no editor wiring).
  ProjectStateSnapshot? snapshot();

  /// Validate [commands] against the live document and persist them as one
  /// transaction. Returns the validated [CommandExecution] (candidate state
  /// + canonical summaries) on success; the failure carries the project
  /// validation/persistence message for model self-correction.
  Future<Result<CommandExecution>> applyCommands(List<ProjectCommand> commands);
}
