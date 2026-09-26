// The public dependency names intentionally map to private stored fields.
// ignore_for_file: prefer_initializing_formals

import 'package:clipmind/core/results/result.dart';

import '../domain/commands/project_command_executor.dart';
import '../domain/commands/project_command_factory.dart';
import '../domain/entities/project_document.dart';
import '../domain/transactions/edit_transaction.dart';
import '../domain/transactions/project_transaction_gateway.dart';
import '../domain/commands/project_command.dart';

final class TimelineProjectController {
  const TimelineProjectController({
    required ProjectCommandFactory factory,
    required ProjectTransactionGateway transactions,
    required ProjectDocument document,
  }) : _factory = factory,
       _transactions = transactions,
       _document = document;

  final ProjectCommandFactory _factory;
  final ProjectTransactionGateway _transactions;
  final ProjectDocument _document;

  Future<void> removeRange({
    required String clipId,
    required int startMs,
    required int endMs,
  }) async {
    final command = _factory.removeClipRange(
      clipId: clipId,
      startMs: startMs,
      endMs: endMs,
    );
    final result = ProjectCommandExecutor.standard().applyAll(
      _document.currentState,
      [command],
    );
    if (result case Success<CommandExecution>(:final value)) {
      await _transactions.apply(
        EditTransaction(
          planId: 'manual-$clipId-$startMs-$endMs',
          expectedRevision: _document.revision,
          beforeState: _document.currentState,
          candidateState: value.candidateState,
          commands: [command],
          summaries: value.summaries,
          sourceKind: TransactionSourceKind.manual,
        ),
      );
    }
  }
}
