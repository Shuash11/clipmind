import '../commands/project_command.dart';
import '../entities/project_state_snapshot.dart';

final class CommandHandlerResult {
  const CommandHandlerResult({required this.state, required this.summary});

  final ProjectStateSnapshot state;
  final CanonicalCommandSummary summary;
}
