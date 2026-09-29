import 'package:clipmind/data/services/llm/anthropic_provider.dart';
import 'package:clipmind/data/services/llm/custom_openai_compatible_provider.dart';
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
    if (provider is CustomOpenAiCompatibleProvider) {
      return provider.modelName;
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
        'nvidia': const ActiveLlmConfig(
          providerId: 'nvidia',
          apiKey: 'k',
          model: 'qwen/qwen3-next-80b-a3b-instruct',
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

    test('nvidia catalog id and nvidia_nim alias share one service',
        () async {
      for (final id in ['nvidia', 'nvidia_nim']) {
        final provider = await registryWith(
          () => ActiveLlmConfig(
            providerId: id,
            apiKey: 'k',
            model: 'meta/llama-3.3-70b-instruct',
          ),
        ).getActiveProvider();

        expect(provider, isA<NvidiaNimProvider>(), reason: id);
        expect(
          (provider as NvidiaNimProvider).modelName,
          equals('meta/llama-3.3-70b-instruct'),
          reason: id,
        );
      }
    });

    test('compat presets resolve through the custom adapter', () async {
      const endpoints = {
        'openrouter': 'https://openrouter.ai/api/v1',
        'groq': 'https://api.groq.com/openai/v1',
        'cerebras': 'https://api.cerebras.ai/v1',
        'deepseek': 'https://api.deepseek.com',
        'together': 'https://api.together.xyz/v1',
        'fireworks': 'https://api.fireworks.ai/inference/v1',
        'xai': 'https://api.x.ai/v1',
        'mistral': 'https://api.mistral.ai/v1',
      };
      for (final entry in endpoints.entries) {
        final provider = await registryWith(
          () => ActiveLlmConfig(
            providerId: entry.key,
            endpoint: Uri.parse(entry.value),
            apiKey: 'k',
            model: 'some/model',
          ),
        ).getActiveProvider();

        expect(
          provider,
          isA<CustomOpenAiCompatibleProvider>(),
          reason: entry.key,
        );
        expect(
          (provider as CustomOpenAiCompatibleProvider).modelName,
          equals('some/model'),
          reason: entry.key,
        );
        expect(provider.supportsToolCalling, isTrue, reason: entry.key);
      }
    });

    test('compat preset without model or endpoint resolves to null',
        () async {
      final noModel = await registryWith(
        () => ActiveLlmConfig(
          providerId: 'groq',
          endpoint: Uri.parse('https://api.groq.com/openai/v1'),
        ),
      ).getActiveProvider();
      expect(noModel, isNull);

      final noEndpoint = await registryWith(
        () => const ActiveLlmConfig(
          providerId: 'groq',
          model: 'llama-3.3-70b-versatile',
        ),
      ).getActiveProvider();
      expect(noEndpoint, isNull);
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

    test('usable custom profile resolves with the selected model', () async {
      final provider = await registryWith(
        () => ActiveLlmConfig(
          providerId: 'custom',
          endpoint: Uri.parse('https://openrouter.ai/api/v1'),
          apiKey: 'sk-test',
          model: 'openai/gpt-oss-120b',
        ),
      ).getActiveProvider();

      expect(provider, isA<CustomOpenAiCompatibleProvider>());
      final custom = provider as CustomOpenAiCompatibleProvider;
      expect(custom.modelName, equals('openai/gpt-oss-120b'));
      expect(custom.id, equals('custom:openai/gpt-oss-120b'));
      expect(custom.supportsToolCalling, isTrue);
      expect(await custom.resolveApiKey(), equals('sk-test'));
    });

    test('custom without a selected model resolves to null', () async {
      for (final model in [null, '', '   ']) {
        final provider = await registryWith(
          () => ActiveLlmConfig(
            providerId: 'custom',
            endpoint: Uri.parse('https://openrouter.ai/api/v1'),
            model: model,
          ),
        ).getActiveProvider();
        expect(provider, isNull, reason: 'model=$model');
      }
    });

    test('custom without an endpoint resolves to null', () async {
      final provider = await registryWith(
        () => const ActiveLlmConfig(
          providerId: 'custom',
          model: 'openai/gpt-oss-120b',
        ),
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
