import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/transactions/edit_transaction.dart';
import 'package:clipmind/features/projects/domain/transactions/project_command_application.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:clipmind/features/projects/domain/transactions/project_transaction_service.dart';
import 'package:clipmind/features/tagging/domain/marker_filter.dart';
import 'package:clipmind/features/tagging/domain/tag_query.dart';
import 'package:clipmind/features/tagging/domain/tagging_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final tagQueryProvider = StateProvider<TagQuery>((ref) => TagQuery());

final markerFilterProvider = StateProvider<MarkerFilter>(
  (ref) => MarkerFilter(),
);

final selectedAssetIdProvider = StateProvider<String?>((ref) => null);

final taggingProvidersProvider = Provider<TaggingProviders?>((ref) => null);

final class TaggingProviders {
  factory TaggingProviders({
    required TaggingController controller,
    required ProjectDocument? Function() currentDocument,
    required ProjectTransactionService transactions,
    required String Function() manualTransactionId,
  }) => TaggingProviders._(
    controller: controller,
    currentDocument: currentDocument,
    transactions: transactions,
    manualTransactionId: manualTransactionId,
  );

  const TaggingProviders._({
    required this.controller,
    required this._currentDocument,
    required this._transactions,
    required this._manualTransactionId,
  });

  final TaggingController controller;
  final ProjectDocument? Function() _currentDocument;
  final ProjectTransactionService _transactions;
  final String Function() _manualTransactionId;

  ProjectDocument? get document => _currentDocument();

  /// Shared validate → persist sequence for manual and agent command
  /// batches — one mutation path for tagging. [applyManual] (the tagging
  /// widgets) records [TransactionSourceKind.manual]; the agent command
  /// gateway records [TransactionSourceKind.agent] and consumes the
  /// [ProjectCommandApplication.execution] for its tool result.
  Future<Result<ProjectCommandApplication>> applyTransaction(
    List<ProjectCommand> commands, {
    required TransactionSourceKind sourceKind,
    required String transactionId,
  }) async {
    final ProjectDocument? current;
    try {
      current = _currentDocument();
    } catch (_) {
      return const Failure(
        ProjectValidationFailure('Unable to read the current project'),
      );
    }
    if (current == null) {
      return const Failure(ProjectValidationFailure('No project is available'));
    }

    final Result<CommandExecution> execution;
    try {
      execution = ProjectCommandExecutor.standard().applyAll(
        current.currentState,
        commands,
      );
    } catch (_) {
      return const Failure(
        ProjectValidationFailure('Unable to validate project transaction'),
      );
    }
    if (execution case Failure<CommandExecution>(:final error)) {
      return Failure(error);
    }

    final applied = (execution as Success<CommandExecution>).value;
    final Result<ProjectSaveOutcome> saved;
    try {
      saved = await _transactions.apply(
        current,
        EditTransaction(
          planId: transactionId,
          expectedRevision: current.revision,
          beforeState: current.currentState,
          candidateState: applied.candidateState,
          commands: commands,
          summaries: applied.summaries,
          sourceKind: sourceKind,
        ),
      );
    } catch (_) {
      return const Failure(
        ProjectValidationFailure('Unable to apply project transaction'),
      );
    }
    return switch (saved) {
      Success<ProjectSaveOutcome>(:final value) => Success(
        ProjectCommandApplication(execution: applied, outcome: value),
      ),
      Failure<ProjectSaveOutcome>(:final error) => Failure(error),
    };
  }

  /// Apply one manual command batch (tagging widgets) through the shared
  /// sequence; the returned save outcome is unused by callers but keeps
  /// the manual contract explicit.
  Future<Result<ProjectSaveOutcome>> applyManual(ProjectCommand command) async {
    final result = await applyTransaction(
      [command],
      sourceKind: TransactionSourceKind.manual,
      transactionId: _manualTransactionId(),
    );
    return switch (result) {
      Success<ProjectCommandApplication>(:final value) =>
        Success(value.outcome),
      Failure<ProjectCommandApplication>(:final error) => Failure(error),
    };
  }
}
