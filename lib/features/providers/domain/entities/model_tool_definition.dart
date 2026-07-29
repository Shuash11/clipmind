import 'immutable_value.dart';

final class ModelToolDefinition {
  ModelToolDefinition({
    required this.name,
    required this.description,
    required Map<String, Object?> inputSchema,
  }) : inputSchema = immutableObjectMap(inputSchema);

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
}
