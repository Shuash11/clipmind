import 'package:clipmind/core/results/result.dart';

final class ProviderValidationFailure extends AppFailure {
  const ProviderValidationFailure(String message)
    : super('provider_validation', message);
}

final class ProviderTransportFailure extends AppFailure {
  const ProviderTransportFailure({
    this.statusCode,
    String message = 'The provider request failed.',
  }) : super('provider_transport', message);

  final int? statusCode;
}

final class ProviderCancellationFailure extends AppFailure {
  const ProviderCancellationFailure()
    : super('provider_cancelled', 'The provider request was cancelled.');
}

final class ProviderCredentialFailure extends AppFailure {
  const ProviderCredentialFailure(String message)
    : super('provider_credential', message);
}

final class ProviderPersistenceFailure extends AppFailure {
  const ProviderPersistenceFailure(String message)
    : super('provider_persistence', message);
}

final class ProviderDeletionPendingFailure extends AppFailure {
  const ProviderDeletionPendingFailure()
    : super(
        'provider_deletion_pending',
        'Provider deletion is pending and will resume safely.',
      );
}

final class ProviderMigrationFailure extends AppFailure {
  const ProviderMigrationFailure()
    : super(
        'provider_migration',
        'Provider settings migration could not be completed safely.',
      );
}

final class ProviderRegistryFailure extends AppFailure {
  const ProviderRegistryFailure()
    : super(
        'provider_registry',
        'Provider adapters could not be registered safely.',
      );
}

final class ProviderNetworkDisabledFailure extends AppFailure {
  const ProviderNetworkDisabledFailure()
    : super(
        'provider_network_disabled',
        'Provider networking is disabled for this initialization.',
      );
}
