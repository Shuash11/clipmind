import 'package:clipmind/features/providers/domain/entities/provider_capabilities.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';

/// The built-in provider presets. Custom profiles are intentionally separate.
final class ProviderCatalog {
  ProviderCatalog._();

  static final List<ProviderDefinition>
  presets = List.unmodifiable(<ProviderDefinition>[
    _compatible(
      'nvidia',
      'NVIDIA compatible',
      'https://integrate.api.nvidia.com/v1',
    ),
    _compatible('openai', 'OpenAI compatible', 'https://api.openai.com/v1'),
    _compatible(
      'openrouter',
      'OpenRouter compatible',
      'https://openrouter.ai/api/v1',
    ),
    _compatible('groq', 'Groq compatible', 'https://api.groq.com/openai/v1'),
    _compatible(
      'cerebras',
      'Cerebras compatible',
      'https://api.cerebras.ai/v1',
    ),
    _compatible('deepseek', 'DeepSeek compatible', 'https://api.deepseek.com'),
    _compatible(
      'together',
      'Together AI compatible',
      'https://api.together.xyz/v1',
    ),
    _compatible(
      'fireworks',
      'Fireworks AI compatible',
      'https://api.fireworks.ai/inference/v1',
    ),
    _compatible('xai', 'xAI compatible', 'https://api.x.ai/v1'),
    _compatible('mistral', 'Mistral compatible', 'https://api.mistral.ai/v1'),
    ProviderDefinition(
      id: 'anthropic',
      displayName: 'Anthropic dedicated',
      baseUri: Uri(scheme: 'https', host: 'api.anthropic.com', path: '/v1'),
      protocol: ProviderProtocol.anthropic,
      capabilities: const ProviderCapabilities(supportsTools: true),
    ),
    ProviderDefinition(
      id: 'gemini',
      displayName: 'Gemini dedicated',
      baseUri: Uri(
        scheme: 'https',
        host: 'generativelanguage.googleapis.com',
        path: '/v1beta',
      ),
      protocol: ProviderProtocol.gemini,
      capabilities: const ProviderCapabilities(
        supportsModelDiscovery: true,
        supportsTools: true,
      ),
      modelDiscoveryRelativePath: 'models',
    ),
    ProviderDefinition(
      id: 'ollama',
      displayName: 'Ollama dedicated',
      baseUri: Uri(scheme: 'http', host: '127.0.0.1', port: 11434),
      protocol: ProviderProtocol.ollama,
      capabilities: const ProviderCapabilities(
        supportsModelDiscovery: true,
        supportsTools: true,
      ),
      modelDiscoveryRelativePath: 'api/tags',
    ),
  ]);

  static ProviderDefinition _compatible(
    String id,
    String displayName,
    String base,
  ) => ProviderDefinition(
    id: id,
    displayName: displayName,
    baseUri: Uri.parse(base),
    protocol: ProviderProtocol.compatible,
    capabilities: const ProviderCapabilities(
      supportsModelDiscovery: true,
      supportsTools: true,
    ),
    modelDiscoveryRelativePath: 'models',
  );

  static ProviderDefinition? byId(String providerId) {
    for (final definition in presets) {
      if (definition.id == providerId) return definition;
    }
    return null;
  }
}
