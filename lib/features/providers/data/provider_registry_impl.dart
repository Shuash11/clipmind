import 'package:clipmind/features/providers/data/adapters/anthropic_adapter.dart';
import 'package:clipmind/features/providers/data/adapters/gemini_adapter.dart';
import 'package:clipmind/features/providers/data/adapters/ollama_adapter.dart';
import 'package:clipmind/features/providers/data/adapters/openai_compatible_adapter.dart';
import 'package:clipmind/features/providers/data/catalog/provider_catalog.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';

/// Immutable service-id registry. Model identifiers are never registration keys.
final class ProviderRegistryImpl implements ProviderRegistry {
  ProviderRegistryImpl({
    Iterable<ProviderDefinition>? definitions,
    required Map<String, ModelProviderAdapter> adapters,
  }) : _definitions = List.unmodifiable(
         List<ProviderDefinition>.from(definitions ?? ProviderCatalog.presets),
       ),
       _adapters = Map.unmodifiable(
         Map<String, ModelProviderAdapter>.from(adapters),
       ) {
    final ids = _definitions.map((definition) => definition.id).toSet();
    if (ids.length != _definitions.length ||
        _adapters.keys.any(
          (id) => id != customOpenAiCompatibleProviderId && !ids.contains(id),
        )) {
      throw ArgumentError(
        'Provider registry identifiers must be catalog service IDs.',
      );
    }
  }

  factory ProviderRegistryImpl.standard({
    required ProviderHttpTransport transport,
    required CredentialStore credentials,
    Iterable<ProviderDefinition>? definitions,
  }) {
    final catalog = List<ProviderDefinition>.from(
      definitions ?? ProviderCatalog.presets,
    );
    final compatibleIds = catalog
        .where(
          (definition) => definition.protocol == ProviderProtocol.compatible,
        )
        .map((definition) => definition.id)
        .followedBy(const <String>[customOpenAiCompatibleProviderId])
        .toList(growable: false);
    final compatible = OpenAiCompatibleAdapter(
      transport: transport,
      credentials: credentials,
      providerIds: compatibleIds,
    );
    final anthropic = AnthropicAdapter(
      transport: transport,
      credentials: credentials,
    );
    final gemini = GeminiAdapter(
      transport: transport,
      credentials: credentials,
    );
    final ollama = OllamaAdapter(
      transport: transport,
      credentials: credentials,
    );
    final adapters = <String, ModelProviderAdapter>{};
    for (final definition in catalog) {
      switch (definition.protocol) {
        case ProviderProtocol.compatible:
          adapters[definition.id] = compatible;
          break;
        case ProviderProtocol.anthropic:
          adapters[definition.id] = anthropic;
          break;
        case ProviderProtocol.gemini:
          adapters[definition.id] = gemini;
          break;
        case ProviderProtocol.ollama:
          adapters[definition.id] = ollama;
          break;
      }
    }
    adapters[customOpenAiCompatibleProviderId] = compatible;
    return ProviderRegistryImpl(definitions: catalog, adapters: adapters);
  }

  final List<ProviderDefinition> _definitions;
  final Map<String, ModelProviderAdapter> _adapters;

  @override
  Iterable<ProviderDefinition> get definitions => _definitions;

  @override
  ModelProviderAdapter? adapterFor(String providerId) => _adapters[providerId];

  @override
  ProviderDefinition? definitionFor(String providerId) {
    for (final definition in _definitions) {
      if (definition.id == providerId) return definition;
    }
    return null;
  }
}
