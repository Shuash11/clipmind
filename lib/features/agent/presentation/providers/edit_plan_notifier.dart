import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/transactions/edit_transaction.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit_plan_state.dart';
import 'edit_plan_transaction_gateway.dart';

typedef EditPlanSubmitter =
    Future<Result<EditPlan>> Function(
      String command,
      CancellationToken cancellationToken,
    );
typedef EditPlanReplanner =
    Future<Result<EditPlan>> Function(
      EditPlan priorPlan,
      String instruction,
      CancellationToken cancellationToken,
    );
typedef EditPlanCancellationControllerFactory =
    CancellationController Function();

final class EditPlanNotifier extends StateNotifier<EditPlanState> {
  factory EditPlanNotifier({
    required EditPlanSubmitter submitter,
    required EditPlanReplanner replanner,
    required EditPlanTransactionGateway transactionGateway,
    required EditPlanCancellationControllerFactory
    cancellationControllerFactory,
    EditPlan? initialPlan,
  }) => EditPlanNotifier._(
    submitter,
    replanner,
    transactionGateway,
    cancellationControllerFactory,
    initialPlan,
  );

  EditPlanNotifier._(
    this._submitter,
    this._replanner,
    this._transactionGateway,
    this._cancellationControllerFactory,
    EditPlan? initialPlan,
  ) : super(EditPlanState(plan: initialPlan));

  final EditPlanSubmitter _submitter;
  final EditPlanReplanner _replanner;
  final EditPlanTransactionGateway _transactionGateway;
  final EditPlanCancellationControllerFactory _cancellationControllerFactory;
  CancellationController? _cancellation;
  int _epoch = 0;
  bool _isDisposed = false;

  Future<void> submit(String command) async {
    if (!_safeInstruction(command) || state.isBusy) return;
    final controller = _beginRequest();
    final epoch = _epoch;
    state = state.copyWith(
      action: EditPlanAction.planning,
      clearFailure: true,
      clearSaveOutcome: true,
    );
    Result<EditPlan> result;
    try {
      result = await _submitter(command.trim(), controller.token);
    } catch (_) {
      result = const Failure<EditPlan>(
        ProjectValidationFailure('Planning could not be completed.'),
      );
    }
    if (!_accepts(epoch, controller)) return;
    switch (result) {
      case Success<EditPlan>(:final value):
        if (!_isAcceptedPlanningPlan(value)) {
          state = state.copyWith(
            action: EditPlanAction.idle,
            failureMessage:
                'The planning response could not be verified. No changes were applied.',
            clearSaveOutcome: true,
          );
          return;
        }
        state = state.copyWith(
          plan: value,
          action: EditPlanAction.idle,
          clearFailure: true,
          clearSaveOutcome: true,
        );
      case Failure<EditPlan>():
        state = state.copyWith(
          action: EditPlanAction.idle,
          failureMessage:
              'Agent planning is unavailable. Configure an AI provider and try again.',
          clearSaveOutcome: true,
        );
    }
  }

  void approve(String planId) {
    final plan = _matchingPlan(planId);
    if (plan == null || state.isBusy || plan.status != EditPlanStatus.valid) {
      return;
    }
    state = state.copyWith(plan: plan.approve(), clearFailure: true);
  }

  Future<void> apply(String planId) async {
    final plan = _matchingPlan(planId);
    if (plan == null ||
        state.isBusy ||
        (plan.status != EditPlanStatus.valid &&
            plan.status != EditPlanStatus.approved)) {
      return;
    }
    final payload = plan.payload;
    if (payload == null) {
      _failPlan(plan, 'The preview is incomplete. No changes were applied.');
      return;
    }
    final document = _transactionGateway.currentDocument;
    if (document == null) {
      _failPlan(plan, 'No project is available. No changes were applied.');
      return;
    }
    if (document.id != plan.baseProjectId) {
      _failPlan(
        plan,
        'This preview belongs to another project. No changes were applied.',
      );
      return;
    }
    if (document.revision != plan.baseRevision) {
      _failPlan(
        plan,
        'The project changed after this preview. No changes were applied.',
      );
      return;
    }
    final transaction = EditTransaction(
      planId: plan.id,
      expectedRevision: plan.baseRevision,
      beforeState: document.currentState,
      candidateState: payload.candidateState,
      commands: payload.commands,
      summaries: payload.summaries,
      sourceKind: TransactionSourceKind.agent,
    );
    state = state.copyWith(
      action: EditPlanAction.applying,
      clearFailure: true,
      clearSaveOutcome: true,
    );
    Result<ProjectSaveOutcome> result;
    try {
      result = await _transactionGateway.apply(document, transaction);
    } catch (_) {
      result = const Failure(
        ProjectPersistenceFailure('Project changes could not be saved.'),
      );
    }
    if (_isDisposed || state.plan?.id != plan.id) return;
    switch (result) {
      case Success(:final value):
        if (!_isCoherentOutcome(value, plan, payload)) {
          _failPlan(
            plan,
            'The saved project could not be verified. No changes were applied.',
          );
          return;
        }
        state = state.copyWith(
          plan: plan.apply(),
          action: EditPlanAction.idle,
          saveOutcome: value,
          clearFailure: true,
        );
      case Failure():
        _failPlan(plan, 'The preview was not saved. No changes were applied.');
    }
  }

  void cancel(String planId) {
    final plan = _matchingPlan(planId);
    if (plan == null) return;
    if (state.action == EditPlanAction.planning ||
        state.action == EditPlanAction.revising) {
      _epoch++;
      _cancellation?.cancel();
      if (plan.status == EditPlanStatus.revised) {
        state = state.copyWith(action: EditPlanAction.idle);
        return;
      }
    }
    if (state.action == EditPlanAction.applying ||
        (plan.status != EditPlanStatus.draft &&
            plan.status != EditPlanStatus.valid &&
            plan.status != EditPlanStatus.approved)) {
      return;
    }
    state = state.copyWith(
      plan: plan.cancel(),
      action: EditPlanAction.idle,
      clearFailure: true,
      clearSaveOutcome: true,
    );
  }

  /// Cancels an owned planning scope when no preview ID exists yet.
  /// Durable apply is deliberately excluded: its save is already in progress.
  void cancelActivePlanning() {
    if (state.action != EditPlanAction.planning &&
        state.action != EditPlanAction.revising) {
      return;
    }
    _epoch++;
    _cancellation?.cancel();
    state = state.copyWith(
      action: EditPlanAction.idle,
      clearFailure: true,
      clearSaveOutcome: true,
    );
  }

  Future<void> revise(String planId, String instruction) async {
    final plan = _matchingPlan(planId);
    if (plan == null || state.isBusy || !_safeInstruction(instruction)) return;
    if (plan.status != EditPlanStatus.draft &&
        plan.status != EditPlanStatus.rejected &&
        plan.status != EditPlanStatus.valid &&
        plan.status != EditPlanStatus.approved) {
      return;
    }
    final document = _transactionGateway.currentDocument;
    if (document == null ||
        document.id != plan.baseProjectId ||
        document.revision != plan.baseRevision) {
      _failPlan(
        plan,
        'The project changed after this preview. No changes were applied.',
      );
      return;
    }
    final oldPayload = plan.payload;
    final revised = plan.revise();
    final controller = _beginRequest();
    final epoch = _epoch;
    state = state.copyWith(
      plan: revised,
      priorRevisedPlans: [...state.priorRevisedPlans, revised],
      action: EditPlanAction.revising,
      clearFailure: true,
      clearSaveOutcome: true,
    );
    Result<EditPlan> result;
    try {
      result = await _replanner(plan, instruction.trim(), controller.token);
    } catch (_) {
      result = const Failure<EditPlan>(
        ProjectValidationFailure('Revision planning could not be completed.'),
      );
    }
    if (!_accepts(epoch, controller)) return;
    switch (result) {
      case Failure<EditPlan>():
        _revisionFailure(
          plan,
          'A revised preview could not be prepared. No changes were applied.',
        );
      case Success<EditPlan>(:final value):
        final current = _transactionGateway.currentDocument;
        final validIdentity =
            value.id != plan.id &&
            value.baseProjectId == plan.baseProjectId &&
            value.baseRevision == plan.baseRevision &&
            current != null &&
            current.id == plan.baseProjectId &&
            current.revision == plan.baseRevision;
        if (!validIdentity || !_isAcceptedReplan(value, oldPayload)) {
          _revisionFailure(
            plan,
            'The revised preview could not be verified. No changes were applied.',
          );
          return;
        }
        state = state.copyWith(
          plan: value,
          action: EditPlanAction.idle,
          clearFailure: true,
          clearSaveOutcome: true,
        );
    }
  }

  CancellationController _beginRequest() {
    _epoch++;
    _cancellation?.cancel();
    final controller = _cancellationControllerFactory();
    _cancellation = controller;
    return controller;
  }

  bool _accepts(int epoch, CancellationController controller) =>
      !_isDisposed &&
      _epoch == epoch &&
      identical(_cancellation, controller) &&
      !controller.token.isCancelled;

  EditPlan? _matchingPlan(String planId) {
    final plan = state.plan;
    return plan != null && plan.id == planId ? plan : null;
  }

  void _failPlan(EditPlan plan, String message) {
    if (_isDisposed || state.plan?.id != plan.id) return;
    if (plan.status != EditPlanStatus.draft &&
        plan.status != EditPlanStatus.valid &&
        plan.status != EditPlanStatus.approved) {
      state = state.copyWith(
        action: EditPlanAction.idle,
        failureMessage: message,
        clearSaveOutcome: true,
      );
      return;
    }
    state = state.copyWith(
      plan: plan.fail(<ValidationFinding>[
        ValidationFinding(code: 'apply_failed', message: message),
      ]),
      action: EditPlanAction.idle,
      failureMessage: message,
      clearSaveOutcome: true,
    );
  }

  void _revisionFailure(EditPlan plan, String message) {
    final id = plan.id.length <= 180
        ? 'failed-${plan.id}'
        : 'failed-${plan.id.substring(0, 180)}';
    state = state.copyWith(
      plan: EditPlan.failedBeforeValidation(
        id: id,
        summary: 'The revised preview could not be verified.',
        baseProjectId: plan.baseProjectId,
        baseRevision: plan.baseRevision,
        findings: <ValidationFinding>[
          ValidationFinding(code: 'revision_failed', message: message),
        ],
      ),
      action: EditPlanAction.idle,
      failureMessage: message,
      clearSaveOutcome: true,
    );
  }

  bool _isAcceptedPlanningPlan(EditPlan plan) =>
      _hasConsistentStatusPayload(plan) &&
      (plan.status == EditPlanStatus.valid ||
          plan.status == EditPlanStatus.rejected ||
          plan.status == EditPlanStatus.failed);

  bool _isAcceptedReplan(EditPlan plan, Object? oldPayload) =>
      _hasConsistentStatusPayload(plan) &&
      (plan.status == EditPlanStatus.rejected ||
          plan.status == EditPlanStatus.failed ||
          (plan.status == EditPlanStatus.valid &&
              plan.payload != null &&
              !identical(plan.payload, oldPayload)));

  bool _hasConsistentStatusPayload(EditPlan plan) {
    final payload = plan.payload;
    if (plan.status == EditPlanStatus.valid) {
      return payload != null &&
          payload.commands.isNotEmpty &&
          payload.commands.length == payload.summaries.length;
    }
    return (plan.status == EditPlanStatus.rejected ||
            plan.status == EditPlanStatus.failed) &&
        payload == null;
  }

  bool _isCoherentOutcome(
    ProjectSaveOutcome outcome,
    EditPlan plan,
    ValidatedPlanPayload payload,
  ) {
    final document = outcome.document;
    return document.id == plan.baseProjectId &&
        document.revision == plan.baseRevision + 1 &&
        document.currentState == payload.candidateState;
  }

  bool _safeInstruction(String value) =>
      value.trim().isNotEmpty &&
      value.length <= 1000 &&
      !value.codeUnits.any((unit) => unit < 32 || unit == 127);

  @override
  void dispose() {
    _isDisposed = true;
    _epoch++;
    _cancellation?.cancel();
    super.dispose();
  }
}
