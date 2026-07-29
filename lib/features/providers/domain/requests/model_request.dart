import '../entities/immutable_value.dart';
import '../entities/model_tool_definition.dart';

final class ModelRequest {
  ModelRequest({
    required this.providerId,
    required this.modelId,
    required Iterable<Map<String, Object?>> messages,
    Iterable<ModelToolDefinition> tools = const <ModelToolDefinition>[],
    this.idempotencyKey,
  }) : messages = List.unmodifiable(messages.map(immutableObjectMap)),
       tools = List.unmodifiable(List<ModelToolDefinition>.from(tools));

  final String providerId;
  final String modelId;
  final List<Map<String, Object?>> messages;
  final List<ModelToolDefinition> tools;
  final String? idempotencyKey;
}
