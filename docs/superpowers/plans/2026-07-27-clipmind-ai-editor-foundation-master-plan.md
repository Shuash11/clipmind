# ClipMind AI Editor Foundation — Master Implementation Plan

**Goal:** Deliver the approved Windows-first AI-editor foundation without an OpenCode runtime dependency.  
**Architecture:** Feature-modular OOP: pure-Dart domain, adapter data, Flutter/Riverpod presentation, constructor injection, immutable state, and small single-purpose files.  
**Tech Stack:** Flutter 3.44.1, Dart 3.12.1, Riverpod 2.6.1, existing Dio, Drift, Freezed/json_serializable, flutter_secure_storage, media_kit, and FFmpeg dependencies.  
**Prerequisites:** Approved design and controller-owned baseline at `c4c756de2dd8e63b355d5370d831541f4fb491c9`.  
**Links:** [approved spec](../specs/2026-07-27-clipmind-ai-editor-foundation-design.md) · child plans below.

## Global scope and publication status

Only the five child plans implement product behavior. This master has **0 tasks**. The controller runs every command, verifies every RED/GREEN expectation, and resumes the same implementation owner for repairs. Existing dependencies are preferred; no dependency upgrade is permitted unless the controller proves it essential. Generated Freezed, json_serializable, and Drift output is generated only, never handwritten.

Publication status is **local implementation and verification only**. No task stages, commits, pushes, creates a pull request, deploys, releases, tags, or changes CI. Excluded paths include `.opencode/**`, release/version files, CI workflows, installers, `pubspec.yaml`, lockfiles, generated build output, and `lib/data/services/updates/**`.

## Dependency order

1. [Project foundation](2026-07-27-clipmind-project-foundation-plan.md), 4 tasks: shared primitives, canonical non-recursive project state, IDs/commands, migration, durable file-first repository, transactions, and consumer bridge.
2. [Provider platform](2026-07-27-clipmind-provider-platform-plan.md), 4 tasks: catalog, profiles, credentials, transport, protocol adapters, bootstrap, and provider UI.
3. [Agent tools](2026-07-27-clipmind-agent-tools-plan.md), 4 tasks: sanitized requests, registry, validation, local-only payload, Preview/Apply/Cancel/Revise, and legacy boundary.
4. [Tagging and markers](2026-07-27-clipmind-tagging-markers-plan.md), 3 tasks: manual query/UI/ruler and shared transaction integration.
5. [Integration and verification](2026-07-27-clipmind-integration-verification-plan.md), 4 tasks: composition, fixture, generated output, native gates, Windows smoke harness.

Do not begin a child until the controller records its predecessor’s exit criteria. A failure returns to the permanent implementation owner, then the controller reruns the named focused command. Total executable child tasks: **19**.

## Type ownership and dependency rules

| Owner and exact path | Owns | Permitted consumers |
|---|---|---|
| `lib/core/results/result.dart` | `sealed class Result<T>`, direct `Success<T>`/`Failure<T>`, `abstract base class AppFailure` | all features; feature failures may extend `AppFailure` |
| `lib/core/async/cancellation_token.dart` | `CancellationToken`, `CancellationController`, `CancelledException` | provider data and composition |
| `lib/features/projects/domain/ids/id_generator.dart` | pure `IdGenerator` | project command factory only |
| `lib/features/projects/data/ids/uuid_id_generator.dart` | `UuidIdGenerator` adapter | composition root |
| project entities/commands/transactions | snapshots, document, command hierarchy, `ProjectCommandFactory`, `ProjectFileWriteOutcome`, warning-complete `ProjectSaveOutcome`, repository and transaction contracts | agent/tagging/presentation |
| provider domain | `ModelToolDefinition`, `NormalizedModelToolCall`, `ModelRequest`, `ModelResponse`, `ProviderConnectionResult`, `ProviderProfilesDocument`, `ProviderPlatformBootstrap` | agent converts provider values later; provider never imports agent |
| agent domain | sanitized snapshot, `EditPlan`, `ValidatedPlanPayload`, registry, validator | agent presentation; tagging preview |
| tagging | query/layout/controller/widgets only | editor workspace |
| integration | composition and local smoke coordinator/harness | controller verification only |

`Result<T>` direct subclasses stay in `result.dart`. Because failures live in project, provider, agent, and smoke libraries, `AppFailure` is declared exactly `abstract base class AppFailure`; it is not sealed. Every cross-library subclass is `final class ... extends AppFailure`.

`ProjectStateSnapshot` contains editable assets, tracks/clips, tags, markers, and overlays only. `ProjectDocument` contains metadata, `currentState`, revision, `List<PersistedTransactionRecord>`, and cursor. A record contains only `beforeState`, `afterState`, `List<CanonicalCommandSummary>`, `appliedAt`, and source; it never contains a document, metadata, or history. Undo and redo save a changed snapshot and revision without nesting history.

## Traceability matrix

| Requirement | Owning plan/tasks | Required behavioral evidence |
|---|---|---|
| Dart-legal failures and cancellation | Project 1 | provider/project/smoke failures compile as external subclasses; cancellation stops an injected transport |
| deterministic IDs and 18 modular commands | Project 1; Agent 1 | factory allocates all new IDs; no provider/manual new-entity ID; range interior split receives factory ID |
| migration, recoverable protocol, non-recursive history | Project 2–3 | independent injected file failures preserve/recover original; JSON-valid recovery evidence; versioned backup; undo/redo codec round trip |
| authoritative `.cmproj` and rebuildable Drift cache | Project 3–4 | file failure blocks update; every durable file result, including rollback-cleanup warning, publishes a warning-complete success; restart rebuild repairs index |
| profiles, baseline endpoints, security, cancellation | Provider 1–3 | 13 adapters/presets contract-tested; NVIDIA host is `integrate.api.nvidia.com`; secrets absent from JSON/errors |
| resumable deletion and UI | Provider 2–4 | only profile-scoped secrets deleted; pending deletion resumes; manual/discovery fallback works |
| exact canonical tools and privacy boundary | Agent 1–2 | exactly 18 schemas; no paths/bytes/raw FFmpeg/shell accepted; deferred names absent |
| valid payload and approval | Agent 2–3 | payload cannot be swapped; stale plan fails without mutation; cancel has no save |
| shared manual/AI tag-marker transactions | Tagging 1–3 | both paths use command factory and transaction service; AI remains previewed |
| no automatic analysis | Agent 1; Tagging 3; Integration 2 | no registry/prompt/UI capability performs visual, audio, transcript, scene, or object tagging |
| smoke completion | Integration 1–4 | release executable produces one validated temp report without network or UI automation |

## Exact smoke assertion

Launching the Windows release binary in explicit local smoke mode with a legacy v1 fixture must automatically migrate/open the project, render preserved timeline clip data and the Custom OpenAI-compatible provider form with provider networking disabled, write a system-temp JSON report with `projectLoaded`, `providersRendered`, and `timelineRendered` true and `flutterError` null, and exit/cleanup under the Dart harness.

The harness chooses a nonexisting direct child of `Directory.systemTemp`, passes an existing absolute `.cmproj` fixture, always terminates the spawned process, and deletes its report in `finally`. Normal-app interaction/navigation is separately tested; the release harness needs no UI automation.

## Controller checkpoints

Each task names a focused RED command, expected missing behavior, and GREEN command/behavior. The controller—not the implementer—runs them. At each child exit, controller records the focused result, then later executes the integration chain: generation, format check, focused suites, analysis, full tests, Windows release build, Windows interaction test, and smoke harness. `LOCAL_PASS` is a verification verdict, not publication authorization.
