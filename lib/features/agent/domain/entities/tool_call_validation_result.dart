import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';

import 'validated_plan_payload.dart';
import 'validation_finding.dart';

final class ToolCallValidationResult {
  ToolCallValidationResult._({
    required Iterable<ProjectCommand> commands,
    required Iterable<ValidationFinding> findings,
    required this.payload,
    required this.candidate,
  }) : commands = List<ProjectCommand>.unmodifiable(commands),
       findings = List<ValidationFinding>.unmodifiable(findings);

  factory ToolCallValidationResult.valid(ValidatedPlanPayload payload) =>
      ToolCallValidationResult._(
        commands: payload.commands,
        findings: const <ValidationFinding>[],
        payload: payload,
        candidate: payload.candidateState,
      );

  factory ToolCallValidationResult.invalid(
    Iterable<ValidationFinding> findings,
  ) => ToolCallValidationResult._(
    commands: const <ProjectCommand>[],
    findings: findings,
    payload: null,
    candidate: null,
  );

  final List<ProjectCommand> commands;
  final List<ValidationFinding> findings;
  final ValidatedPlanPayload? payload;
  final ProjectStateSnapshot? candidate;
  ProjectStateSnapshot? get candidateState => candidate;
  ValidatedPlanPayload? get validatedPayload => payload;
  bool get isValid => payload != null && findings.isEmpty;
}
