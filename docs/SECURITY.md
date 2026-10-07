# Security Rules

ClipMind is a local desktop app, and user API keys are its most sensitive data. These rules are normative: code and the canary suite (`test/features/providers/security/key_egress_canary_test.dart`) enforce them, and any change touching credential handling must keep them true.

## Rule 1 — Keys live only in OS secure storage

**Rule:** API keys and secret header values live exclusively in the OS secure store, addressed by profile-scoped credential references. They never appear in profile metadata, settings, the database, exports, or docs.
**Why:** the profile document is plain JSON that is read, backed up, and synced like any other file — only the OS secure store gets keychain-grade protection.
**Enforcement:**
- `ProviderCredentialReference` (`lib/features/providers/domain/provider_credential_reference.dart`) builds the keychain keys (`clipmind_provider_<profileId>_api_key`, `…_header_<hexName>`) and is metadata-only by design.
- `SecureCredentialStore` (`lib/features/providers/data/security/secure_credential_store.dart`) is the only read/write path for profile credentials; its failure values omit both the backend exception and the secret.
- `ProviderProfilesCodec._hasSecretInMetadata` (`lib/features/providers/data/profiles/provider_profiles_codec.dart`) rejects metadata that would carry a secret (sensitive header names, key-bearing endpoint queries) — a defensive check, not a storage mechanism.
- Gen A keeps its own OS-secure-store naming scheme in `SecureKeyStore` (`lib/data/local/secure_key_store.dart`); the resolver bridge falls back to it when the profile credential is empty. Both naming schemes are in scope of Rules 1–2.
- Canary groups: "Gen B credential storage", "Gen B metadata codec", "Gen B legacy migration".

## Rule 2 — Keys egress only to the configured provider

**Rule:** A key is transmitted only to its configured provider endpoint, in exactly one place per request: the designated auth header — or, where the provider contract mandates it (Gemini), the provider's `key` query parameter.
**Why:** every extra transmission point is an unverified leak channel; a single construction point keeps the canary's "exactly one header" assertion meaningful.
**Enforcement:**
- `ProviderAdapterBase.headersFor` / `apiKeyFor` (`lib/features/providers/data/adapters/provider_adapter_support.dart`) is the single Gen B construction point; adapters assemble no auth headers themselves.
- The Gen A bridge (`lib/state/agent_providers.dart`) resolves the active profile credential into `ActiveLlmConfig` for the provider only; providers fall back to `SecureKeyStore` when it is empty (`lib/data/services/llm/provider_registry.dart`).
- Gemini's `key` query parameter is provider-contract-mandated in both stacks and stays inside the same egress boundary: Gen A sets `queryParameters: {'key': apiKey}` (`lib/data/services/llm/gemini_provider.dart`), and Gen B injects `'key': apiKeyFor(profile)` into the request URI (`lib/features/providers/data/adapters/gemini_adapter.dart:212-217`).
- Canary tests: "headersFor carries the canary only in the designated header" (group "Gen B egress"); "SecureKeyStore fallback resolves the canary into the auth header only" (group "Gen A legacy fallback and error surfaces").

## Rule 3 — Never logged, telemetry'd, or exported

**Rule:** No key may appear in logs, error strings, failure objects, UI, or any exported or diagnostic artifact. Any surface that renders request, response, or failure context must route through `ProviderRedactor` first.
**Why:** observability surfaces are the widest leak channel — once a key reaches a log line or error message it is effectively public.
**Enforcement:**
- `ProviderRedactor` (`lib/features/providers/data/security/provider_redactor.dart`) redacts explicit secrets, bearer tokens, sensitive JSON fields, header names, and URI query parameters.
- The transport boundary `RetryingProviderHttpTransport._failureFor` (`lib/features/providers/data/http/provider_http_transport.dart`) never includes request values in failures and consumes the redactor as the single supplied-credential boundary.
- Untrusted provider bodies: `redactApiKeyFromError` (`lib/data/services/llm/provider_error_redaction.dart`) strips a key echoed in a 400 body before it reaches an error message (Anthropic/Gemini `_formatDioError`).
- Secrets are never logged (`lib/state/agent_providers.dart` and `lib/data/services/llm/provider_registry.dart` both state it); UI fields mask values and are never rendered (canary "UI masking").
- Canary tests: "redacts the canary as an explicit secret and inside bearer, URLs, JSON, and headers"; "provider error paths never echo the canary from request context"; "provider 400 messages redact a canary echoed in the response body"; "connection status streams emit typed states only"; "transport failures and request/response toStrings never carry the canary".

## Rule 4 — Agent-session verification uses scalars and hashes

**Rule:** Scripts and commands that touch secrets must assert on scalars — lengths, digests, booleans, presence/absence — and must never render secret values. Test data always uses obvious fake sentinels, never real keys.
**Why:** an agent transcript or command output is itself a log; printing a secret to verify it turns verification into disclosure.
**Enforcement:** a review-enforced convention, anchored by the canary suite — `key_egress_canary_test.dart` asserts Boolean presence/absence over a fake sentinel and is the template for new verification commands.

## Rule 5 — Raw failure causes stay in memory

**Rule:** Raw causes (e.g. `DioException`) may be held in memory while handling a failure, but must never be serialized or crash-reported without redaction.
**Why:** a serialized cause smuggles request context — including auth headers — outside the redaction boundary.
**Enforcement:**
- Gen B maps raw exceptions to typed failures with no cause field (`ProviderTransportFailure`, `provider_http_transport.dart`).
- Gen A attaches the `DioException` only as the in-memory `ProviderFailure.cause` and formats structural messages (`_formatDioError`); untrusted response bodies pass through `redactApiKeyFromError` (Rule 3). The canary test "provider error paths never echo the canary from request context" asserts message and `toString()` stay key-free.

## Contributor checklist

When adding a provider, adapter, or diagnostic surface:

- [ ] Persist secrets only via the credential store and `ProviderCredentialReference` — never in profile documents or new storage.
- [ ] Build auth headers/queries only via `headersFor` (Gen B) or `resolveApiKey`/`authHeaders` (Gen A); never log the result.
- [ ] Route any rendering of request/response context through `ProviderRedactor`; add no raw logging.
- [ ] Extend `key_egress_canary_test.dart` for every new egress path or surface (adapter, error path, UI).
- [ ] If a new egress channel is unavoidable (e.g. provider-contract query auth), document it in this file first.
- [ ] Keep test data fake and verify on scalars/hashes only.
