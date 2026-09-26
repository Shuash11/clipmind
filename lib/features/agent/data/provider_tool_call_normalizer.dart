import 'package:clipmind/features/agent/domain/entities/normalized_planning_output.dart';
import 'package:clipmind/features/agent/domain/entities/tool_call.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';

import 'strict_json_schema_encoder.dart';

final class ProviderToolCallNormalizer {
  factory ProviderToolCallNormalizer({
    EditorToolRegistry? registry,
    StrictJsonSchemaEncoder? fallbackEncoder,
  }) {
    final sharedRegistry = registry ?? EditorToolRegistry.standard();
    return ProviderToolCallNormalizer._(
      sharedRegistry,
      fallbackEncoder ?? StrictJsonSchemaEncoder(registry: sharedRegistry),
    );
  }

  ProviderToolCallNormalizer._(this._registry, this._fallbackEncoder);

  final EditorToolRegistry _registry;
  final StrictJsonSchemaEncoder _fallbackEncoder;

  NormalizedPlanningOutput normalize(ModelResponse response) {
    if (response.toolCalls.isEmpty) {
      return _fallbackEncoder.decode(response.content);
    }
    if (response.toolCalls.length > EditorToolRegistry.maxToolCalls) {
      return _invalid('too_many_calls');
    }
    final calls = <ToolCall>[];
    try {
      for (final call in response.toolCalls) {
        if (_registry.byName(call.name) == null) {
          return _invalid('unknown_tool');
        }
        calls.add(
          ToolCall(callId: call.id, name: call.name, arguments: call.arguments),
        );
      }
    } catch (_) {
      return _invalid('invalid_operation');
    }
    final summary = _safeSummary(response.content);
    return NormalizedPlanningOutput(
      summary: summary ?? 'The model proposed editor changes.',
      calls: calls,
    );
  }

  String? _safeSummary(String value) =>
      value.trim().isNotEmpty &&
          value.length <= 1000 &&
          !value.codeUnits.any((unit) => unit < 32 || unit == 127)
      ? value
      : null;

  NormalizedPlanningOutput _invalid(String code) =>
      NormalizedPlanningOutput.invalid(
        ValidationFinding(
          code: code,
          message: 'The provider tool response could not be used safely.',
        ),
      );
}
