import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/provider_credential_reference.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The intentionally small subset of secure storage used by provider profiles.
abstract interface class SecureStorageBackend {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

final class FlutterSecureStorageBackend implements SecureStorageBackend {
  FlutterSecureStorageBackend([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}

/// Stores only profile-scoped provider credentials. It deliberately exposes no
/// global or provider-name-wide clearing operation.
final class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({SecureStorageBackend? backend})
    : _backend = backend ?? FlutterSecureStorageBackend();

  final SecureStorageBackend _backend;

  static String apiKeyCredentialId(String profileId) =>
      ProviderCredentialReference.apiKey(profileId);

  static String secretHeaderCredentialId(String profileId, String headerName) =>
      ProviderCredentialReference.secretHeader(profileId, headerName);

  Future<Result<void>> deleteApiKey(String profileId) =>
      _deleteFor(() => apiKeyCredentialId(profileId));

  Future<Result<void>> deleteSecretHeader(
    String profileId,
    String headerName,
  ) => _deleteFor(() => secretHeaderCredentialId(profileId, headerName));

  Future<Result<String?>> readApiKey(String profileId) =>
      _readFor(() => apiKeyCredentialId(profileId));

  Future<Result<String?>> readSecretHeader(
    String profileId,
    String headerName,
  ) => _readFor(() => secretHeaderCredentialId(profileId, headerName));

  Future<Result<void>> writeApiKey(String profileId, String secret) =>
      _writeFor(() => apiKeyCredentialId(profileId), secret);

  Future<Result<void>> writeSecretHeader(
    String profileId,
    String headerName,
    String secret,
  ) => _writeFor(() => secretHeaderCredentialId(profileId, headerName), secret);

  @override
  Future<Result<void>> delete(String credentialId) async {
    if (!ProviderCredentialReference.isValid(credentialId)) return _invalid();
    try {
      await _backend.delete(key: credentialId);
      return const Success<void>(null);
    } catch (_) {
      return _deleteFailure();
    }
  }

  @override
  Future<Result<String?>> read(String credentialId) async {
    if (!ProviderCredentialReference.isValid(credentialId)) {
      return const Failure<String?>(
        ProviderCredentialFailure(
          'The provider credential reference is invalid.',
        ),
      );
    }
    try {
      return Success<String?>(await _backend.read(key: credentialId));
    } catch (_) {
      return const Failure<String?>(
        ProviderCredentialFailure('Unable to read provider credentials.'),
      );
    }
  }

  @override
  Future<Result<void>> write(String credentialId, String secret) async {
    if (!ProviderCredentialReference.isValid(credentialId)) return _invalid();
    try {
      await _backend.write(key: credentialId, value: secret);
      return const Success<void>(null);
    } catch (_) {
      // Do not include either the backend exception or the secret in failures.
      return const Failure<void>(
        ProviderCredentialFailure('Unable to store provider credentials.'),
      );
    }
  }

  Failure<void> _invalid() => const Failure<void>(
    ProviderCredentialFailure('The provider credential reference is invalid.'),
  );

  Failure<void> _deleteFailure() => const Failure<void>(
    ProviderCredentialFailure('Unable to delete provider credentials.'),
  );

  Future<Result<void>> _deleteFor(String Function() reference) async {
    try {
      return await delete(reference());
    } on ArgumentError {
      return _invalid();
    }
  }

  Future<Result<String?>> _readFor(String Function() reference) async {
    try {
      return await read(reference());
    } on ArgumentError {
      return const Failure<String?>(
        ProviderCredentialFailure(
          'The provider credential reference is invalid.',
        ),
      );
    }
  }

  Future<Result<void>> _writeFor(
    String Function() reference,
    String secret,
  ) async {
    try {
      return await write(reference(), secret);
    } on ArgumentError {
      return _invalid();
    }
  }
}
