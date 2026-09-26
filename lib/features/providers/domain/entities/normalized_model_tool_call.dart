import 'immutable_value.dart';

final class NormalizedModelToolCall {
  NormalizedModelToolCall({
    required this.id,
    required this.name,
    required Map<String, Object?> arguments,
  }) : arguments = immutableObjectMap(arguments);

  final String id;
  final String name;
  final Map<String, Object?> arguments;
}
