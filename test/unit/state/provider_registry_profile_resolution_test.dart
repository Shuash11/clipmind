import 'package:clipmind/data/services/llm/anthropic_provider.dart';
import 'package:clipmind/data/services/llm/gemini_provider.dart';
import 'package:clipmind/data/services/llm/nvidia_nim_provider.dart';
import 'package:clipmind/data/services/llm/ollama_provider.dart';
import 'package:clipmind/data/services/llm/openai_provider.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolution matrix for profile-driven [ProviderRegistry.getActiveProvider].
///
/// NOTE: `modelName` is exposed only by the OpenAI-compatible providers
/// (OpenAI/Ollama/NIM); Gemini/Anthropic are native and assert via `id`,
/// which embeds the same `config.model`.
void main() {
  ProviderRegistry registryWith(ActiveLlmConfig? Function()? resolve) {
    return ProviderRegistry(
      activeProfileResolver:
          resolve == null ? null : () async => resolve(),
    );
  }

  Future<String?> resolveModelName(
    String preset,
    ActiveLlmConfig config,
  ) async {
    final provider =
        await registryWith(() => config).getActiveProvider();
    if (provider is OpenAiProvider) return provider.modelName;
    if (provider is OllamaProvider) return provider.modelName;
    if (provider is NvidiaNimProvider) return provider.modelName;
    if (provider is GeminiProvider) {
      return provider.id.split(':').last;
    }
    if (provider is AnthropicProvider) {
      return provider.id.split(':').last;
    }
    return null;
  }

  group('profile resolution matrix', () {
    test('selected model reaches the provider for every preset', () async {
      final cases = {
        'openai': const ActiveLlmConfig(
          providerId: 'openai',
          apiKey: 'k',
          model: 'gpt-5.4-mini',
        ),
        'anthropic': const ActiveLlmConfig(
          providerId: 'anthropic',
          apiKey: 'k',
          model: 'claude-haiku-4-5',
        ),
        'gemini': const ActiveLlmConfig(
          providerId: 'gemini',
          apiKey: 'k',
          model: 'gemini-2.5-pro',
        ),
        'nvidia_nim': const ActiveLlmConfig(
          providerId: 'nvidia_nim',
          apiKey: 'k',
          model: 'openai/gpt-oss-120b',
        ),
        'ollama': ActiveLlmConfig(
          providerId: 'ollama',
          endpoint: Uri.parse('http://nas:11434'),
          model: 'qwen3:8b',
        ),
      };
      for (final entry in cases.entries) {
        expect(
          await resolveModelName(entry.key, entry.value),
          equals(entry.value.model),
          reason: entry.key,
        );
      }
    });

    test('null model falls back to each provider default', () async {
      final defaults = {
        'openai': 'gpt-4o',
        'anthropic': 'claude-sonnet-5',
        'gemini': 'gemini-3.8-flash',
        'nvidia_nim': 'meta/llama-3.3-70b-instruct',
        'ollama': 'llama3.1',
      };
      for (final entry in defaults.entries) {
        final provider = await registryWith(
          () => ActiveLlmConfig(providerId: entry.key),
        ).getActiveProvider();
        expect(provider?.id, equals('${entry.key}:${entry.value}'),
            reason: entry.key);
      }
    });

    test('ollama maps host, port and model', () async {
      final provider = await registryWith(
        () => ActiveLlmConfig(
          providerId: 'ollama',
          endpoint: Uri.parse('http://192.168.1.50:11435'),
          model: 'llama3.1:8b',
        ),
      ).getActiveProvider();

      expect(provider, isA<OllamaProvider>());
      final ollama = provider as OllamaProvider;
      expect(ollama.config.host, equals('192.168.1.50'));
      expect(ollama.config.port, equals(11435));
      expect(ollama.modelName, equals('llama3.1:8b'));
      expect(ollama.baseUrl, equals('http://192.168.1.50:11435/v1'));
    });

    test('null resolver result falls back to legacy (null)', () async {
      final provider =
          await registryWith(() => null).getActiveProvider();
      expect(provider, isNull);
    });

    test('throwing resolver falls through to legacy (null)', () async {
      final registry = ProviderRegistry(
        activeProfileResolver: () => throw StateError('store offline'),
      );
      expect(await registry.getActiveProvider(), isNull);
    });

    test('unknown/custom providerId resolves to null', () async {
      final provider = await registryWith(
        () => const ActiveLlmConfig(providerId: 'my-custom-thing'),
      ).getActiveProvider();
      expect(provider, isNull);
    });
  });

  group('active cache', () {
    test('second call does not re-resolve', () async {
      var resolutions = 0;
      final registry = ProviderRegistry(
        activeProfileResolver: () async {
          resolutions++;
          return const ActiveLlmConfig(providerId: 'openai');
        },
      );

      final first = await registry.getActiveProvider();
      final second = await registry.getActiveProvider();

      expect(first, isNotNull);
      expect(identical(second, first), isTrue);
      expect(resolutions, equals(1));
    });

    test('invalidateActive forces re-resolution', () async {
      var resolutions = 0;
      final registry = ProviderRegistry(
        activeProfileResolver: () async {
          resolutions++;
          return const ActiveLlmConfig(providerId: 'openai');
        },
      );

      await registry.getActiveProvider();
      registry.invalidateActive();
      final again = await registry.getActiveProvider();

      expect(again, isNotNull);
      expect(resolutions, equals(2));
    });
  });
}
