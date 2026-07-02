import 'dart:async';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'operation_schema.dart';

class IntentParser {
  static Future<(EditOperationSet?, ProviderFailure?)> parse(
    LlmProvider provider,
    AgentRequest request, {
    bool isRetry = false,
  }) async {
    final timeout = Duration(
      seconds: request.timeoutSeconds + (isRetry ? 30 : 0),
    );

    try {
      final result = await provider
          .parseCommand(request)
          .timeout(timeout);

      return (result, null);
    } on TimeoutException {
      return (
        null,
        ProviderFailure(
          provider.id,
          'Request timed out after ${timeout.inSeconds}s',
        ),
      );
    } on ProviderFailure catch (e) {
      return (null, e);
    } catch (e) {
      return (null, ProviderFailure(provider.id, 'Parse failed: $e'));
    }
  }
}
