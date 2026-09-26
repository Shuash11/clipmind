import 'dart:convert';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/data/provider_tool_call_normalizer.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/entities/sanitized_project_snapshot.dart';
import 'package:clipmind/features/agent/domain/entities/tool_call_validation_result.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';

import 'malformed_output_repair_policy.dart';
import 'tool_call_validator.dart';

final class AgentPlanningRequest {
  AgentPlanningRequest({
    required this.providerId,
    required this.modelId,
    required this.userCommand,
    required this.document,
    required this.cancellationToken,
    this.idempotencyKey,
  });

  final String providerId;
  final String modelId;
  final String userCommand;
  final ProjectDocument document;
  final CancellationToken cancellationToken;
  final String? idempotencyKey;
}

/// Builds a provider-safe request only when planning is explicitly submitted.
/// This service has no persistence or presentation responsibilities.
final class AgentPlanningService {
  factory AgentPlanningService({
    required EditorToolRegistry registry,
    required ProviderToolCallNormalizer normalizer,
    required ToolCallValidator validator,
    required PlanningCompletion complete,
    required String Function() planIdFactory,
    MalformedOutputRepairPolicy Function()? repairPolicyFactory,
  }) => AgentPlanningService._(
    registry,
    normalizer,
    validator,
    complete,
    planIdFactory,
    repairPolicyFactory ?? MalformedOutputRepairPolicy.new,
  );

  AgentPlanningService._(
    this._registry,
    this._normalizer,
    this._validator,
    this._complete,
    this._planIdFactory,
    this._repairPolicyFactory,
  );

  final EditorToolRegistry _registry;
  final ProviderToolCallNormalizer _normalizer;
  final ToolCallValidator _validator;
  final PlanningCompletion _complete;
  final String Function() _planIdFactory;
  final MalformedOutputRepairPolicy Function() _repairPolicyFactory;

  Future<Result<EditPlan>> plan(AgentPlanningRequest submission) async {
    final document = submission.document;
    final planId = _planIdFactory();
    if (!_safeCommand(submission.userCommand) ||
        !_safeIdentity(submission.providerId) ||
        !_safeIdentity(submission.modelId)) {
      return Success(
        EditPlan.rejected(
          id: planId,
          summary: 'The planning request was rejected.',
          baseProjectId: document.id,
          baseRevision: document.revision,
          findings: [
            _finding('invalid_arguments', 'The planning request is not valid.'),
          ],
        ),
      );
    }
    final request = _modelRequest(submission);
    Result<ModelResponse> first;
    try {
      submission.cancellationToken.throwIfCancelled();
      first = await _complete(request, submission.cancellationToken);
      submission.cancellationToken.throwIfCancelled();
    } on CancelledException {
      return const Failure<EditPlan>(ProviderCancellationFailure());
    } catch (_) {
      return const Failure<EditPlan>(
        ProviderTransportFailure(
          message: 'The planning request could not be completed.',
        ),
      );
    }
    final ModelResponse response;
    switch (first) {
      case Success<ModelResponse>(:final value):
        response = value;
        break;
      case Failure<ModelResponse>(:final error):
        return Failure<EditPlan>(error);
    }
    var normalized = _normalizer.normalize(response);
    var validated = normalized.findings.isEmpty
        ? _validator.validate(normalized.calls, document)
        : null;
    if (normalized.findings.isEmpty && validated!.isValid) {
      return Success(_valid(planId, normalized.summary, document, validated));
    }
    final findings = normalized.findings.isNotEmpty
        ? normalized.findings
        : validated!.findings;
    final repair = _repairPolicyFactory();
    final repaired = await repair.repair(
      originalRequest: request,
      findings: findings,
      complete: _complete,
      token: submission.cancellationToken,
    );
    if (submission.cancellationToken.isCancelled) {
      return const Failure<EditPlan>(ProviderCancellationFailure());
    }
    final ModelResponse repairedResponse;
    switch (repaired) {
      case Success<ModelResponse>(:final value):
        repairedResponse = value;
        break;
      case Failure<ModelResponse>(:final error):
        return Failure<EditPlan>(error);
      case null:
        return Success(_rejected(planId, document, findings));
    }
    normalized = _normalizer.normalize(repairedResponse);
    validated = normalized.findings.isEmpty
        ? _validator.validate(normalized.calls, document)
        : null;
    if (normalized.findings.isEmpty && validated!.isValid) {
      return Success(_valid(planId, normalized.summary, document, validated));
    }
    return Success(
      _rejected(
        planId,
        document,
        normalized.findings.isNotEmpty
            ? normalized.findings
            : validated!.findings,
      ),
    );
  }

  ModelRequest _modelRequest(AgentPlanningRequest submission) {
    final snapshot = SanitizedProjectSnapshot.fromDocument(submission.document);
    return ModelRequest(
      providerId: submission.providerId,
      modelId: submission.modelId,
      idempotencyKey: submission.idempotencyKey,
      tools: _registry.toModelToolDefinitions(),
      messages: <Map<String, Object?>>[
        <String, Object?>{
          'role': 'system',
          'content':
              'Propose only canonical editor tool calls. Do not include local paths, shell commands, or output settings.',
        },
        <String, Object?>{
          'role': 'user',
          'content': jsonEncode(<String, Object?>{
            'command': submission.userCommand,
            'project': snapshot.toProviderJson(),
          }),
        },
      ],
    );
  }

  EditPlan _valid(
    String id,
    String summary,
    ProjectDocument document,
    ToolCallValidationResult result,
  ) => EditPlan.valid(
    id: id,
    summary: _summary(summary),
    baseProjectId: document.id,
    baseRevision: document.revision,
    payload: result.payload!,
  );

  EditPlan _rejected(
    String id,
    ProjectDocument document,
    Iterable<ValidationFinding> findings,
  ) => EditPlan.rejected(
    id: id,
    summary: 'The proposed changes could not be validated.',
    baseProjectId: document.id,
    baseRevision: document.revision,
    findings: findings,
  );

  bool _safeCommand(String value) =>
      value.trim().isNotEmpty &&
      value.length <= 4000 &&
      !value.codeUnits.any((unit) => unit < 32 || unit == 127);
  bool _safeIdentity(String value) =>
      value.trim().isNotEmpty &&
      value.length <= 200 &&
      !value.codeUnits.any((unit) => unit < 32 || unit == 127);
  String _summary(String _) => 'Proposed editor changes.';
  ValidationFinding _finding(String code, String message) =>
      ValidationFinding(code: code, message: message);
}
