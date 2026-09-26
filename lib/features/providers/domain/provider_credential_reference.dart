/// Canonical, profile-scoped secure-storage references.
///
/// These are metadata references only; they never contain credential values.
final class ProviderCredentialReference {
  ProviderCredentialReference._();

  static const String _prefix = 'clipmind_provider_';
  static final RegExp _profileId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$');
  static final RegExp _headerName = RegExp(
    r"^[A-Za-z0-9!#\$%&'*+.^_`|~-]{1,128}$",
  );

  static String apiKey(String profileId) {
    _validateProfileId(profileId);
    return '$_prefix${profileId}_api_key';
  }

  static String secretHeader(String profileId, String headerName) {
    _validateProfileId(profileId);
    if (!_headerName.hasMatch(headerName)) {
      throw ArgumentError.value(
        headerName,
        'headerName',
        'Invalid header name.',
      );
    }
    final encoded = headerName
        .toLowerCase()
        .codeUnits
        .map((unit) => unit.toRadixString(16).padLeft(2, '0'))
        .join();
    return '$_prefix${profileId}_header_$encoded';
  }

  static bool isValid(String credentialId) {
    final match = RegExp(
      r'^clipmind_provider_([A-Za-z0-9][A-Za-z0-9_-]{0,127})_(api_key|header_[0-9a-f]+)$',
    ).firstMatch(credentialId);
    return match != null;
  }

  static bool belongsToProfile(String credentialId, String profileId) {
    if (!_profileId.hasMatch(profileId)) return false;
    final match = RegExp(
      r'^clipmind_provider_([A-Za-z0-9][A-Za-z0-9_-]{0,127})_(api_key|header_[0-9a-f]+)$',
    ).firstMatch(credentialId);
    return match?.group(1) == profileId;
  }

  static void _validateProfileId(String profileId) {
    if (!_profileId.hasMatch(profileId)) {
      throw ArgumentError.value(
        profileId,
        'profileId',
        'Invalid profile identifier.',
      );
    }
  }
}
