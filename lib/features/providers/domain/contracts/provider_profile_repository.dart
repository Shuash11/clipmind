import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';

abstract interface class ProviderProfileRepository {
  Future<Result<ProviderProfilesDocument>> load();
  Future<Result<void>> save(ProviderProfilesDocument document);
  Future<Result<void>> deleteProfile(
    String profileId,
    CredentialStore credentials,
  );
  Future<Result<void>> resumePendingDeletions(CredentialStore credentials);
}
