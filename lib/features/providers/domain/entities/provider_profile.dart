final class ProviderProfile {
  ProviderProfile({
    required this.id,
    required this.providerId,
    required this.displayName,
    required this.endpoint,
    this.credentialId,
    Map<String, String> headers = const <String, String>{},
    Iterable<String> secretHeaderNames = const <String>[],
    Map<String, String> secretHeaderCredentialIds = const <String, String>{},
    Iterable<String> manualModelIds = const <String>[],
    this.selectedModelId,
    this.enabled = true,
    this.timeout = const Duration(seconds: 30),
    this.deletionPending = false,
  }) : headers = Map.unmodifiable(Map<String, String>.from(headers)),
       secretHeaderNames = List.unmodifiable(
         List<String>.from(secretHeaderNames),
       ),
       secretHeaderCredentialIds = Map.unmodifiable(
         Map<String, String>.from(secretHeaderCredentialIds),
       ),
       manualModelIds = List.unmodifiable(List<String>.from(manualModelIds));

  final String id;
  final String providerId;
  final String displayName;
  final Uri endpoint;
  final String? credentialId;

  /// Non-secret headers only. Secret values live in [secretHeaderCredentialIds].
  final Map<String, String> headers;
  final List<String> secretHeaderNames;
  final Map<String, String> secretHeaderCredentialIds;
  final List<String> manualModelIds;

  /// The model selected for this profile. This is provider metadata, never a
  /// registry key, and is deliberately independent of the profile identifier.
  final String? selectedModelId;
  final bool enabled;
  final Duration timeout;
  final bool deletionPending;

  ProviderProfile copyWith({
    String? displayName,
    Uri? endpoint,
    String? credentialId,
    Map<String, String>? headers,
    Iterable<String>? secretHeaderNames,
    Map<String, String>? secretHeaderCredentialIds,
    Iterable<String>? manualModelIds,
    String? selectedModelId,
    bool? enabled,
    Duration? timeout,
    bool? deletionPending,
    bool clearCredentialId = false,
    bool clearSelectedModelId = false,
  }) => ProviderProfile(
    id: id,
    providerId: providerId,
    displayName: displayName ?? this.displayName,
    endpoint: endpoint ?? this.endpoint,
    credentialId: clearCredentialId ? null : credentialId ?? this.credentialId,
    headers: headers ?? this.headers,
    secretHeaderNames: secretHeaderNames ?? this.secretHeaderNames,
    secretHeaderCredentialIds:
        secretHeaderCredentialIds ?? this.secretHeaderCredentialIds,
    manualModelIds: manualModelIds ?? this.manualModelIds,
    selectedModelId: clearSelectedModelId
        ? null
        : selectedModelId ?? this.selectedModelId,
    enabled: enabled ?? this.enabled,
    timeout: timeout ?? this.timeout,
    deletionPending: deletionPending ?? this.deletionPending,
  );
}
