import 'safe_json_value.dart';

final class ToolCall {
  ToolCall({
    required String callId,
    required String name,
    required Map<String, Object?> arguments,
  }) : callId = _nonEmpty(callId),
       name = _canonicalName(name),
       arguments = immutableSafeJsonMap(arguments);

  final String callId;
  final String name;
  final Map<String, Object?> arguments;

  String get id => callId;
  String get canonicalName => name;

  static String _nonEmpty(String value) {
    if (value.trim().isEmpty ||
        value.length > 200 ||
        value.codeUnits.any((unit) => unit < 32 || unit == 127)) {
      throw ArgumentError('Invalid tool call identifier');
    }
    return value;
  }

  static String _canonicalName(String value) {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(value)) {
      throw ArgumentError('Invalid tool call name');
    }
    return value;
  }
}
