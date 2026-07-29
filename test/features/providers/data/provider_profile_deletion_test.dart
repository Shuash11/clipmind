import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_codec.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_storage.dart';
import 'package:clipmind/features/providers/data/provider_profile_repository_impl.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'marks metadata before scoped deletion and preserves unrelated credentials',
    () async {
      final storage = _Storage();
      final repository = ProviderProfileRepositoryImpl(storage: storage);
      final credentials = _Credentials(<String, String>{
        'clipmind_provider_one_api_key': 'one',
        'clipmind_provider_one_header_782d736563726574': 'secret',
        'clipmind_provider_two_api_key': 'two',
      });
      await repository.save(_document());

      expect(
        await repository.deleteProfile('one', credentials),
        isA<Success<void>>(),
      );
      expect(
        credentials.values,
        containsPair('clipmind_provider_two_api_key', 'two'),
      );
      expect(
        credentials.values.containsKey('clipmind_provider_one_api_key'),
        isFalse,
      );
      final document =
          (await repository.load() as Success<ProviderProfilesDocument>).value;
      expect(document.profiles.map((profile) => profile.id), <String>['two']);
      expect(storage.writes[1], contains('"deletionPending":true'));
    },
  );

  test('initial pending-marker failure deletes zero credentials', () async {
    final storage = _Storage();
    final repository = ProviderProfileRepositoryImpl(storage: storage);
    final credentials = _Credentials(<String, String>{
      'clipmind_provider_one_api_key': 'one',
      'clipmind_provider_one_header_782d736563726574': 'secret',
    });
    await repository.save(_document());
    storage.failAtWrite = storage.writes.length + 1;

    final result = await repository.deleteProfile('one', credentials);
    expect(result, isA<Failure<void>>());
    expect(credentials.deleted, isEmpty);
    expect(
      credentials.values,
      containsPair('clipmind_provider_one_api_key', 'one'),
    );
  });

  test(
    'final metadata failure retains pending profile and unrelated profile',
    () async {
      final storage = _Storage();
      final repository = ProviderProfileRepositoryImpl(storage: storage);
      final credentials = _Credentials(<String, String>{
        'clipmind_provider_one_api_key': 'one',
        'clipmind_provider_one_header_782d736563726574': 'secret',
        'clipmind_provider_two_api_key': 'two',
      });
      await repository.save(_document());
      storage.failAtWrite = storage.writes.length + 2;
      final failedFinalSave = await repository.deleteProfile(
        'one',
        credentials,
      );
      expect(failedFinalSave, isA<Failure<void>>());
      final document =
          (await repository.load() as Success<ProviderProfilesDocument>).value;
      final one = document.profiles.firstWhere(
        (profile) => profile.id == 'one',
      );
      final two = document.profiles.firstWhere(
        (profile) => profile.id == 'two',
      );
      expect(one.deletionPending, isTrue);
      expect(two.deletionPending, isFalse);
      expect(
        credentials.values,
        containsPair('clipmind_provider_two_api_key', 'two'),
      );
    },
  );

  test('resume is idempotent after a partial credential deletion', () async {
    final storage = _Storage();
    final repository = ProviderProfileRepositoryImpl(storage: storage);
    final credentials = _Credentials(<String, String>{
      'clipmind_provider_one_api_key': 'one',
      'clipmind_provider_one_header_782d736563726574': 'secret',
      'clipmind_provider_two_api_key': 'two',
    })..failAtDelete = 2;
    await repository.save(_document());

    expect(
      await repository.deleteProfile('one', credentials),
      isA<Failure<void>>(),
    );
    expect(
      credentials.values.containsKey('clipmind_provider_one_api_key'),
      isFalse,
    );
    expect(
      credentials.values,
      containsPair('clipmind_provider_one_header_782d736563726574', 'secret'),
    );

    credentials.failAtDelete = null;
    expect(
      await repository.resumePendingDeletions(credentials),
      isA<Success<void>>(),
    );
    expect(
      await repository.resumePendingDeletions(credentials),
      isA<Success<void>>(),
    );
    expect(
      credentials.values,
      containsPair('clipmind_provider_two_api_key', 'two'),
    );
    expect(
      (await repository.load() as Success<ProviderProfilesDocument>)
          .value
          .profiles
          .map((profile) => profile.id),
      <String>['two'],
    );
  });
}

ProviderProfilesDocument _document() => ProviderProfilesDocument(
  schemaVersion: ProviderProfilesCodec.currentSchemaVersion,
  activeProfileId: 'one',
  profiles: <ProviderProfile>[
    ProviderProfile(
      id: 'one',
      providerId: 'openai',
      displayName: 'One',
      endpoint: Uri.parse('https://one.test'),
      credentialId: 'clipmind_provider_one_api_key',
      secretHeaderCredentialIds: const <String, String>{
        'X-Secret': 'clipmind_provider_one_header_782d736563726574',
      },
    ),
    ProviderProfile(
      id: 'two',
      providerId: 'openai',
      displayName: 'Two',
      endpoint: Uri.parse('https://two.test'),
      credentialId: 'clipmind_provider_two_api_key',
    ),
  ],
);

final class _Storage implements ProviderProfilesStorage {
  String? value;
  bool failWrite = false;
  int? failAtWrite;
  final List<String> writes = <String>[];
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String contents) async {
    if (failWrite || failAtWrite == writes.length + 1) {
      throw StateError('write failed');
    }
    writes.add(contents);
    value = contents;
  }
}

final class _Credentials implements CredentialStore {
  _Credentials(this.values);
  final Map<String, String> values;
  bool failDelete = false;
  int? failAtDelete;
  final List<String> deleted = <String>[];
  @override
  Future<Result<void>> delete(String credentialId) async {
    deleted.add(credentialId);
    if (failDelete || failAtDelete == deleted.length) {
      return const Failure<void>(ProviderCredentialFailure('failed'));
    }
    values.remove(credentialId);
    return const Success<void>(null);
  }

  @override
  Future<Result<String?>> read(String credentialId) async =>
      Success<String?>(values[credentialId]);
  @override
  Future<Result<void>> write(String credentialId, String secret) async {
    values[credentialId] = secret;
    return const Success<void>(null);
  }
}
