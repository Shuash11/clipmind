import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_profile_repository.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/provider_connection_result.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';

final class MemoryProfileRepository implements ProviderProfileRepository {
  MemoryProfileRepository(this.document);
  ProviderProfilesDocument document;
  AppFailure? saveFailure;
  AppFailure? deleteFailure;
  @override
  Future<Result<ProviderProfilesDocument>> load() async => Success(document);
  @override
  Future<Result<void>> save(ProviderProfilesDocument value) async {
    if (saveFailure != null) return Failure<void>(saveFailure!);
    document = value;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> deleteProfile(
    String profileId,
    CredentialStore credentials,
  ) async {
    if (deleteFailure != null) return Failure<void>(deleteFailure!);
    document = document.withProfiles(
      document.profiles.where((profile) => profile.id != profileId),
    );
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> resumePendingDeletions(
    CredentialStore credentials,
  ) async => const Success<void>(null);
}

final class MemoryCredentialStore implements CredentialStore {
  final Map<String, String> values = <String, String>{};
  AppFailure? writeFailure;
  AppFailure? deleteFailure;
  final List<String> writes = <String>[];
  final List<String> deletes = <String>[];
  @override
  Future<Result<void>> delete(String credentialId) async {
    deletes.add(credentialId);
    if (deleteFailure != null) return Failure<void>(deleteFailure!);
    values.remove(credentialId);
    return const Success<void>(null);
  }

  @override
  Future<Result<String?>> read(String credentialId) async =>
      Success(values[credentialId]);
  @override
  Future<Result<void>> write(String credentialId, String secret) async {
    writes.add(credentialId);
    if (writeFailure != null) return Failure<void>(writeFailure!);
    values[credentialId] = secret;
    return const Success<void>(null);
  }
}

final class FakeProviderRegistry implements ProviderRegistry {
  FakeProviderRegistry({
    Iterable<ProviderDefinition> definitions = const <ProviderDefinition>[],
    this.adapter,
    Map<String, ModelProviderAdapter>? adapters,
  }) : _adapters = Map<String, ModelProviderAdapter>.from(adapters ?? const {}),
       _definitions = List<ProviderDefinition>.from(definitions);
  final List<ProviderDefinition> _definitions;
  final ModelProviderAdapter? adapter;
  final Map<String, ModelProviderAdapter> _adapters;
  @override
  Iterable<ProviderDefinition> get definitions => _definitions;
  @override
  ModelProviderAdapter? adapterFor(String providerId) =>
      _adapters[providerId] ?? adapter;
  @override
  ProviderDefinition? definitionFor(String providerId) {
    for (final definition in _definitions) {
      if (definition.id == providerId) return definition;
    }
    return null;
  }
}

final class DiscoveringAdapter implements ModelProviderAdapter {
  DiscoveringAdapter(this.models);
  final List<ModelDescriptor> models;
  @override
  Future<Result<List<ModelDescriptor>>> discoverModels(
    ProviderProfile profile,
    CancellationToken token,
  ) async => Success(models);
  @override
  Future<Result<ProviderConnectionResult>> testConnection(
    ProviderProfile profile,
    CancellationToken token,
  ) async => const Success(ProviderConnectionResult(isConnected: true));
  @override
  Future<Result<ModelResponse>> complete(
    ModelRequest request,
    ProviderProfile profile,
    CancellationToken token,
  ) async => throw UnimplementedError();
}
