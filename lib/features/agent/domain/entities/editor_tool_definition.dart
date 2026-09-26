import 'safe_json_value.dart';

final class EditorToolDefinition {
  EditorToolDefinition({
    required this.name,
    required this.description,
    required Map<String, Object?> inputSchema,
  }) : inputSchema = immutableSafeJsonMap(inputSchema) {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      throw ArgumentError('Invalid editor tool name');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError('Invalid editor tool description');
    }
  }

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;

  Map<String, Object?> get schema => inputSchema;
}
