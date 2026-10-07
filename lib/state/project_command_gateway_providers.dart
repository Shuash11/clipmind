import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/domain/agent/tools/project_command_gateway.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';
import 'package:clipmind/features/projects/domain/transactions/project_command_application.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Single wiring point for agent tag/marker commands (mirrors
/// `agentEditApplierProvider`): the domain [ProjectCommandGateway] backed
/// by the live tagging document + transaction service the editor supplies
/// through [taggingProvidersProvider]. Null when no tagging wiring exists,
/// so command tools fail actionably instead of guessing an editor.
final projectCommandGatewayProvider = Provider<ProjectCommandGateway?>((ref) {
  final providers = ref.watch(taggingProvidersProvider);
  if (providers == null) return null;
  return TaggingProjectCommandGateway(providers, const Uuid().v4);
});

/// Adapts the editor-supplied tagging composition to the domain port:
/// reads the live snapshot for the reader tool and applies command batches
/// through [TaggingProviders.applyTransaction] with agent-sourced
/// transactions (undo, revision guard, DB/file persistence all shared with
/// the manual path).
final class TaggingProjectCommandGateway implements ProjectCommandGateway {
  TaggingProjectCommandGateway(this._providers, this._nextTransactionId);

  final TaggingProviders _providers;
  final String Function() _nextTransactionId;

  @override
  ProjectStateSnapshot? snapshot() {
    try {
      return _providers.document?.currentState;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Result<CommandExecution>> applyCommands(
    List<ProjectCommand> commands,
  ) async {
    final result = await _providers.applyTransaction(
      commands,
      sourceKind: TransactionSourceKind.agent,
      transactionId: _nextTransactionId(),
    );
    return switch (result) {
      Success<ProjectCommandApplication>(:final value) =>
        Success(value.execution),
      Failure<ProjectCommandApplication>(:final error) => Failure(error),
    };
  }
}
