/// Removes a resolved API key from provider error text.
///
/// Provider responses are untrusted input: a `400` body can echo the submitted
/// key back. Error messages must stay key-free (keys are impossible to leak
/// through errors), so any occurrence of the resolved key is replaced before
/// the text is embedded in a [ProviderFailure] message. Text that does not
/// contain the key passes through unchanged.
String redactApiKeyFromError(String text, String? apiKey) {
  if (apiKey == null || apiKey.isEmpty) return text;
  return text.replaceAll(apiKey, '[REDACTED]');
}
