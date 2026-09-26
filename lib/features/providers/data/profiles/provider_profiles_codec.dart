import 'dart:convert';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/policy/provider_url_policy.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_credential_reference.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';

/// Versioned codec for non-secret provider profile metadata.
final class ProviderProfilesCodec {
  static const int currentSchemaVersion = 1;
  static final RegExp _identifier = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$',
  );

  Result<String> encode(ProviderProfilesDocument document) {
    if (document.schemaVersion != currentSchemaVersion) return _unsupported();
    try {
      if (!_hasUniqueProfileIds(document.profiles) ||
          document.profiles.any(_hasSecretInMetadata)) {
        return _persistence();
      }
      return Success<String>(
        jsonEncode(<String, Object?>{
          'schemaVersion': document.schemaVersion,
          'activeProfileId': document.activeProfileId,
          'legacyMigrationState': document.legacyMigrationState.name,
          'profiles': document.profiles
              .map(_encodeProfile)
              .toList(growable: false),
        }),
      );
    } catch (_) {
      return _persistence();
    }
  }

  Result<ProviderProfilesDocument> decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return _malformed();
      final root = Map<String, Object?>.from(decoded);
      final schemaVersion = root['schemaVersion'];
      if (schemaVersion is! int) return _malformed();
      if (schemaVersion != currentSchemaVersion) return _unsupportedDocument();
      final rawProfiles = root['profiles'];
      if (rawProfiles is! List) return _malformed();
      final profiles = <ProviderProfile>[];
      for (final rawProfile in rawProfiles) {
        if (rawProfile is! Map) return _malformed();
        final profile = _decodeProfile(Map<String, Object?>.from(rawProfile));
        if (profile == null) return _malformed();
        profiles.add(profile);
      }
      if (!_hasUniqueProfileIds(profiles)) return _malformed();
      final activeProfileId = root['activeProfileId'];
      if (activeProfileId != null && activeProfileId is! String) {
        return _malformed();
      }
      final migration = _migrationState(root['legacyMigrationState']);
      if (migration == null) return _malformed();
      return Success<ProviderProfilesDocument>(
        ProviderProfilesDocument(
          schemaVersion: schemaVersion,
          profiles: profiles,
          activeProfileId: activeProfileId as String?,
          legacyMigrationState: migration,
        ),
      );
    } catch (_) {
      return _malformed();
    }
  }

  Map<String, Object?> _encodeProfile(
    ProviderProfile profile,
  ) => <String, Object?>{
    'id': profile.id,
    'providerId': profile.providerId,
    'displayName': profile.displayName,
    'endpoint': profile.endpoint.toString(),
    'credentialId': profile.credentialId,
    'headers': _sortedMap(profile.headers),
    'secretHeaderNames': profile.secretHeaderNames,
    'secretHeaderCredentialIds': _sortedMap(profile.secretHeaderCredentialIds),
    'manualModelIds': profile.manualModelIds,
    'selectedModelId': profile.selectedModelId,
    'enabled': profile.enabled,
    'timeoutMilliseconds': profile.timeout.inMilliseconds,
    'deletionPending': profile.deletionPending,
  };

  bool _hasSecretInMetadata(ProviderProfile profile) {
    try {
      if (!_identifier.hasMatch(profile.id) ||
          !_identifier.hasMatch(profile.providerId) ||
          profile.timeout.inMilliseconds <= 0 ||
          ProviderUrlPolicy.validate(profile.endpoint)
              is Failure<ProviderUrlValidation> ||
          _hasSensitiveEndpointQuery(profile.endpoint)) {
        return true;
      }
      if (profile.headers.keys.any(_isSensitiveHeaderName)) return true;
      if (!_hasUniqueCaseInsensitive(profile.secretHeaderNames) ||
          !_hasUniqueCaseInsensitive(profile.secretHeaderCredentialIds.keys)) {
        return true;
      }
      final apiKey = ProviderCredentialReference.apiKey(profile.id);
      if (profile.credentialId != null && profile.credentialId != apiKey) {
        return true;
      }
      final names = <String>{
        ...profile.secretHeaderNames,
        ...profile.secretHeaderCredentialIds.keys,
      };
      final normalizedSecretNames = names
          .map((name) => name.toLowerCase())
          .toSet();
      if (profile.headers.keys.any(
        (name) => normalizedSecretNames.contains(name.toLowerCase()),
      )) {
        return true;
      }
      return names.any((name) {
        final expected = ProviderCredentialReference.secretHeader(
          profile.id,
          name,
        );
        final reference = profile.secretHeaderCredentialIds[name];
        return reference != null && reference != expected;
      });
    } on ArgumentError {
      return true;
    }
  }

  bool _hasUniqueProfileIds(Iterable<ProviderProfile> profiles) {
    final ids = <String>{};
    for (final profile in profiles) {
      if (!ids.add(profile.id)) return false;
    }
    return true;
  }

  bool _hasUniqueCaseInsensitive(Iterable<String> values) {
    final normalized = <String>{};
    for (final value in values) {
      if (!normalized.add(value.toLowerCase())) return false;
    }
    return true;
  }

  bool _isSensitiveHeaderName(String name) {
    final normalized = name.toLowerCase();
    return normalized == 'authorization' ||
        normalized == 'proxy-authorization' ||
        normalized == 'x-api-key' ||
        normalized == 'api-key' ||
        normalized == 'api_key' ||
        normalized == 'x-auth-token' ||
        normalized == 'cookie' ||
        normalized.contains('token') ||
        normalized.contains('secret') ||
        normalized.contains('password') ||
        normalized.contains('apikey');
  }

  bool _hasSensitiveEndpointQuery(Uri endpoint) {
    for (final entry in endpoint.queryParametersAll.entries) {
      final name = entry.key.toLowerCase();
      if (name == 'api_key' ||
          name == 'access_token' ||
          name == 'refresh_token' ||
          name == 'client_secret' ||
          _isSensitiveHeaderName(name)) {
        return true;
      }
      if (entry.value.any(
        (value) => RegExp(r'\bbearer\s+', caseSensitive: false).hasMatch(value),
      )) {
        return true;
      }
    }
    return false;
  }

  Map<String, String> _sortedMap(Map<String, String> value) {
    final entries = value.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return Map<String, String>.fromEntries(entries);
  }

  ProviderProfile? _decodeProfile(Map<String, Object?> value) {
    final id = value['id'];
    final providerId = value['providerId'];
    final displayName = value['displayName'];
    final endpoint = value['endpoint'];
    final enabled = value['enabled'];
    final timeout = value['timeoutMilliseconds'];
    final deletionPending = value['deletionPending'];
    if (id is! String ||
        providerId is! String ||
        displayName is! String ||
        endpoint is! String ||
        enabled is! bool ||
        timeout is! int ||
        deletionPending is! bool ||
        timeout <= 0 ||
        !_identifier.hasMatch(id) ||
        !_identifier.hasMatch(providerId)) {
      return null;
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        ProviderUrlPolicy.validate(uri) is Failure<ProviderUrlValidation> ||
        _hasSensitiveEndpointQuery(uri)) {
      return null;
    }
    final credentialId = value['credentialId'];
    if (credentialId != null && credentialId is! String) return null;
    final headers = _stringMap(value['headers']);
    final secretHeaderCredentialIds = _stringMap(
      value['secretHeaderCredentialIds'],
    );
    final secretHeaderNames = _stringList(value['secretHeaderNames']);
    final manualModelIds = _stringList(value['manualModelIds']);
    final selectedModelId = value['selectedModelId'];
    if (headers == null ||
        secretHeaderCredentialIds == null ||
        secretHeaderNames == null ||
        manualModelIds == null ||
        (selectedModelId != null && selectedModelId is! String)) {
      return null;
    }
    final profile = ProviderProfile(
      id: id,
      providerId: providerId,
      displayName: displayName,
      endpoint: uri,
      credentialId: credentialId as String?,
      headers: headers,
      secretHeaderNames: secretHeaderNames,
      secretHeaderCredentialIds: secretHeaderCredentialIds,
      manualModelIds: manualModelIds,
      selectedModelId: selectedModelId as String?,
      enabled: enabled,
      timeout: Duration(milliseconds: timeout),
      deletionPending: deletionPending,
    );
    return _hasSecretInMetadata(profile) ? null : profile;
  }

  Map<String, String>? _stringMap(Object? value) {
    if (value is! Map) return null;
    final result = <String, String>{};
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! String) return null;
      result[entry.key as String] = entry.value as String;
    }
    return result;
  }

  List<String>? _stringList(Object? value) {
    if (value is! List || value.any((entry) => entry is! String)) return null;
    return value.cast<String>();
  }

  LegacyMigrationState? _migrationState(Object? value) {
    if (value is! String) return null;
    for (final state in LegacyMigrationState.values) {
      if (state.name == value) return state;
    }
    return null;
  }

  Failure<String> _persistence() => const Failure<String>(
    ProviderPersistenceFailure('Provider profile metadata could not be saved.'),
  );
  Failure<String> _unsupported() => const Failure<String>(
    ProviderPersistenceFailure(
      'Provider profile metadata version is unsupported.',
    ),
  );
  Failure<ProviderProfilesDocument> _malformed() =>
      const Failure<ProviderProfilesDocument>(
        ProviderPersistenceFailure('Provider profile metadata is invalid.'),
      );
  Failure<ProviderProfilesDocument> _unsupportedDocument() =>
      const Failure<ProviderProfilesDocument>(
        ProviderPersistenceFailure(
          'Provider profile metadata version is unsupported.',
        ),
      );
}
