// The public dependency names intentionally map to private stored fields.
// ignore_for_file: prefer_initializing_formals

import 'package:clipmind/core/results/result.dart';

import '../entities/persisted_transaction_record.dart';
import '../entities/project_document.dart';
import '../repositories/project_repository.dart';
import 'edit_transaction.dart';
import 'project_document_publisher.dart';
import 'project_save_outcome.dart';

final class ProjectTransactionService {
  ProjectTransactionService({
    required ProjectRepository repository,
    required ProjectDocumentPublisher publisher,
    required DateTime Function() now,
  }) : _repository = repository,
       _publisher = publisher,
       _now = now;

  final ProjectRepository _repository;
  final ProjectDocumentPublisher _publisher;
  final DateTime Function() _now;

  Future<Result<ProjectSaveOutcome>> apply(
    ProjectDocument current,
    EditTransaction transaction,
  ) async {
    if (current.revision != transaction.expectedRevision ||
        current.currentState != transaction.beforeState) {
      return const Failure(
        ProjectValidationFailure('Stale project transaction'),
      );
    }
    final retained = current.history.take(current.historyCursor + 1).toList();
    final record = PersistedTransactionRecord(
      planId: transaction.planId,
      beforeState: transaction.beforeState,
      afterState: transaction.candidateState,
      commands: transaction.summaries,
      appliedAt: _now(),
      sourceKind: transaction.sourceKind,
    );
    final candidate = current.copyWith(
      currentState: transaction.candidateState,
      revision: current.revision + 1,
      history: [...retained, record],
      historyCursor: retained.length,
      updatedAt: _now(),
    );
    return _saveAndPublish(candidate);
  }

  Future<Result<ProjectSaveOutcome>> undo(ProjectDocument current) async {
    if (current.historyCursor < 0) {
      return const Failure(ProjectValidationFailure('Nothing to undo'));
    }
    final record = current.history[current.historyCursor];
    return _saveAndPublish(
      current.copyWith(
        currentState: record.beforeState,
        revision: current.revision + 1,
        historyCursor: current.historyCursor - 1,
        updatedAt: _now(),
      ),
    );
  }

  Future<Result<ProjectSaveOutcome>> redo(ProjectDocument current) async {
    final next = current.historyCursor + 1;
    if (next >= current.history.length) {
      return const Failure(ProjectValidationFailure('Nothing to redo'));
    }
    final record = current.history[next];
    return _saveAndPublish(
      current.copyWith(
        currentState: record.afterState,
        revision: current.revision + 1,
        historyCursor: next,
        updatedAt: _now(),
      ),
    );
  }

  Future<Result<ProjectSaveOutcome>> _saveAndPublish(
    ProjectDocument candidate,
  ) async {
    final result = await _repository.save(candidate);
    if (result case Success<ProjectSaveOutcome>(:final value)) {
      _publisher.publish(value.document, warnings: value.warnings);
    }
    return result;
  }
}
