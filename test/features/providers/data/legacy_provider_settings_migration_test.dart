import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/migration/legacy_provider_settings_migration.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_storage.dart';
import 'package:clipmind/features/providers/data/provider_profile_repository_impl.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'migrates legacy provider settings once into scoped credentials',
    () async {
      final repository = ProviderProfileRepositoryImpl(storage: _Storage());
      final legacyCredentials = _LegacyCredentials(<String, String>{
        'openai': 'legacy-secret',
      });
      final credentials = _Credentials();
      final migration = LegacyProviderSettingsMigration(
        repository: repository,
        settings: _Settings(
          const LegacyProviderSettings(
            activeProviderId: 'openai',
            activeModel: 'gpt-test',
            ollamaEndpoint: 'http://localhost:11434',
          ),
        ),
        legacyCredentials: legacyCredentials,
        credentials: credentials,
      );

      expect(await migration.migrate(), isA<Success<void>>());
      final document =
          (await repository.load() as Success<ProviderProfilesDocument>).value;
      expect(document.legacyMigrationState.name, 'completed');
      expect(document.activeProfileId, 'legacy-openai');
      expect(
        credentials.values,
        containsPair(
          'clipmind_provider_legacy-openai_api_key',
          'legacy-secret',
        ),
      );
      expect(legacyCredentials.values, isEmpty);

      expect(await migration.migrate(), isA<Success<void>>());
      expect(credentials.writes, 1);
    },
  );

  test('does not remove a legacy key when scoped copy fails', () async {
    final legacyCredentials = _LegacyCredentials(<String, String>{
      'openai': 'only-copy',
    });
    final credentials = _Credentials()..failWrite = true;
    final migration = LegacyProviderSettingsMigration(
      repository: ProviderProfileRepositoryImpl(storage: _Storage()),
      settings: _Settings(
        const LegacyProviderSettings(
          activeProviderId: 'openai',
          activeModel: '',
          ollamaEndpoint: 'http://localhost:11434',
        ),
      ),
      legacyCredentials: legacyCredentials,
      credentials: credentials,
    );

    final result = await migration.migrate();
    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).error, isA<ProviderMigrationFailure>());
    expect(legacyCredentials.values, containsPair('openai', 'only-copy'));
  });

  test(
    'resumes after legacy deletion failure without duplicate profiles',
    () async {
      final storage = _Storage();
      final repository = ProviderProfileRepositoryImpl(storage: storage);
      final legacyCredentials = _LegacyCredentials(<String, String>{
        'openai': 'only-copy',
      })..failDelete = true;
      final credentials = _Credentials();
      final migration = _migration(repository, legacyCredentials, credentials);

      expect(await migration.migrate(), isA<Failure<void>>());
      expect(
        credentials.values,
        containsPair('clipmind_provider_legacy-openai_api_key', 'only-copy'),
      );
      expect(legacyCredentials.values, containsPair('openai', 'only-copy'));
      expect(
        (await repository.load() as Success<ProviderProfilesDocument>)
            .value
            .legacyMigrationState
            .name,
        'pending',
      );

      legacyCredentials.failDelete = false;
      expect(await migration.migrate(), isA<Success<void>>());
      final profiles =
          (await repository.load() as Success<ProviderProfilesDocument>)
              .value
              .profiles
              .where((profile) => profile.id == 'legacy-openai');
      expect(profiles, hasLength(1));
      expect(legacyCredentials.values, isEmpty);
    },
  );

  test(
    'resumes final metadata failure after legacy credentials are moved',
    () async {
      final storage = _Storage()..failAtWrite = 3;
      final repository = ProviderProfileRepositoryImpl(storage: storage);
      final legacyCredentials = _LegacyCredentials(<String, String>{
        'openai': 'only-copy',
      });
      final credentials = _Credentials();
      final migration = _migration(repository, legacyCredentials, credentials);

      expect(await migration.migrate(), isA<Failure<void>>());
      expect(legacyCredentials.values, isEmpty);
      expect(
        credentials.values,
        containsPair('clipmind_provider_legacy-openai_api_key', 'only-copy'),
      );
      expect(
        (await repository.load() as Success<ProviderProfilesDocument>)
            .value
            .legacyMigrationState
            .name,
        'pending',
      );

      storage.failAtWrite = null;
      expect(await migration.migrate(), isA<Success<void>>());
      final document =
          (await repository.load() as Success<ProviderProfilesDocument>).value;
      expect(document.legacyMigrationState.name, 'completed');
      expect(
        document.profiles.where((profile) => profile.id == 'legacy-openai'),
        hasLength(1),
      );
    },
  );
}

LegacyProviderSettingsMigration _migration(
  ProviderProfileRepositoryImpl repository,
  _LegacyCredentials legacyCredentials,
  _Credentials credentials,
) => LegacyProviderSettingsMigration(
  repository: repository,
  settings: _Settings(
    const LegacyProviderSettings(
      activeProviderId: 'openai',
      activeModel: '',
      ollamaEndpoint: 'http://localhost:11434',
    ),
  ),
  legacyCredentials: legacyCredentials,
  credentials: credentials,
);

final class _Storage implements ProviderProfilesStorage {
  String? value;
  int? failAtWrite;
  int writes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String contents) async {
    if (failAtWrite == writes + 1) throw StateError('metadata write failed');
    writes++;
    value = contents;
  }
}

final class _Settings implements LegacyProviderSettingsSource {
  _Settings(this.value);
  final LegacyProviderSettings value;
  @override
  Future<Result<LegacyProviderSettings?>> load() async =>
      Success<LegacyProviderSettings?>(value);
}

final class _LegacyCredentials implements LegacyProviderCredentialSource {
  _LegacyCredentials(this.values);
  final Map<String, String> values;
  bool failDelete = false;
  @override
  Future<Result<void>> deleteApiKey(String providerId) async {
    if (failDelete) return const Failure<void>(ProviderMigrationFailure());
    values.remove(providerId);
    return const Success<void>(null);
  }

  @override
  Future<Result<String?>> readApiKey(String providerId) async =>
      Success<String?>(values[providerId]);
}

final class _Credentials implements CredentialStore {
  final Map<String, String> values = <String, String>{};
  int writes = 0;
  bool failWrite = false;
  @override
  Future<Result<void>> delete(String credentialId) async {
    values.remove(credentialId);
    return const Success<void>(null);
  }

  @override
  Future<Result<String?>> read(String credentialId) async =>
      Success<String?>(values[credentialId]);
  @override
  Future<Result<void>> write(String credentialId, String secret) async {
    if (failWrite) {
      return const Failure<void>(ProviderCredentialFailure('write failed'));
    }
    writes++;
    values[credentialId] = secret;
    return const Success<void>(null);
  }
}
