import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/data/repositories/settings_repository.dart';
import 'anthropic_provider.dart';
import 'gemini_provider.dart';
import 'llm_provider.dart';
import 'nvidia_nim_provider.dart';
import 'ollama_provider.dart';
import 'openai_provider.dart';

class ProviderRegistry {
  final Map<String, LlmProvider> _providers = {};
  final SecureKeyStore _keyStore;
  final SettingsRepository _settingsRepository;

  LlmProvider? _cachedActive;

  ProviderRegistry({
    SecureKeyStore? keyStore,
    SettingsRepository? settingsRepository,
  }) : _keyStore = keyStore ?? SecureKeyStore(),
       _settingsRepository = settingsRepository ?? SettingsRepository();

  void register(LlmProvider provider) {
    _providers[provider.id] = provider;
    _cachedActive = null;
  }

  LlmProvider? get(String id) => _providers[id];

  List<LlmProvider> get all => _providers.values.toList();

  List<String> get providerIds => _providers.keys.toList();

  void unregister(String id) {
    _providers.remove(id);
    _cachedActive = null;
  }

  void dispose() {
    for (final provider in _providers.values) {
      (provider as dynamic).dispose();
    }
    _providers.clear();
  }

  Future<void> initializeAll() async {
    final settings = await _settingsRepository.load();
    final ollamaEndpoint = settings.ollamaEndpoint;
    final uri = Uri.parse(ollamaEndpoint);

    final ollama = OllamaProvider(
      config: OllamaConfig(host: uri.host, port: uri.port),
    );
    register(ollama);

    final anthropicApiKey = await _keyStore.readApiKey('anthropic');
    final anthropic = AnthropicProvider(
      config: AnthropicConfig(apiKey: anthropicApiKey ?? ''),
      keyStore: _keyStore,
    );
    register(anthropic);

    final openaiApiKey = await _keyStore.readApiKey('openai');
    final openai = OpenAiProvider(
      config: OpenAiConfig(apiKey: openaiApiKey ?? ''),
      keyStore: _keyStore,
    );
    register(openai);

    final geminiApiKey = await _keyStore.readApiKey('gemini');
    final gemini = GeminiProvider(
      config: GeminiConfig(apiKey: geminiApiKey ?? ''),
      keyStore: _keyStore,
    );
    register(gemini);

    final nvidiaApiKey = await _keyStore.readApiKey('nvidia_nim');
    final nvidia = NvidiaNimProvider(
      config: NvidiaNimConfig(apiKey: nvidiaApiKey ?? ''),
      keyStore: _keyStore,
    );
    register(nvidia);
  }

  Future<LlmProvider?> getActiveProvider() async {
    if (_cachedActive != null) return _cachedActive;

    final settings = await _settingsRepository.load();
    final providerId = settings.activeProviderId;

    if (providerId.isNotEmpty && _providers.containsKey(providerId)) {
      _cachedActive = _providers[providerId];
      return _cachedActive;
    }

    if (_providers.isNotEmpty) {
      _cachedActive = _providers.values.first;
      return _cachedActive;
    }

    return null;
  }
}
