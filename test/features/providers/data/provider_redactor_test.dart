import 'package:clipmind/features/providers/data/security/provider_redactor.dart';
import 'package:clipmind/features/providers/data/security/secure_credential_store.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'redacts credentials from text, URLs, query values, and JSON metadata',
    () {
      const secret = 'super-secret-value';
      final redactor = ProviderRedactor(secretValues: const <String>[secret]);
      final output = redactor.redact(
        'Bearer $secret https://user:$secret@example.test/?api_key=$secret '
        '{"client_secret":"$secret"} X-Secret: $secret',
      );
      expect(output, isNot(contains(secret)));
      expect(output, contains('[REDACTED]'));
    },
  );

  test(
    'secure storage errors are stable and never include backend details',
    () async {
      const secret = 'storage-secret';
      final store = SecureCredentialStore(backend: _FailingBackend());
      final result = await store.write(
        'clipmind_provider_profile_api_key',
        secret,
      );
      expect(result, isA<Failure<void>>());
      final failure = (result as Failure<void>).error;
      expect(failure.toString(), isNot(contains(secret)));
      expect(failure.toString(), isNot(contains('backend storage-secret')));
    },
  );

  test('uses collision-resistant profile and header credential keys', () {
    expect(
      SecureCredentialStore.apiKeyCredentialId('profile-1'),
      'clipmind_provider_profile-1_api_key',
    );
    expect(
      SecureCredentialStore.secretHeaderCredentialId('profile-1', 'X-Api-Key'),
      startsWith('clipmind_provider_profile-1_header_'),
    );
    expect(
      () => SecureCredentialStore.apiKeyCredentialId('../other'),
      throwsArgumentError,
    );
  });
}

final class _FailingBackend implements SecureStorageBackend {
  @override
  Future<void> delete({required String key}) async =>
      throw StateError('backend storage-secret');
  @override
  Future<String?> read({required String key}) async =>
      throw StateError('backend storage-secret');
  @override
  Future<void> write({required String key, required String value}) async =>
      throw StateError('backend storage-secret');
}
