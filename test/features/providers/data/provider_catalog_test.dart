import 'package:clipmind/features/providers/data/catalog/provider_catalog.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog is the exact approved preset catalog', () {
    expect(ProviderCatalog.presets, hasLength(13));
    expect(
      ProviderCatalog.presets.map(
        (definition) => definition.baseUri.toString(),
      ),
      <String>[
        'https://integrate.api.nvidia.com/v1',
        'https://api.openai.com/v1',
        'https://openrouter.ai/api/v1',
        'https://api.groq.com/openai/v1',
        'https://api.cerebras.ai/v1',
        'https://api.deepseek.com',
        'https://api.together.xyz/v1',
        'https://api.fireworks.ai/inference/v1',
        'https://api.x.ai/v1',
        'https://api.mistral.ai/v1',
        'https://api.anthropic.com/v1',
        'https://generativelanguage.googleapis.com/v1beta',
        'http://127.0.0.1:11434',
      ],
    );
    expect(
      ProviderCatalog.byId('nvidia')!.baseUri.host,
      'integrate.api.nvidia.com',
    );
  });

  test('model discovery is explicit for each provider family', () {
    final anthropic = ProviderCatalog.byId('anthropic')!;
    expect(anthropic.protocol, ProviderProtocol.anthropic);
    expect(anthropic.modelDiscoveryIsAvailable, isFalse);
    expect(
      ProviderCatalog.byId('openai')!.modelDiscoveryRelativePath,
      'models',
    );
    expect(
      ProviderCatalog.byId('gemini')!.modelDiscoveryRelativePath,
      'models',
    );
    expect(
      ProviderCatalog.byId('ollama')!.modelDiscoveryRelativePath,
      'api/tags',
    );
  });
}
