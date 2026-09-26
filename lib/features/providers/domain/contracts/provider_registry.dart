import '../entities/provider_definition.dart';
import 'model_provider_adapter.dart';

abstract interface class ProviderRegistry {
  Iterable<ProviderDefinition> get definitions;
  ProviderDefinition? definitionFor(String providerId);
  ModelProviderAdapter? adapterFor(String providerId);
}
