import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/transactions/edit_transaction.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:clipmind/features/projects/domain/transactions/project_transaction_service.dart';

/// Narrow agent boundary: the project layer remains responsible for persistence
/// and publication, while agent presentation code cannot access either directly.
abstract interface class EditPlanTransactionGateway {
  ProjectDocument? get currentDocument;
  Future<Result<ProjectSaveOutcome>> apply(
    ProjectDocument expectedDocument,
    EditTransaction transaction,
  );
}

final class ProjectTransactionEditPlanGateway
    implements EditPlanTransactionGateway {
  factory ProjectTransactionEditPlanGateway({
    required ProjectTransactionService service,
    required ProjectDocument? Function() currentDocumentReader,
  }) => ProjectTransactionEditPlanGateway._(service, currentDocumentReader);

  ProjectTransactionEditPlanGateway._(
    this._service,
    this._currentDocumentReader,
  );

  final ProjectTransactionService _service;
  final ProjectDocument? Function() _currentDocumentReader;

  @override
  ProjectDocument? get currentDocument => _currentDocumentReader();

  @override
  Future<Result<ProjectSaveOutcome>> apply(
    ProjectDocument expectedDocument,
    EditTransaction transaction,
  ) async {
    final current = _currentDocumentReader();
    if (current == null) {
      return const Failure<ProjectSaveOutcome>(
        ProjectValidationFailure('No project is available for this edit.'),
      );
    }
    if (current.id != expectedDocument.id ||
        current.revision != expectedDocument.revision ||
        current.currentState != expectedDocument.currentState ||
        current != expectedDocument) {
      return const Failure<ProjectSaveOutcome>(
        ProjectValidationFailure(
          'The project changed before the edit was saved.',
        ),
      );
    }
    return _service.apply(current, transaction);
  }
}

final class UnavailableEditPlanTransactionGateway
    implements EditPlanTransactionGateway {
  const UnavailableEditPlanTransactionGateway();

  @override
  ProjectDocument? get currentDocument => null;

  @override
  Future<Result<ProjectSaveOutcome>> apply(
    ProjectDocument expectedDocument,
    EditTransaction transaction,
  ) async => const Failure<ProjectSaveOutcome>(
    ProjectValidationFailure('Project transaction support is unavailable.'),
  );
}
