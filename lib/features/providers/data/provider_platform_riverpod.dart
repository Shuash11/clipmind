import 'dart:async';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_profile_repository.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/features/providers/presentation/providers/provider_profile_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The startup override makes provider state available without activating UI.
final providerPlatformBootstrapResultProvider =
    Provider<Result<ProviderPlatformBootstrapResult>>((ref) {
      return const Failure<ProviderPlatformBootstrapResult>(
        ProviderPersistenceFailure(
          'Provider platform initialization is unavailable.',
        ),
      );
    });

/// Alias retained as a semantic runtime composition point for widget tests.
final providerPlatformRuntimeProvider = providerPlatformBootstrapResultProvider;

final providerProfileRepositoryProvider = Provider<ProviderProfileRepository>((
  ref,
) {
  final result = ref.watch(providerPlatformRuntimeProvider);
  if (result case Success<ProviderPlatformBootstrapResult>(:final value)) {
    final repository = value.repository;
    if (repository != null) return repository;
  }
  return const _UnavailableRepository();
});

final providerCredentialStoreProvider = Provider<CredentialStore>((ref) {
  final result = ref.watch(providerPlatformRuntimeProvider);
  if (result case Success<ProviderPlatformBootstrapResult>(:final value)) {
    final credentials = value.credentials;
    if (credentials != null) return credentials;
  }
  return const _UnavailableCredentials();
});

final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final result = ref.watch(providerPlatformRuntimeProvider);
  if (result case Success<ProviderPlatformBootstrapResult>(:final value)) {
    return value.registry;
  }
  return const _UnavailableRegistry();
});

final providerProfileIdFactoryProvider = Provider<ProviderIdFactory>((ref) {
  var sequence = 0;
  return () => 'profile_${DateTime.now().microsecondsSinceEpoch}_${sequence++}';
});

final providerCancellationControllerFactoryProvider =
    Provider<ProviderCancellationControllerFactory>(
      (ref) => CancellationController.new,
    );

final providerProfileNotifierProvider =
    StateNotifierProvider<ProviderProfileNotifier, ProviderProfileState>((ref) {
      final runtime = ref.watch(providerPlatformRuntimeProvider);
      ProviderProfileState? initial;
      if (runtime case Success<ProviderPlatformBootstrapResult>(:final value)) {
        initial = ProviderProfileState(
          profiles: value.profiles,
          activeProfileId: value.activeProfileId,
          selectedProfileId: value.activeProfileId,
          schemaVersion: value.schemaVersion,
          legacyMigrationState: value.legacyMigrationState,
          action: ProviderProfileAction.loading,
        );
      } else if (runtime case Failure<ProviderPlatformBootstrapResult>(
        :final error,
      )) {
        initial = ProviderProfileState(
          action: ProviderProfileAction.idle,
          failure: error,
          failureMessage: error.message,
        );
      }
      final notifier = ProviderProfileNotifier(
        repository: ref.watch(providerProfileRepositoryProvider),
        credentials: ref.watch(providerCredentialStoreProvider),
        registry: ref.watch(providerRegistryProvider),
        cancellationControllerFactory: ref.watch(
          providerCancellationControllerFactoryProvider,
        ),
        idFactory: ref.watch(providerProfileIdFactoryProvider),
        initialState: initial,
      );
      unawaited(notifier.load());
      return notifier;
    });

final class _UnavailableRepository implements ProviderProfileRepository {
  const _UnavailableRepository();
  Failure<T> _failure<T>() => Failure<T>(
    const ProviderPersistenceFailure(
      'Provider platform initialization is unavailable.',
    ),
  );
  @override
  Future<Result<void>> deleteProfile(
    String profileId,
    CredentialStore credentials,
  ) async => _failure<void>();
  @override
  Future<Result<ProviderProfilesDocument>> load() async =>
      _failure<ProviderProfilesDocument>();
  @override
  Future<Result<void>> resumePendingDeletions(
    CredentialStore credentials,
  ) async => _failure<void>();
  @override
  Future<Result<void>> save(ProviderProfilesDocument document) async =>
      _failure<void>();
}

final class _UnavailableCredentials implements CredentialStore {
  const _UnavailableCredentials();
  Failure<T> _failure<T>() => Failure<T>(
    const ProviderCredentialFailure('Provider credentials are unavailable.'),
  );
  @override
  Future<Result<void>> delete(String credentialId) async => _failure<void>();
  @override
  Future<Result<String?>> read(String credentialId) async =>
      _failure<String?>();
  @override
  Future<Result<void>> write(String credentialId, String secret) async =>
      _failure<void>();
}

final class _UnavailableRegistry implements ProviderRegistry {
  const _UnavailableRegistry();
  @override
  Iterable<ProviderDefinition> get definitions => const <ProviderDefinition>[];
  @override
  ModelProviderAdapter? adapterFor(String providerId) => null;
  @override
  ProviderDefinition? definitionFor(String providerId) => null;
}
