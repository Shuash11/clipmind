/// Read tools answer from project ground truth; edit tools run FFmpeg.
enum ToolCategory { read, edit }

/// One callable tool: transport-agnostic definition (MCP-style).
///
/// [inputSchema] is the canonical strict-compatible JSON Schema:
/// `{type: object, properties: {...}, required: [all fields],
/// additionalProperties: false}`. Optional params are typed as
/// `["string","null"]` / `["number","null"]` unions.
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final ToolCategory category;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
        'category': category.name,
      };

  factory ToolDefinition.fromJson(Map<String, dynamic> json) {
    return ToolDefinition(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      inputSchema:
          Map<String, dynamic>.from(json['inputSchema'] as Map? ?? {}),
      category: ToolCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ToolCategory.read,
      ),
    );
  }
}

/// One invocation requested by the model.
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> args;

  const ToolCall({
    required this.id,
    required this.name,
    this.args = const {},
  });
}

/// What executing a [ToolCall] produced.
///
/// Failures carry an actionable message (+ retry hint) so the model can
/// self-correct. Executors never throw across the boundary.
class ToolResult {
  final bool success;
  final Map<String, dynamic> data;
  final String error;
  final String summary;

  const ToolResult({
    required this.success,
    this.data = const {},
    this.error = '',
    this.summary = '',
  });

  factory ToolResult.ok({
    Map<String, dynamic> data = const {},
    String summary = '',
  }) {
    return ToolResult(success: true, data: data, summary: summary);
  }

  factory ToolResult.fail(
    String error, {
    String summary = '',
    Map<String, dynamic> data = const {},
  }) {
    return ToolResult(
      success: false,
      error: error,
      summary: summary.isNotEmpty ? summary : error,
      data: data,
    );
  }
}

/// Implemented by [ReadToolExecutor] / [EditToolExecutor].
abstract class ToolExecutor {
  Future<ToolResult> execute(ToolCall call);
}
