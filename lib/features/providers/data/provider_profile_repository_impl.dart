import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_codec.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_storage.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_profile_repository.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_credential_reference.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';

final class ProviderProfileRepositoryImpl implements ProviderProfileRepository {
  factory ProviderProfileRepositoryImpl({
    required ProviderProfilesStorage storage,
    ProviderProfilesCodec? codec,
  }) => ProviderProfileRepositoryImpl._(
    storage,
    codec ?? ProviderProfilesCodec(),
  );

  ProviderProfileRepositoryImpl._(this._storage, this._codec);

  final ProviderProfilesStorage _storage;
  final ProviderProfilesCodec _codec;

  @override
  Future<Result<void>> deleteProfile(
    String profileId,
    CredentialStore credentials,
  ) async {
    final loaded = await load();
    if (loaded case Failure<ProviderProfilesDocument>(:final error)) {
      return Failure<void>(error);
    }
    final document = (loaded as Success<ProviderProfilesDocument>).value;
    ProviderProfile? profile;
    for (final candidate in document.profiles) {
      if (candidate.id == profileId) {
        profile = candidate;
        break;
      }
    }
    if (profile == null) return const Success<void>(null);

    // This is the durability boundary: no credential is touched before it.
    final marked = profile.copyWith(deletionPending: true);
    final markedDocument = document.withProfiles(
      document.profiles.map((item) => item.id == profileId ? marked : item),
    );
    final markerSave = await save(markedDocument);
    if (markerSave case Failure<void>()) return markerSave;

    final references = _credentialReferences(marked);
    if (references == null) {
      return const Failure<void>(ProviderDeletionPendingFailure());
    }
    for (final reference in references) {
      Result<void> deleted;
      try {
        deleted = await credentials.delete(reference);
      } catch (_) {
        return const Failure<void>(ProviderDeletionPendingFailure());
      }
      if (deleted case Failure<void>()) {
        return const Failure<void>(ProviderDeletionPendingFailure());
      }
    }

    final finalDocument = markedDocument.withProfiles(
      markedDocument.profiles.where((item) => item.id != profileId),
    );
    final saved = await save(finalDocument);
    if (saved case Failure<void>()) {
      return const Failure<void>(ProviderDeletionPendingFailure());
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<ProviderProfilesDocument>> load() async {
    try {
      final stored = await _storage.read();
      if (stored == null || stored.isEmpty) {
        return Success<ProviderProfilesDocument>(
          ProviderProfilesDocument(
            schemaVersion: ProviderProfilesCodec.currentSchemaVersion,
            profiles: const <ProviderProfile>[],
          ),
        );
      }
      return _codec.decode(stored);
    } catch (_) {
      return const Failure<ProviderProfilesDocument>(
        ProviderPersistenceFailure(
          'Provider profile metadata could not be read.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> resumePendingDeletions(
    CredentialStore credentials,
  ) async {
    final loaded = await load();
    if (loaded case Failure<ProviderProfilesDocument>(:final error)) {
      return Failure<void>(error);
    }
    final pendingIds = (loaded as Success<ProviderProfilesDocument>)
        .value
        .profiles
        .where((profile) => profile.deletionPending)
        .map((profile) => profile.id)
        .toList(growable: false);
    var hasPendingFailure = false;
    for (final profileId in pendingIds) {
      final result = await deleteProfile(profileId, credentials);
      if (result is Failure<void>) hasPendingFailure = true;
    }
    return hasPendingFailure
        ? const Failure<void>(ProviderDeletionPendingFailure())
        : const Success<void>(null);
  }

  @override
  Future<Result<void>> save(ProviderProfilesDocument document) async {
    final encoded = _codec.encode(document);
    if (encoded case Failure<String>(:final error)) return Failure<void>(error);
    try {
      await _storage.write((encoded as Success<String>).value);
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(
        ProviderPersistenceFailure(
          'Provider profile metadata could not be saved.',
        ),
      );
    }
  }

  Set<String>? _credentialReferences(ProviderProfile profile) {
    try {
      final apiKey = ProviderCredentialReference.apiKey(profile.id);
      final references = <String>{apiKey};
      if (profile.credentialId != null) {
        // API credential metadata may only point at this profile's canonical
        // key. A prefix comparison would allow profile-id collisions.
        if (profile.credentialId != apiKey) return null;
      }
      final secretHeaderNames = <String>{
        ...profile.secretHeaderNames,
        ...profile.secretHeaderCredentialIds.keys,
      };
      for (final headerName in secretHeaderNames) {
        final expected = ProviderCredentialReference.secretHeader(
          profile.id,
          headerName,
        );
        final reference = profile.secretHeaderCredentialIds[headerName];
        if (reference != null && reference != expected) {
          return null;
        }
        references.add(expected);
      }
      return references;
    } on ArgumentError {
      return null;
    }
  }
}
