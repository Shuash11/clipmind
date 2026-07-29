import '../entities/immutable_value.dart';
import '../entities/normalized_model_tool_call.dart';

final class ModelResponse {
  ModelResponse({
    required this.modelId,
    required this.content,
    Iterable<NormalizedModelToolCall> toolCalls =
        const <NormalizedModelToolCall>[],
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : toolCalls = List.unmodifiable(
         List<NormalizedModelToolCall>.from(toolCalls),
       ),
       metadata = immutableObjectMap(metadata);

  final String modelId;
  final String content;
  final List<NormalizedModelToolCall> toolCalls;
  final Map<String, Object?> metadata;
}
