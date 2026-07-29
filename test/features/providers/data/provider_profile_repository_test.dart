import 'dart:convert';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_codec.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_storage.dart';
import 'package:clipmind/features/providers/data/provider_profile_repository_impl.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trips deterministic non-secret profile metadata', () async {
    final storage = _MemoryStorage();
    final repository = ProviderProfileRepositoryImpl(storage: storage);
    final document = ProviderProfilesDocument(
      schemaVersion: ProviderProfilesCodec.currentSchemaVersion,
      activeProfileId: 'work',
      profiles: <ProviderProfile>[
        ProviderProfile(
          id: 'work',
          providerId: 'openai',
          displayName: 'Work',
          endpoint: Uri.parse('https://example.test/v1'),
          credentialId: 'clipmind_provider_work_api_key',
          headers: const <String, String>{'X-Client': 'clipmind'},
          secretHeaderNames: const <String>['X-Secret'],
          secretHeaderCredentialIds: const <String, String>{
            'X-Secret': 'clipmind_provider_work_header_782d736563726574',
          },
          manualModelIds: const <String>['manual-model'],
        ),
      ],
    );

    expect(await repository.save(document), isA<Success<void>>());
    final metadata = storage.value!;
    expect(metadata, isNot(contains('secret-value')));
    expect(jsonDecode(metadata), isA<Map<Object?, Object?>>());
    final result = await repository.load();
    expect(result, isA<Success<ProviderProfilesDocument>>());
    final restored = (result as Success<ProviderProfilesDocument>).value;
    expect(restored.activeProfileId, 'work');
    expect(restored.profiles.single.secretHeaderNames, <String>['X-Secret']);
  });

  test(
    'rejects an actual secret value that overlaps secret header metadata',
    () async {
      const secret = 'actual-custom-secret-value';
      final storage = _MemoryStorage();
      final repository = ProviderProfileRepositoryImpl(storage: storage);
      final document = ProviderProfilesDocument(
        schemaVersion: ProviderProfilesCodec.currentSchemaVersion,
        profiles: <ProviderProfile>[
          ProviderProfile(
            id: 'work',
            providerId: 'openai',
            displayName: 'Work',
            endpoint: Uri.parse('https://example.test/v1'),
            headers: <String, String>{'X-Client': secret},
            secretHeaderNames: const <String>['x-client'],
            secretHeaderCredentialIds: const <String, String>{
              'x-client': 'clipmind_provider_work_header_782d636c69656e74',
            },
          ),
        ],
      );

      final result = await repository.save(document);
      expect(result, isA<Failure<void>>());
      expect(storage.value, isNull);
      expect(storage.writes, isEmpty);
      expect(result.toString(), isNot(contains(secret)));
    },
  );

  test(
    'rejects malformed and unsupported metadata with stable failures',
    () async {
      final malformed = ProviderProfileRepositoryImpl(
        storage: _MemoryStorage('{"apiKey":"leak"}'),
      );
      final unsupported = ProviderProfileRepositoryImpl(
        storage: _MemoryStorage('{"schemaVersion":99,"profiles":[]}'),
      );

      for (final repository in <ProviderProfileRepositoryImpl>[
        malformed,
        unsupported,
      ]) {
        final result = await repository.load();
        expect(result, isA<Failure<ProviderProfilesDocument>>());
        final failure = (result as Failure<ProviderProfilesDocument>).error;
        expect(failure, isA<ProviderPersistenceFailure>());
        expect(failure.toString(), isNot(contains('leak')));
      }
    },
  );

  test('active selection ignores disabled and pending profiles', () {
    final pending = ProviderProfile(
      id: 'pending',
      providerId: 'openai',
      displayName: 'P',
      endpoint: Uri.parse('https://example.test'),
      deletionPending: true,
    );
    final disabled = ProviderProfile(
      id: 'disabled',
      providerId: 'openai',
      displayName: 'D',
      endpoint: Uri.parse('https://example.test'),
      enabled: false,
    );
    expect(
      ProviderProfilesDocument(
        schemaVersion: 1,
        profiles: <ProviderProfile>[pending],
        activeProfileId: 'pending',
      ).activeProfileId,
      isNull,
    );
    expect(
      ProviderProfilesDocument(
        schemaVersion: 1,
        profiles: <ProviderProfile>[disabled],
        activeProfileId: 'disabled',
      ).activeProfile,
      isNull,
    );
  });

  test(
    'rejects unsafe endpoints and ambiguous metadata without raw payloads',
    () {
      final codec = ProviderProfilesCodec();
      expect(
        codec.encode(
          ProviderProfilesDocument(
            schemaVersion: ProviderProfilesCodec.currentSchemaVersion,
            profiles: <ProviderProfile>[
              ProviderProfile(
                id: 'unsafe',
                providerId: 'openai',
                displayName: 'Unsafe',
                endpoint: Uri.parse('http://example.test/v1'),
              ),
            ],
          ),
        ),
        isA<Failure<String>>(),
      );
      for (final endpoint in <String>[
        'http://example.test/v1',
        'https://user:secret@example.test/v1',
        'https://example.test/v1#fragment',
        'https://example.test/v1?api_key=secret',
        'ftp://example.test/v1',
      ]) {
        final result = codec.decode(
          jsonEncode(_metadataProfile(endpoint: endpoint)),
        );
        expect(result, isA<Failure<ProviderProfilesDocument>>());
        expect(
          (result as Failure<ProviderProfilesDocument>).error.toString(),
          isNot(contains('secret')),
        );
      }

      final duplicate = _metadataProfile(
        profiles: <Map<String, Object?>>[
          _profileJson(id: 'same'),
          _profileJson(id: 'same'),
        ],
      );
      final zeroTimeout = _metadataProfile(
        profiles: <Map<String, Object?>>[_profileJson(timeout: 0)],
      );
      final duplicateHeaders = _metadataProfile(
        profiles: <Map<String, Object?>>[
          _profileJson(secretHeaderNames: <String>['X-Custom', 'x-custom']),
        ],
      );
      final invalidIdentifier = _metadataProfile(
        profiles: <Map<String, Object?>>[_profileJson(id: '../other')],
      );
      final headerOverlap = _metadataProfile(
        profiles: <Map<String, Object?>>[
          _profileJson(
            secretHeaderNames: <String>['X-Custom'],
            headers: <String, String>{'x-custom': 'custom-secret'},
          ),
        ],
      );
      for (final metadata in <Map<String, Object?>>[
        duplicate,
        zeroTimeout,
        duplicateHeaders,
        invalidIdentifier,
        headerOverlap,
      ]) {
        expect(
          codec.decode(jsonEncode(metadata)),
          isA<Failure<ProviderProfilesDocument>>(),
        );
      }
    },
  );
}

Map<String, Object?> _metadataProfile({
  String endpoint = 'https://example.test/v1',
  List<Map<String, Object?>>? profiles,
}) => <String, Object?>{
  'schemaVersion': ProviderProfilesCodec.currentSchemaVersion,
  'activeProfileId': null,
  'legacyMigrationState': 'notStarted',
  'profiles':
      profiles ?? <Map<String, Object?>>[_profileJson(endpoint: endpoint)],
};

Map<String, Object?> _profileJson({
  String id = 'profile',
  String endpoint = 'https://example.test/v1',
  int timeout = 1000,
  List<String> secretHeaderNames = const <String>[],
  Map<String, String> headers = const <String, String>{},
}) => <String, Object?>{
  'id': id,
  'providerId': 'openai',
  'displayName': 'Profile',
  'endpoint': endpoint,
  'credentialId': 'clipmind_provider_${id}_api_key',
  'headers': headers,
  'secretHeaderNames': secretHeaderNames,
  'secretHeaderCredentialIds': <String, String>{},
  'manualModelIds': <String>[],
  'enabled': true,
  'timeoutMilliseconds': timeout,
  'deletionPending': false,
};

final class _MemoryStorage implements ProviderProfilesStorage {
  _MemoryStorage([this.value]);
  String? value;
  final List<String> writes = <String>[];
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String contents) async {
    writes.add(contents);
    value = contents;
  }
}
