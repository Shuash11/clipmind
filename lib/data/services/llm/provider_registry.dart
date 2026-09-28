import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/data/repositories/settings_repository.dart';
import 'anthropic_provider.dart';
import 'gemini_provider.dart';
import 'llm_provider.dart';
import 'nvidia_nim_provider.dart';
import 'ollama_provider.dart';
import 'openai_provider.dart';

/// Profile-driven active-provider config (plain data carrier; the state
/// layer resolves the live profile — data never imports features).
class ActiveLlmConfig {
  /// Preset id: 'openai' | 'anthropic' | 'gemini' | 'nvidia_nim' | 'ollama'.
  final String providerId;

  /// Ollama host:port (null for cloud providers).
  final Uri? endpoint;

  /// Resolved from the credential store; never logged.
  final String? apiKey;

  /// Profile selected model id (null = provider default).
  final String? model;

  const ActiveLlmConfig({
    required this.providerId,
    this.endpoint,
    this.apiKey,
    this.model,
  });
}

/// Resolves the live active-provider profile. Wired by the state layer;
/// null = no profile selected.
typedef ActiveProfileResolver = Future<ActiveLlmConfig?> Function();

class ProviderRegistry {
  final Map<String, LlmProvider> _providers = {};
  final SecureKeyStore _keyStore;
  final SettingsRepository _settingsRepository;
  final ActiveProfileResolver? activeProfileResolver;

  LlmProvider? _cachedActive;

  ProviderRegistry({
    SecureKeyStore? keyStore,
    SettingsRepository? settingsRepository,
    this.activeProfileResolver,
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

  /// Drop the cached active provider so the next [getActiveProvider]
  /// re-resolves (call after profile/model/credential changes).
  void invalidateActive() {
    _cachedActive = null;
  }

  /// Resolve the active provider.
  ///
  /// P0 fix: the registry was never populated at runtime — [initializeAll]
  /// had no call sites since the initial commit, so this always returned
  /// null and every agent run failed with "No LLM provider configured".
  /// Resolution is now profile-driven first: a wired
  /// [activeProfileResolver] builds the Gen A provider on demand; the
  /// legacy settings path below is unchanged (and still truthfully
  /// returns null for the empty registry).
  Future<LlmProvider?> getActiveProvider() async {
    if (_cachedActive != null) return _cachedActive;

    final resolver = activeProfileResolver;
    if (resolver != null) {
      try {
        final config = await resolver();
        if (config != null) {
          final provider = _providerFromConfig(config);
          if (provider != null) {
            _cachedActive = provider;
            return _cachedActive;
          }
        }
      } catch (_) {
        // Fall through to the legacy path (no crash on resolver errors).
      }
    }

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

  /// Build the Gen A provider for a resolved profile config.
  ///
  /// Named params with explicit null override Dart defaults, so the
  /// null-coalescing to each provider's class default is mandatory.
  /// Unknown/custom ids return null (graceful — same as today; the custom
  /// adapter lands in Phase 2).
  LlmProvider? _providerFromConfig(ActiveLlmConfig config) {
    final model = config.model;
    final apiKey = config.apiKey ?? '';
    switch (config.providerId) {
      case 'openai':
        return OpenAiProvider(
          config: OpenAiConfig(apiKey: apiKey, model: model ?? 'gpt-4o'),
          keyStore: _keyStore,
        );
      case 'anthropic':
        return AnthropicProvider(
          config: AnthropicConfig(
            apiKey: apiKey,
            model: model ?? 'claude-sonnet-5',
          ),
          keyStore: _keyStore,
        );
      case 'gemini':
        return GeminiProvider(
          config: GeminiConfig(
            apiKey: apiKey,
            model: model ?? 'gemini-3.8-flash',
          ),
          keyStore: _keyStore,
        );
      case 'nvidia_nim':
        return NvidiaNimProvider(
          config: NvidiaNimConfig(
            apiKey: apiKey,
            model: model ?? 'meta/llama-3.3-70b-instruct',
          ),
          keyStore: _keyStore,
        );
      case 'ollama':
        final endpoint = config.endpoint;
        return OllamaProvider(
          config: OllamaConfig(
            host: endpoint?.host ?? 'localhost',
            port: endpoint?.port ?? 11434,
            model: model ?? 'llama3.1',
            apiKey: apiKey,
          ),
          keyStore: _keyStore,
        );
      default:
        return null;
    }
  }
}
