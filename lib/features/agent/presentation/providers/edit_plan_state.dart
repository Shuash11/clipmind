import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';

enum EditPlanAction { idle, planning, applying, revising }

/// Presentation state intentionally contains only local, already-sanitized data.
final class EditPlanState {
  EditPlanState({
    this.plan,
    Iterable<EditPlan> priorRevisedPlans = const <EditPlan>[],
    this.action = EditPlanAction.idle,
    this.failureMessage,
    this.saveOutcome,
  }) : priorRevisedPlans = List<EditPlan>.unmodifiable(priorRevisedPlans);

  final EditPlan? plan;
  final List<EditPlan> priorRevisedPlans;
  final EditPlanAction action;
  final String? failureMessage;
  final ProjectSaveOutcome? saveOutcome;

  List<EditPlan> get priorPlans => priorRevisedPlans;
  bool get isBusy => action != EditPlanAction.idle;
  bool get isPlanning => action == EditPlanAction.planning;

  EditPlanState copyWith({
    EditPlan? plan,
    bool clearPlan = false,
    Iterable<EditPlan>? priorRevisedPlans,
    EditPlanAction? action,
    String? failureMessage,
    bool clearFailure = false,
    ProjectSaveOutcome? saveOutcome,
    bool clearSaveOutcome = false,
  }) => EditPlanState(
    plan: clearPlan ? null : (plan ?? this.plan),
    priorRevisedPlans: priorRevisedPlans ?? this.priorRevisedPlans,
    action: action ?? this.action,
    failureMessage: clearFailure
        ? null
        : (failureMessage ?? this.failureMessage),
    saveOutcome: clearSaveOutcome ? null : (saveOutcome ?? this.saveOutcome),
  );
}
