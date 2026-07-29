# ClipMind Provider Platform Plan

**Goal:** Build ClipMind-owned profiles, catalog, credentials, adapters, bootstrap, and dynamic provider UI without importing agent implementation types.  
**Architecture:** provider domain is pure Dart; data owns URI policy, persistence, secure storage, transport, and protocols; presentation is Flutter/Riverpod.  
**Tech Stack:** existing Dart 3.12.1, Dio 5.7.0, flutter_secure_storage 9.2.4, Flutter/Riverpod 2.6.1.  
**Prerequisites:** Project foundation exit, especially `Result`, `AppFailure`, and cancellation.  
**Links:** [spec](../specs/2026-07-27-clipmind-ai-editor-foundation-design.md) · [master](2026-07-27-clipmind-ai-editor-foundation-master-plan.md).

## File-responsibility map

| Path | Responsibility |
|---|---|
| `lib/features/providers/domain/entities/model_tool_definition.dart`, `normalized_model_tool_call.dart`, `provider_connection_result.dart` | provider-owned normalized tool/connection values. |
| `lib/features/providers/domain/requests/model_request.dart`, `responses/model_response.dart` | provider request/response values. |
| `lib/features/providers/domain/entities/provider_definition.dart`, `provider_capabilities.dart`, `model_descriptor.dart`, `provider_profile.dart`, `provider_profiles_document.dart` | catalog and non-secret profile state. |
| `lib/features/providers/domain/contracts/model_provider_adapter.dart`, `provider_registry.dart`, `credential_store.dart`, `provider_profile_repository.dart` | pure contracts. |
| `lib/features/providers/domain/provider_platform_bootstrap.dart` | provider-domain bootstrap contract/result. |
| `lib/features/providers/data/catalog/*`, `policy/*`, `security/*`, `http/provider_http_transport.dart`, `adapters/*`, `provider_*_impl.dart` | ClipMind-owned implementations. |
| `lib/features/providers/presentation/providers/*`, `screens/ai_providers_screen.dart`, `widgets/*` | profile state and UI. |

Provider owns `ModelToolDefinition`, `NormalizedModelToolCall`, `ModelRequest`, `ModelResponse`, `ProviderConnectionResult`, `ProviderProfilesDocument`, and `ProviderPlatformBootstrap`. Agent later maps these values to its own types. Provider code never imports `lib/features/agent/**`.

## Exact catalog and contracts

Compatible preset bases are NVIDIA `https://integrate.api.nvidia.com/v1`, OpenAI `https://api.openai.com/v1`, OpenRouter `https://openrouter.ai/api/v1`, Groq `https://api.groq.com/openai/v1`, Cerebras `https://api.cerebras.ai/v1`, DeepSeek `https://api.deepseek.com`, Together AI `https://api.together.xyz/v1`, Fireworks AI `https://api.fireworks.ai/inference/v1`, xAI `https://api.x.ai/v1`, and Mistral `https://api.mistral.ai/v1`. Dedicated bases are Anthropic `https://api.anthropic.com/v1`, Gemini `https://generativelanguage.googleapis.com/v1beta`, and Ollama `http://127.0.0.1:11434`.

Direct discovery is `models` for compatible/Gemini, `api/tags` for Ollama, and unavailable for Anthropic. Every unavailable or failed discovery exposes catalog/manual entry; no guessed endpoint occurs. `ProviderEndpointResolver.resolve` strips a leading relative slash, adds a trailing base slash, clears query/fragment, and uses `Uri.resolve`, preserving `/v1`, `/api/v1`, `/openai/v1`, and `/inference/v1` prefixes.

`CancellationToken` is the project/core pure contract. Transport calls `throwIfCancelled` before each attempt and races request work with `whenCancelled`; cancellation maps to a typed provider cancellation/transport failure. Discovery/test GETs retry only timeout/reset/429/5xx at most twice after the initial attempt. Completion is not retried unless the adapter explicitly supplies an idempotency key.

## Tasks (4)

### 1. Define provider domain, catalog, endpoint policy, and transport seam

**Create:** every provider-domain path in the map except bootstrap implementation, catalog/policy/transport/redactor data paths, and contract tests. **Modify:** none. **Test:** `provider_contract_test.dart`, `provider_catalog_test.dart`, `provider_endpoint_resolver_test.dart`, `provider_url_policy_test.dart`, `provider_http_transport_test.dart`.

**Test first — controller command:** `flutter test test/features/providers/domain/provider_contract_test.dart test/features/providers/data/provider_catalog_test.dart test/features/providers/data/provider_endpoint_resolver_test.dart test/features/providers/data/provider_url_policy_test.dart test/features/providers/data/provider_http_transport_test.dart`.

**Expected RED:** normalized provider types and prefix-preserving safe endpoint resolution do not exist.

```dart
// test/features/providers/data/provider_endpoint_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/features/providers/data/policy/provider_endpoint_resolver.dart';
void main() => test('resolver preserves a provider API prefix', () {
  final base = Uri.parse('https://api.fireworks.ai/inference/v1');
  expect(ProviderEndpointResolver.resolve(base, '/chat/completions').toString(),
      'https://api.fireworks.ai/inference/v1/chat/completions');
});
```

Use `abstract base class AppFailure` from the project prerequisite for provider failure classes. URL policy accepts HTTPS and only loopback/RFC1918 HTTP with `ProviderUrlWarning.insecureLocalHttp`; rejects public HTTP, non-http(s), user-info, fragments, empty host. Catalog tests enumerate every required preset and assert NVIDIA host is never `build.nvidia.com`.

**GREEN command:** rerun RED. **Expected behavior:** exact bases/flags, safe URI behavior, redacted typed errors, cancellation, and maximum three attempts. **Exit:** no provider type in agent paths.

### 2. Persist profiles and securely resume profile-scoped deletion

**Create:** `secure_credential_store.dart`, `provider_profile_repository_impl.dart`, repository/credential fakes and tests. **Modify:** settings/key transition facades. **Test:** profile repository, deletion, legacy migration, and redaction tests.

**Test first — controller command:** `flutter test test/features/providers/data/provider_profile_repository_test.dart test/features/providers/data/provider_profile_deletion_test.dart test/features/providers/data/legacy_provider_settings_migration_test.dart test/features/providers/data/provider_redactor_test.dart`.

**Expected RED:** secrets reach JSON/errors, provider-name keys conflate profiles, or deletion can remove unrelated secrets.

```dart
// test/features/providers/data/provider_profile_deletion_test.dart
// This test defines its local credential/profile fakes in the same file.
test('pending deletion retains unrelated profile', () async {
  final credentials = MemoryCredentials(failId: 'p1');
  final repository = MemoryProfiles(['p1', 'p2']);
  expect(await repository.deleteProfile('p1', credentials), isA<Failure<void>>());
  expect(repository.pendingIds, {'p1'});
  credentials.failId = null;
  await repository.resumePendingDeletions(credentials);
  expect(repository.ids, {'p2'});
  expect(credentials.deleted, everyElement(startsWith('clipmind_provider_p1_')));
});
```

The test’s `MemoryCredentials` and `MemoryProfiles` implement the exact contracts created in this task and are declared in that test file. Algorithm: persist `deletionPending:true`; delete only `clipmind_provider_<profileId>_api_key` and same-profile secret-header keys; remove metadata and persist. Secret deletion or final metadata failure leaves pending metadata and returns `ProviderDeletionPendingFailure`; bootstrap resumes it. No `clearAll`/`deleteAll` operation is permitted. Active selection ignores pending profiles. Profile JSON retains no secret values; errors/logs use `ProviderRedactor`.

**GREEN command:** rerun RED. **Expected behavior:** restarted deletion finishes only p1, p2 survives, profile IDs stay model-independent, and redaction tests find no secret. **Exit:** metadata and secrets have distinct persistence boundaries.

### 3. Implement protocol adapters and bootstrap

**Create:** compatible, Anthropic, Gemini, Ollama adapters; registry implementation; bootstrap implementation. **Modify:** `main.dart`, `app.dart`, legacy provider registry/settings provider bridge. **Test:** one adapter contract test per family plus bootstrap test.

**Test first — controller command:** `flutter test test/features/providers/data/adapters/openai_compatible_adapter_test.dart test/features/providers/data/adapters/anthropic_adapter_test.dart test/features/providers/data/adapters/gemini_adapter_test.dart test/features/providers/data/adapters/ollama_adapter_test.dart test/features/providers/data/provider_platform_bootstrap_test.dart`.

**Expected RED:** startup skips registry initialization, model IDs become registry keys, and responses are not provider-normalized.

```dart
// test/features/providers/data/adapters/openai_compatible_adapter_test.dart
// RecordingTransport is declared here and implements the ProviderHttpTransport contract from task 1.
test('compatible adapter parses zero brightness tool argument', () async {
  final transport = RecordingTransport.json('{"choices":[{"message":{"tool_calls":[{"id":"c1","function":{"name":"set_clip_brightness","arguments":"{\\"clipId\\":\\"c\\",\\"brightness\\":0}"}}]}}]}');
  final result = await adapterFor(transport).complete(requestForBrightness(), profileForOpenAi(), tokenNotCancelled());
  final call = (result as Success<ModelResponse>).value.toolCalls.single;
  expect(call.arguments['brightness'], 0);
});
```

The same test file declares `RecordingTransport`, `adapterFor`, `requestForBrightness`, `profileForOpenAi`, and `tokenNotCancelled`; their return types are the exact task-1 provider/core contracts. Compatible adapters use `models` and `chat/completions`, Bearer auth, and native function tools. Anthropic uses `messages`, `x-api-key`, `anthropic-version`, and `input_schema`, with catalog/manual discovery only. Gemini uses `models` and `{model}:generateContent`, API-key query, and function declarations. Ollama uses `api/tags`/`api/chat`. All return provider-owned `ModelResponse` or typed failure.

`ProviderPlatformBootstrap.initialize({required bool networkEnabled})` loads catalog and profiles, resumes deletion, registers adapters before resolving active selection, performs one legacy migration, and disables transport calls when `networkEnabled` is false.

**GREEN command:** rerun RED. **Expected behavior:** exact request paths/payloads, typed error mapping, no Anthropic invented discovery, one bootstrap lifecycle, and no smoke-mode request. **Exit:** provider is usable with no agent import.

### 4. Build dynamic provider management UI

**Create:** provider presentation graph, notifier, screen, profile form/list, dynamic selector. **Modify:** settings screen and legacy model-selector bridge. **Test:** AI provider screen/form/dynamic selector/model selector widget tests.

**Test first — controller command:** `flutter test test/features/providers/presentation/ai_providers_screen_test.dart test/features/providers/presentation/provider_profile_form_test.dart test/features/providers/presentation/dynamic_model_selector_test.dart test/features/providers/presentation/model_selector_dropdown_test.dart`.

**Expected RED:** static model choices and no custom compatible profile form or manual fallback.

```dart
// test/features/providers/presentation/dynamic_model_selector_test.dart
// TestProviderRepository is declared in this test and implements task-1 ProviderProfileRepository.
testWidgets('manual model remains selectable after discovery failure', (tester) async {
  await tester.pumpWidget(providerTestApp(TestProviderRepository.discoveryUnavailable()));
  await tester.enterText(find.byKey(const ValueKey('manual-model-id')), 'local-model');
  await tester.pump();
  expect(find.text('local-model'), findsOneWidget);
  expect(find.text('Discovery unavailable; enter a model ID.'), findsOneWidget);
});
```

`ProviderProfileNotifier` uses repository/adapter contracts only, exposes catalog/discovered/manual models, and retains redacted typed errors. Form validates URL, headers, timeout, enabled state, secrets, test/discovery/delete actions. It never repopulates a secret. Custom profiles select the compatible adapter. **GREEN command:** rerun RED. **Expected behavior:** dynamic discovery/manual fallback, pending/disabled selection block, unsafe URL block, and no static list. **Exit criteria:** all phase-1 providers configure correctly and credentials remain secure. **Exclusions:** agent conversion, project transactions, automatic analysis, publication, generated output, dependency upgrades. **Next plan:** agent tools.
