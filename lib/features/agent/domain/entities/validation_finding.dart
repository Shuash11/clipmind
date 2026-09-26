final class ValidationFinding {
  ValidationFinding({
    required String code,
    required String message,
    String? callId,
    String? argumentPath,
  }) : code = _code(code),
       message = _safeText(message, 500),
       callId = _callId(callId),
       argumentPath = _argumentPath(argumentPath);

  final String code;
  final String message;
  final String? callId;
  final String? argumentPath;

  static String _code(String value) {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(value)) {
      throw ArgumentError('Invalid validation finding code');
    }
    return value;
  }

  static String _safeText(String value, int maxLength) {
    if (value.trim().isEmpty ||
        value.length > maxLength ||
        _hasControl(value)) {
      throw ArgumentError('Invalid validation finding text');
    }
    return value;
  }

  static String? _callId(String? value) {
    if (value == null) return null;
    return _safeText(value, 200);
  }

  static String? _argumentPath(String? value) {
    if (value == null) return null;
    if (value.length > 200 ||
        !RegExp(
          r'^[a-z][a-zA-Z0-9]*(?:\[[0-9]+\]|\.[a-z][a-zA-Z0-9]*)*$',
        ).hasMatch(value)) {
      throw ArgumentError('Invalid validation finding argument path');
    }
    return value;
  }

  static bool _hasControl(String value) =>
      value.codeUnits.any((unit) => unit < 32 || unit == 127);
}
