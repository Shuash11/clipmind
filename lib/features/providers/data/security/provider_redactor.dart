final class ProviderRedactor {
  ProviderRedactor({
    Iterable<String> secretValues = const <String>[],
    Iterable<String> sensitiveHeaderNames = const <String>[],
  }) : _secretValues = List<String>.unmodifiable(
         secretValues.where((value) => value.isNotEmpty),
       ),
       _sensitiveHeaderNames = <String>{
         'authorization',
         'proxy-authorization',
         'x-api-key',
         'api-key',
         'x-auth-token',
         'cookie',
         'api_key',
         'access_token',
         'refresh_token',
         'client_secret',
         ...sensitiveHeaderNames.map((name) => name.toLowerCase()),
       };

  final List<String> _secretValues;
  final Set<String> _sensitiveHeaderNames;

  String redact(String value) {
    var result = value;
    for (final secret in _secretValues) {
      result = result.replaceAll(secret, '[REDACTED]');
    }
    result = result.replaceAllMapped(
      RegExp(r'\bbearer\s+[^\s,}\]]+', caseSensitive: false),
      (_) => 'Bearer [REDACTED]',
    );
    result = result.replaceAllMapped(
      RegExp(
        r'("(?:api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|authorization|token|secret|password)"\s*:\s*")[^"]*(")',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]${match.group(2)}',
    );
    result = result.replaceAllMapped(
      RegExp(
        r'([a-z][a-z0-9-]*)(\s*[:=]\s*)([^,\r\n}\]]+)',
        caseSensitive: false,
      ),
      (match) => _isSensitiveName(match.group(1)!)
          ? '${match.group(1)}${match.group(2)}[REDACTED]'
          : match.group(0)!,
    );
    result = result.replaceAllMapped(
      RegExp(r'([a-z][a-z0-9+.-]*://)([^/@\s]+)@', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED]@',
    );
    result = result.replaceAllMapped(
      RegExp(r'([?&])([^=&\s]+)=([^&#\s]*)', caseSensitive: false),
      (match) => _isSensitiveName(match.group(2)!)
          ? '${match.group(1)}${match.group(2)}=[REDACTED]'
          : match.group(0)!,
    );
    return result;
  }

  Uri redactUri(Uri uri) {
    final parameters = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      parameters[key] = _isSensitiveName(key) ? '[REDACTED]' : value;
    });
    final withoutSensitiveQuery = uri.replace(queryParameters: parameters);
    return uri.userInfo.isEmpty
        ? withoutSensitiveQuery
        : withoutSensitiveQuery.replace(userInfo: '[REDACTED]');
  }

  Map<String, String> redactHeaders(Map<String, String> headers) =>
      Map<String, String>.unmodifiable(
        headers.map(
          (name, value) => MapEntry(
            name,
            _isSensitiveName(name) ? '[REDACTED]' : redact(value),
          ),
        ),
      );

  bool _isSensitiveName(String name) {
    final normalized = name.toLowerCase();
    return _sensitiveHeaderNames.contains(normalized) ||
        normalized.contains('token') ||
        normalized.contains('secret') ||
        normalized.contains('password') ||
        normalized.contains('apikey') ||
        normalized == 'key';
  }
}
