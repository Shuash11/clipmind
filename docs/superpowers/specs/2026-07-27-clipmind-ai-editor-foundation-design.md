# ClipMind AI Editor Foundation Design

**Status:** Approved design, awaiting written-spec user review  
**Date:** 2026-07-27  
**Repository:** `C:\projects\clipmind`  
**Branch:** `opencode/clipmind-build`  
**Inspected HEAD:** `c4c756de2dd8e63b355d5370d831541f4fb491c9`  
**Publication state:** Local only; no commit, push, pull request, or release is authorized.

## 1. Background

ClipMind is an independent, Windows-first Flutter/Dart desktop video editor. The product direction is a CapCut-style desktop MVP delivered in verified milestones. ClipMind must own its provider runtime, credentials, model discovery, structured tool calling, validation, and edit execution. OpenCode is reference material only for an eventual provider catalog; ClipMind has no runtime, server, SDK, process, configuration, credential, or filesystem dependency on OpenCode.

The inspected foundation has these concrete defects and gaps:

- `ProviderRegistry.initializeAll` is never called.
- Saved default provider IDs such as `ollama` do not match registered IDs containing model names, such as `ollama:<model>`.
- Settings has no provider/model configuration, and its model selector is static.
- Structured-output schema construction is malformed and mixes `target_clip_id` with `targetClipId`.
- The agent project snapshot lacks local source mapping, and the pipeline resolves a clip ID as an FFmpeg input path.
- Generic positive-number validation incorrectly rejects valid negative and zero values for bounded controls such as brightness.
- The agent applies and renders without a preview/approval transaction and does not reliably update project state.
- Undo/redo returns operation records, but UI actions do not mutate or save the project.
- Tool rail features are mostly placeholders. Existing tests are green but do not cover these integration paths.

## 2. Goal, Scope, Non-Goals, and Assumptions

### Goal

Establish a safe, independently operated AI-editing foundation: users can configure a supported provider profile, obtain models dynamically or enter a model ID manually, ask for an edit plan, inspect the validated operations, and explicitly apply, cancel, or revise that plan. Applied edits are atomic, persisted, reversible, and use project-local media mappings rather than model-supplied paths.

### First-milestone scope

The first milestone repairs the listed foundation defects and delivers:

1. An independent native provider subsystem.
2. Provider-family phase 1:
   - a generic OpenAI-compatible adapter and the minimum presets NVIDIA, OpenAI, OpenRouter, Groq, Cerebras, DeepSeek, Together AI, Fireworks AI, xAI, and Mistral;
   - dedicated Anthropic, Gemini, and Ollama adapters;
   - custom local or remote OpenAI-compatible profiles.
3. Configurable base URL, API key, secret and non-secret headers, timeout, model discovery, manual model ID, connection testing, and profile enable/disable/delete/select operations.
4. Normalized provider capabilities and tool-call responses, with a central provider-neutral `EditorToolRegistry`.
5. Sanitized planning, typed normalization and validation, plan preview, apply/cancel/revise, atomic non-destructive `EditTransaction`, autosave, rollback, and actual undo/redo.
6. `MediaAsset` introduction with legacy project migration.
7. Basic manual and AI-proposed media tags, colored point/range timeline markers, search/filtering, persistence, and undo.

Automatic visual or audio semantic analysis is explicitly out of scope for this milestone.

### Non-goals

- Supporting every provider in the eventual 75+ provider catalog.
- Cloud-signed provider flows, OAuth, subscription authentication, and long-tail provider-specific features.
- A complete CapCut replacement, advanced rendering, or broad creator-tool coverage.
- Sending media bytes, local paths, FFmpeg command fragments, or shell input to models.
- Any OpenCode dependency.

### Assumptions

- The first validated desktop target is Windows.
- Existing projects may contain `sourcePath` and/or `sourceMediaPaths`; migrations must retain their media references.
- Provider credentials can be stored through supported platform secure storage, while non-secret profile metadata can be stored in normal application storage.
- A provider may omit model discovery; manual model entry remains a supported path.

### Roadmap

1. **Milestone 1 — AI editor foundation:** the scope defined above.
2. **Milestone 2 — signed/cloud provider families:** Azure, AWS Bedrock, Google Vertex, Cloudflare, and multi-field APIs.
3. **Milestone 3 — authentication and catalog breadth:** OAuth/subscription providers and long-tail providers referenced from OpenCode, implemented as ClipMind-owned integrations.
4. **Milestone 4 — timeline essentials:** robust CapCut-style timeline selection, trimming, splitting, tracks, snapping, and project editing workflows.
5. **Milestone 5 — creator tools and rendering/export:** text, captions, audio, transitions, effects, transforms, speed curves, keyframes, color, proxies, and export, including output-side-effect utilities deferred from milestone 1.
6. **Milestone 6 — advanced AI assistance:** transcript, scene, object, and other assisted tagging and editing features, subject to separate privacy and consent design.

## 3. Feature-Modular OOP Architecture

New and refactored code follows feature-modular object-oriented boundaries rather than expanding the current horizontal layout. `lib/core` contains only genuinely shared primitives, such as typed result/error values, identifiers, clock abstractions, and narrow common utilities. Feature modules own their contracts and use cases:

```text
lib/features/providers/{domain,data,presentation}
lib/features/agent/{domain,data,presentation}
lib/features/editor/{domain,data,presentation}
lib/features/projects/{domain,data,presentation}
lib/features/tagging/{domain,data,presentation}
lib/features/rendering/{domain,data}
lib/features/settings/{domain,data,presentation}
test/features/<feature>/{domain,data,presentation}
```

Domain is pure Dart and defines entities, value objects, contracts, use cases, and typed result/error values. Data implements those contracts using HTTP, secure/local storage, project serialization, and FFmpeg integration. Presentation is Flutter/Riverpod state and widgets. Dependencies point inward: presentation depends on domain and injected contracts; data depends on domain; domain does not depend on Flutter, Riverpod, HTTP, filesystem, or FFmpeg.

Classes use constructor injection, one responsibility, immutable entities, and typed result/error types. Lifecycle behavior is explicit rather than dynamic. Feature code must not create giant shared services; cross-feature coordination is through narrow domain contracts and application composition roots.

## 4. Provider Subsystem

### Domain model

- `ProviderDefinition`: a bundled catalog definition for a provider family or preset, including stable definition ID, display metadata, adapter kind, default endpoint, authentication style, discovery support, capability defaults, and catalog version.
- `ProviderProfile`: a user-configured profile with a stable profile ID independent of any model ID. It references a `ProviderDefinition`, stores endpoint, enabled state, selected/manual model state, timeout, and permitted non-secret configuration.
- `ProviderCapabilities`: normalized capabilities such as chat, native tools, strict JSON schema, model discovery, streaming, and supported authentication/endpoint constraints.
- `ModelDescriptor`: a normalized model ID, display name, capability hints, and source (`discovered`, `catalog`, or `manual`).
- `ModelProviderAdapter`: adapter contract for validation, connection testing, discovery, and normalized request/response exchange.
- `ProviderRegistry`: deterministic registry of provider definitions and adapters. Application startup explicitly calls initialization before profiles or defaults are resolved.
- `CredentialStore`: platform-secure storage contract for API keys and secret headers, keyed by profile ID and secret field name.

The provider catalog is bundled, versioned, and owned by ClipMind. It works offline and provides known presets and defaults without a network request. It may be curated from public provider documentation and the OpenCode list as reference material, but its data, runtime, and update lifecycle belong solely to ClipMind.

### Initial adapter families

The generic OpenAI-compatible adapter serves compatible presets and custom profiles. The exact minimum phase-1 preset list is NVIDIA, OpenAI, OpenRouter, Groq, Cerebras, DeepSeek, Together AI, Fireworks AI, xAI, and Mistral. Additional OpenAI-compatible presets are optional in milestone 1 and do not replace contract testing for the minimum list or its profile-configuration behavior. Dedicated adapters handle Anthropic, Gemini, and Ollama protocol differences. Custom profiles select the generic adapter and may target a local or remote compatible endpoint.

Each profile supports base URL, API key, named secret headers, named non-secret headers, timeout, enable/disable, deletion, and selection. URLs are validated before persistence. Discovery invokes the selected adapter directly where supported and produces normalized `ModelDescriptor` values. A user can retain or enter a manual model ID when discovery is unavailable, unauthorized, incomplete, or intentionally bypassed. Testing a connection verifies the configured endpoint, credentials, and selected/manual model where the provider permits it, returning a normalized success or error rather than provider-specific exceptions.

Profile resolution always uses the stable profile ID. A default such as `ollama` is represented by a profile that selects a model; it is never conflated with a registry key such as `ollama:<model>`.

## 5. Agent and Tool Architecture

`AgentRequest` contains a sanitized editor snapshot, the explicit user prompt, selected profile/model references, and only the tool definitions relevant to the request. The response adapter produces a normalized response containing assistant text, `ToolCall` values, protocol metadata, and typed provider errors where applicable.

`EditorToolRegistry` centrally defines the closed provider-neutral allowlist. Each `EditorToolDefinition` declares a stable tool name, strict JSON schema, typed input type, target constraints, limits, and a command handler. Schemas use one canonical field convention; for example, `targetClipId` is used consistently rather than mixing it with `target_clip_id`.

### Milestone 1 tool catalog

The following stable canonical names are the minimum project-mutating agent tool catalog for milestone 1:

- `trim_clip`: non-destructively set a clip's validated in/out range against its referenced media asset.
- `remove_clip_range`: non-destructively remove an explicit validated time range from a clip's project timeline representation. The command is deliberately named for range removal; the ambiguous name `cut` is not a new tool.
- `arrange_clips`: non-destructively set explicit clip ordering, track placement, and/or adjacency according to typed arrangement input. It replaces ambiguous merge or concatenation intent and does not merge source media files.
- `set_clip_speed`: set a validated project playback-speed value for a clip.
- `set_clip_muted`: set a clip's explicit muted state.
- `set_clip_volume`: set a clip's validated volume level.
- `set_clip_transform`: set typed project transform values for resize, fit, and rotation; it does not invoke an untyped render command.
- `set_clip_brightness`: set a validated bounded brightness value, including valid negative and zero values.
- `add_text_overlay`: add a typed text-overlay project entity with validated content, timing, and presentation properties.
- `add_image_overlay`: add a typed image-overlay project entity with validated timing and transform properties. A watermark is an image overlay and must reference an imported `MediaAsset` ID.
- `create_tag`: create a validated project `TagDefinition` with a unique normalized name and valid color.
- `update_tag`: rename and/or recolor an existing `TagDefinition`, with normalized-name collision validation.
- `delete_tag`: delete a `TagDefinition` and atomically remove all of its media and clip assignments; the affected assignments are visible in the plan preview.
- `assign_tag`: assign an existing `TagDefinition` to a `MediaAsset` or `Clip`.
- `unassign_tag`: remove a tag assignment from a `MediaAsset` or `Clip` without deleting the `TagDefinition`.
- `create_marker`, `update_marker`, and `delete_marker`: create, modify, or remove a colored point or validated range `TimelineMarker`.

Every catalog tool creates a non-destructive project mutation only. Each participates in plan preview, validation, atomic apply, rollback, persistence, and plan-level undo/redo through `EditTransaction`. Output-side-effect utilities `extract_audio`, `generate_thumbnail`, and `change_format` are deferred to the rendering/export milestone. They must not masquerade as atomic project-edit tools in milestone 1. Existing code paths for them may remain only when they are not exposed through the new agent registry; implementation planning will address safe legacy handling.

`ToolCall` is parsed into a typed proposed operation. `EditPlan` groups normalized operations, validation results, source prompt metadata, and a status: `draft`, `valid`, `rejected`, `approved`, `applied`, `cancelled`, `revised`, or `failed`. Validation is typed and operation-specific. Bounded numeric controls define inclusive ranges, so valid negative and zero brightness values are accepted when within the declared range; a generic positive-number rule is not used for those controls.

Adapters use native provider tool calling when supported. If it is not supported, they use strict JSON-schema output with the same normalized tool definitions. There is at most one constrained malformed-output repair request, containing no additional project data beyond the original sanitized request and validation feedback. A second malformed response is rejected. Plain assistant prose never causes an edit.

`EditTransaction` holds the complete candidate project mutation, its precondition revision, inverse history information, and persistence outcome. Command handlers create candidate changes only; they do not directly mutate live state. There is no partial apply. Approval promotes a valid plan into one atomic, non-destructive transaction. Cancellation creates no semantic project change. Revision starts a new plan from the user's revised prompt or explicitly selected changes.

Local opaque IDs resolve to media paths only inside approved command handling. Models never receive or provide raw local paths, FFmpeg fragments, or shell commands. Rendering uses typed FFmpeg argument builders, not free-form command text. A clip ID is never treated as an FFmpeg input path.

Legacy operation names are handled only at a compatibility boundary. New providers, `EditorToolRegistry` definitions, and new domain code use only the canonical names above. A legacy `trim`, `change_speed`, `mute`, `overlay_text`, `adjust_brightness`, or `change_volume` operation may be normalized to its canonical equivalent only when it has complete typed inputs. Legacy `resize` and `rotate` may normalize to `set_clip_transform`; `overlay_watermark` may normalize to `add_image_overlay` only when it identifies an imported `MediaAsset`; `cut` may normalize to `remove_clip_range` only when it gives an explicit valid range; and `merge` may normalize to `arrange_clips` only when it supplies an explicit valid arrangement. Legacy `add_tag` and `remove_tag` may normalize only when their intent and target are explicit. Missing, conflicting, or otherwise ambiguous legacy inputs fail visibly without project mutation. This preserves compatibility where safe without promising unsafe semantic conversion.

## 6. Project and Tagging Data Model

`MediaAsset` becomes the canonical local-media entity: asset ID, source locator owned by the project, display metadata, import metadata, and optional project-safe derived metadata. `Clip` references an asset ID rather than embedding an uncontrolled source path. The project snapshot supplied to an agent uses opaque asset and clip IDs plus edit-relevant metadata; local asset-to-source resolution remains in the project/rendering layer.

`TagDefinition` defines a reusable tag ID, name, and color. Media and clips hold tag assignments by tag ID. `TimelineMarker` has an ID, color, label/tag linkage where applicable, and either a point timestamp or a validated start/end range. Manual UI tag CRUD uses the same typed command handlers and transactions as agent operations. AI-proposed tag and marker operations additionally require plan preview and explicit approval before they enter the transaction, persistence, and undo pipeline.

`Project` gains a `schemaVersion` and reversible transaction history. Migration recognizes existing `sourcePath` and `sourceMediaPaths` project formats, creates stable `MediaAsset` records, rewrites clip references to asset IDs, and retains original mappings until the migration is successfully persisted. Before a schema migration, the application writes a backup beside or within the approved project backup mechanism. A migration either saves a valid candidate atomically or leaves the original project usable and reports the persistence error. Migration is idempotent for already migrated projects.

Transaction history stores enough typed inverse state to undo and redo one fully applied plan at a time. UI undo/redo actions invoke real project mutations through the transaction service and autosave the resulting project; they do not merely return operation records.

## 7. UI Behavior

The settings experience includes an **AI Providers** management flow. Users can add a preset or custom OpenAI-compatible profile; configure base URL, API key, secret/non-secret headers, timeout, and model; test it; discover models; enter a manual model ID; enable/disable it; delete it; and choose the active profile. The model selector is dynamic and bound to discovered/catalog/manual model state, not static UI data.

The agent presents an AI plan card before any edit. Each proposed operation visibly identifies its target, time or range, parameters, and validation result. The card offers **Apply**, **Cancel**, and **Revise**. Apply is unavailable for invalid plans. Agent-proposed tagging and marker changes appear in this card just like clip edits.

The media panel supports text search, tag chips, tag-based filtering, and basic tag editing. The clip inspector exposes clip tag assignment. The timeline provides a marker ruler with visible colored point and range markers and editing controls. Marker/tag UI changes persist and participate in undo/redo.

## 8. End-to-End Flows

### Provider setup

1. The user opens AI Providers and selects a catalog preset or custom compatible profile.
2. The profile form validates the supported endpoint scheme, timeout, headers, and non-secret fields.
3. API keys and secret headers are written only through `CredentialStore`; profile metadata is persisted without secret values.
4. The user tests the connection and optionally discovers models through the selected adapter.
5. Normalized discovered models populate the selector; the user may instead provide a manual model ID.
6. The validated, selected profile ID and model selection are persisted. Startup initializes the registry before resolving this default.

### AI edit

1. The user submits a prompt with an active profile/model.
2. The agent builds a sanitized snapshot containing opaque IDs and permitted edit metadata, then sends it with the registry's closed tool definitions.
3. The adapter normalizes native tool calls or strict schema output. One bounded repair is permitted for malformed output.
4. The tool layer parses, normalizes, and validates each call against type, range, target ID, conflict, and operation limits.
5. A valid `EditPlan` is shown to the user. Invalid or unknown calls are rejected and cannot affect the project.
6. On approval, handlers build a complete candidate project and `EditTransaction`; local source resolution and typed rendering arguments occur only as necessary after approval.
7. The transaction atomically persists the candidate project, updates in-memory state only after persistence succeeds, records inverse history, and autosaves.
8. On failure, the candidate is rolled back and the original project remains active. Undo and redo each apply one persisted plan-level transaction.

## 9. Error Handling and Security

Model output is untrusted. Only the closed `EditorToolRegistry` allowlist can be parsed, and unknown, unsafe, malformed, excessive, conflicting, or invalid calls are rejected. Validation enforces types, ranges, IDs, target existence, project revision/preconditions, and operation limits. No model input can produce arbitrary paths, raw FFmpeg, or shell commands. FFmpeg receives typed arguments from local command handlers only.

Secrets are stored only in platform secure storage and are redacted from UI, logs, errors, diagnostics, exports, and serialized profile metadata. Remote endpoints default to HTTPS. HTTP is permitted only for loopback or private-network destinations and must show a warning. Only supported URL schemes are accepted. Media bytes and local paths are not sent to providers by default.

Requests support cancellation, bounded timeouts, and limited idempotent transient retry with backoff. Providers map failures into normalized authentication, authorization, validation, unavailable, timeout, rate-limit, transport, and protocol errors. Persistence errors are never swallowed: candidate project save, rollback, and migration backup failures are typed, surfaced, and leave the last known valid project intact.

## 10. First-Milestone Acceptance Criteria

The milestone is accepted only when all of the following are true:

1. Provider profiles support CRUD, connection testing, selection, and persistence; requests use the correct configured endpoint, model, and credentials.
2. Model discovery is dynamic where supported, with catalog and manual-model fallback where it is not; no secret is disclosed through persistence, UI, logs, or errors. The NVIDIA, OpenAI, OpenRouter, Groq, Cerebras, DeepSeek, Together AI, Fireworks AI, xAI, and Mistral presets are each present and configure the generic compatible adapter correctly; optional presets do not substitute for this set.
3. Mocked contract tests cover every initial adapter, every minimum compatible preset's profile-configuration behavior, and key normalized error paths.
4. No project mutation occurs before approval; cancel has no semantic change; apply is atomic, autosaved, and rolled back on failure; one undo and one redo operate at plan granularity.
5. The milestone-1 tool catalog supports `trim_clip`, `remove_clip_range`, `arrange_clips`, `set_clip_speed`, `set_clip_muted`, `set_clip_volume`, `set_clip_transform`, `set_clip_brightness`, `add_text_overlay`, `add_image_overlay`, `create_tag`, `update_tag`, `delete_tag`, `assign_tag`, `unassign_tag`, `create_marker`, `update_marker`, and `delete_marker` as non-destructive project mutations through the preview/transaction/history path. `delete_tag` previews all affected assignment removals. `extract_audio`, `generate_thumbnail`, and `change_format` are not agent-registry tools in this milestone.
6. Unknown or unsafe tool calls are rejected. Regression coverage fixes every inspected provider, schema, path-resolution, numeric-validation, transaction, and undo/redo defect, and verifies safe canonicalization or visible no-mutation rejection for legacy `trim`, `cut`, `merge`, `change_speed`, `mute`, `overlay_text`, `resize`, `rotate`, `adjust_brightness`, `change_volume`, `overlay_watermark`, `add_tag`, and `remove_tag` operations.
7. Existing `sourcePath` and `sourceMediaPaths` projects migrate without losing media references, produce required backups, and remain usable after a failed migration save.
8. Tags and colored point/range markers support full CRUD, search/filtering, AI proposal through approval, persistence, and undo.

## 11. Testing Strategy and Native Gates

Implementation must keep generated files current and run these native gates in order appropriate to the implementation workflow:

```text
dart format --output=none --set-exit-if-changed lib test
focused provider/tool/transaction/migration/tagging/widget tests
flutter analyze
flutter test
flutter build windows --release
```

The Windows smoke gate launches the release build, opens a migrated fixture project, opens AI Providers, and verifies that the custom provider form and existing timeline data render without an uncaught error. Focused tests cover provider adapters and errors, tool schemas and normalization, transaction atomicity/rollback, migrations/backups, tag/marker behavior, persistence/history, and relevant widgets. Full test coverage complements, rather than replaces, integration-path regressions for the inspected defects.

## 12. Intended Paths and Change Boundaries

This is design-level intended scope, not a requirement to edit every listed path. Expected new module directories are:

```text
lib/features/providers/{domain,data,presentation}
lib/features/agent/{domain,data,presentation}
lib/features/editor/{domain,data,presentation}
lib/features/projects/{domain,data,presentation}
lib/features/tagging/{domain,data,presentation}
lib/features/rendering/{domain,data}
lib/features/settings/{domain,data,presentation}
test/features
```

Likely migration touchpoints are the current project serialization/model code, legacy `sourcePath`/`sourceMediaPaths` readers and writers, project state/autosave/history services, existing provider registry/default resolution, agent snapshot and tool-schema construction, FFmpeg input resolution, settings/provider selectors, editor/media/timeline presentation, and their tests. Existing horizontal `lib/core`, `lib/data`, `lib/domain`, `lib/presentation`, and `lib/state` code is refactored only where needed to establish these boundaries.

Explicit exclusions are `.opencode/tasks.json`, release/version files, CI workflows, installers, generated build output, and unrelated update code.

## 13. Risks and Tradeoffs

- OpenAI-compatible APIs vary despite nominal compatibility; adapter contracts and preset-specific capability metadata contain variation without duplicating the editor protocol.
- Provider APIs drift; the versioned ClipMind catalog and adapter contract enable isolated updates, but cannot guarantee every external service behavior.
- Some models have weak tool calling; strict schema fallback and one bounded repair improve reliability while intentionally rejecting uncertain output.
- Project migration risks user media access; stable asset IDs, retained legacy mappings during migration, backups, and atomic saves favor safety over silent conversion.
- Preview cards show semantic intended changes before the editor renderer matures; they are not a promise of final rendered pixels or audio until later timeline/rendering milestones.
- Provider breadth is deliberately limited by family in milestone 1 to protect core transaction, security, and migration quality.
- Custom headers are powerful and sensitive; secret classification, redaction, supported endpoint validation, and explicit HTTP warnings reduce exposure.
- Windows-only first validation limits early platform assurance; other desktop targets require their own secure-storage, FFmpeg, and smoke validation before support is claimed.

## 14. Definition of Done and User Decision Gates

This design is done when it has received written-spec user review and any implementation-plan approval required by the governing workflow. The implementation milestone is done only after all acceptance criteria and native gates pass locally, including the Windows smoke gate.

Commit, push, pull request creation, and release each require separate explicit authorization. No approval of this written specification authorizes publication, deployment, tagging, or release.
