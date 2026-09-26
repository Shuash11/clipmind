import 'validated_plan_payload.dart';
import 'validation_finding.dart';

enum EditPlanStatus {
  draft,
  valid,
  rejected,
  approved,
  applied,
  cancelled,
  revised,
  failed,
}

final class EditPlan {
  EditPlan._({
    required this.id,
    required this.summary,
    required this.baseProjectId,
    required this.baseRevision,
    required this.status,
    required Iterable<ValidationFinding> findings,
    required this.payload,
  }) : findings = List<ValidationFinding>.unmodifiable(findings);

  factory EditPlan.draft({
    required String id,
    required String summary,
    required String baseProjectId,
    required int baseRevision,
  }) => _withoutPayload(
    id: id,
    summary: summary,
    baseProjectId: baseProjectId,
    baseRevision: _revision(baseRevision),
    status: EditPlanStatus.draft,
  );

  factory EditPlan.valid({
    required String id,
    required String summary,
    required String baseProjectId,
    required int baseRevision,
    required ValidatedPlanPayload payload,
    Iterable<ValidationFinding> findings = const <ValidationFinding>[],
  }) => EditPlan._(
    id: _identity(id, 200),
    summary: _identity(summary),
    baseProjectId: _identity(baseProjectId, 200),
    baseRevision: _revision(baseRevision),
    status: EditPlanStatus.valid,
    findings: findings,
    payload: payload,
  );

  factory EditPlan.rejected({
    required String id,
    required String summary,
    required String baseProjectId,
    required int baseRevision,
    required Iterable<ValidationFinding> findings,
  }) => _withoutPayload(
    id: id,
    summary: summary,
    baseProjectId: baseProjectId,
    baseRevision: _revision(baseRevision),
    status: EditPlanStatus.rejected,
    findings: findings,
  );

  factory EditPlan.failedBeforeValidation({
    required String id,
    required String summary,
    required String baseProjectId,
    required int baseRevision,
    Iterable<ValidationFinding> findings = const <ValidationFinding>[],
  }) => _withoutPayload(
    id: id,
    summary: summary,
    baseProjectId: baseProjectId,
    baseRevision: _revision(baseRevision),
    status: EditPlanStatus.failed,
    findings: findings,
  );

  final String id;
  final String summary;
  final String baseProjectId;
  final int baseRevision;
  final EditPlanStatus status;
  final List<ValidationFinding> findings;
  final ValidatedPlanPayload? payload;

  String get planId => id;

  EditPlan validate(ValidatedPlanPayload value) {
    _requireStatus({EditPlanStatus.draft});
    return EditPlan.valid(
      id: id,
      summary: summary,
      baseProjectId: baseProjectId,
      baseRevision: baseRevision,
      payload: value,
    );
  }

  EditPlan approve() {
    _requireStatus({EditPlanStatus.valid});
    return _copy(status: EditPlanStatus.approved, payload: payload);
  }

  EditPlan apply() {
    _requireStatus({EditPlanStatus.valid, EditPlanStatus.approved});
    return _copy(status: EditPlanStatus.applied, payload: payload);
  }

  EditPlan reject(Iterable<ValidationFinding> value) {
    _requireStatus({EditPlanStatus.draft, EditPlanStatus.valid});
    return _copy(
      status: EditPlanStatus.rejected,
      findings: value,
      clearPayload: true,
    );
  }

  EditPlan cancel() {
    _requireStatus({
      EditPlanStatus.draft,
      EditPlanStatus.valid,
      EditPlanStatus.approved,
    });
    return _copy(status: EditPlanStatus.cancelled, clearPayload: true);
  }

  EditPlan revise() {
    _requireStatus({
      EditPlanStatus.draft,
      EditPlanStatus.rejected,
      EditPlanStatus.valid,
      EditPlanStatus.approved,
    });
    return _copy(status: EditPlanStatus.revised, clearPayload: true);
  }

  EditPlan fail(Iterable<ValidationFinding> value) {
    _requireStatus({
      EditPlanStatus.draft,
      EditPlanStatus.valid,
      EditPlanStatus.approved,
    });
    final retainsPayload =
        status == EditPlanStatus.valid || status == EditPlanStatus.approved;
    return _copy(
      status: EditPlanStatus.failed,
      findings: value,
      payload: retainsPayload ? payload : null,
      clearPayload: !retainsPayload,
    );
  }

  EditPlan _copy({
    required EditPlanStatus status,
    Iterable<ValidationFinding>? findings,
    ValidatedPlanPayload? payload,
    bool clearPayload = false,
  }) => EditPlan._(
    id: id,
    summary: summary,
    baseProjectId: baseProjectId,
    baseRevision: baseRevision,
    status: status,
    findings: findings ?? this.findings,
    payload: clearPayload ? null : payload,
  );

  void _requireStatus(Set<EditPlanStatus> allowed) {
    if (!allowed.contains(status)) {
      throw StateError('Cannot transition $status edit plan');
    }
  }

  static EditPlan _withoutPayload({
    required String id,
    required String summary,
    required String baseProjectId,
    required int baseRevision,
    required EditPlanStatus status,
    Iterable<ValidationFinding> findings = const <ValidationFinding>[],
  }) => EditPlan._(
    id: _identity(id, 200),
    summary: _identity(summary),
    baseProjectId: _identity(baseProjectId, 200),
    baseRevision: baseRevision,
    status: status,
    findings: findings,
    payload: null,
  );

  static String _identity(String value, [int maxLength = 500]) {
    if (value.trim().isEmpty ||
        value.length > maxLength ||
        value.codeUnits.any((unit) => unit < 32 || unit == 127)) {
      throw ArgumentError('Invalid edit plan text');
    }
    return value;
  }

  static int _revision(int value) {
    if (value < 0) {
      throw ArgumentError('Invalid edit plan revision');
    }
    return value;
  }
}
