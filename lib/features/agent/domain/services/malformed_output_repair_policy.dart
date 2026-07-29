import 'dart:convert';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';

typedef PlanningCompletion =
    Future<Result<ModelResponse>> Function(
      ModelRequest request,
      CancellationToken token,
    );

/// A per-request allowance for one safe retry.  It is deliberately an instance
/// rather than a process-wide flag so independent planning sessions do not
/// affect one another.
final class MalformedOutputRepairPolicy {
  bool _used = false;
  int get callbackCount => _used ? 1 : 0;
  bool get canRepair => !_used;

  Future<Result<ModelResponse>?> repair({
    required ModelRequest originalRequest,
    required Iterable<ValidationFinding> findings,
    required PlanningCompletion complete,
    required CancellationToken token,
  }) async {
    if (_used) return null;
    _used = true;
    final safeFindings = List<ValidationFinding>.unmodifiable(findings);
    final repairMessage = jsonEncode(<String, Object?>{
      'instruction':
          'Return only the required canonical editor tool calls. Correct the listed validation findings.',
      'findings': safeFindings
          .map(
            (finding) => <String, Object?>{
              'code': finding.code,
              if (finding.argumentPath != null)
                'argumentPath': finding.argumentPath,
            },
          )
          .toList(growable: false),
    });
    final request = ModelRequest(
      providerId: originalRequest.providerId,
      modelId: originalRequest.modelId,
      tools: originalRequest.tools,
      idempotencyKey: originalRequest.idempotencyKey,
      messages: <Map<String, Object?>>[
        ...originalRequest.messages,
        <String, Object?>{'role': 'user', 'content': repairMessage},
      ],
    );
    try {
      token.throwIfCancelled();
      final result = await complete(request, token);
      token.throwIfCancelled();
      return result;
    } on CancelledException {
      return const Failure<ModelResponse>(ProviderCancellationFailure());
    } catch (_) {
      return const Failure<ModelResponse>(
        ProviderTransportFailure(
          message: 'The repair request could not be completed.',
        ),
      );
    }
  }
}
