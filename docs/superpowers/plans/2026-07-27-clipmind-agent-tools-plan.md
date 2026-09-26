# ClipMind Agent Tools Plan

**Goal:** Convert untrusted provider output to a closed validated plan, show Preview/Apply/Cancel/Revise, and apply only its local validated payload through project transactions.  
**Architecture:** agent domain owns snapshots, registry, validation, plans, payload, repair, and legacy boundary. Provider owns protocol-normalized values. Project owns commands, ID allocation, candidate execution, persistence, and history.  
**Tech Stack:** Dart 3.12.1, Flutter/Riverpod 2.6.1, completed project/provider contracts.  
**Prerequisites:** project foundation and provider platform exits.  
**Links:** [spec](../specs/2026-07-27-clipmind-ai-editor-foundation-design.md) · [master](2026-07-27-clipmind-ai-editor-foundation-master-plan.md).

## File-responsibility map

| Path | Responsibility |
|---|---|
| `lib/features/agent/domain/entities/sanitized_project_snapshot.dart`, `tool_call.dart`, `validation_finding.dart` | provider-safe request and findings. |
| `lib/features/agent/domain/entities/validated_plan_payload.dart`, `edit_plan.dart` | local-only candidate/commands/summaries and plan status. |
| `lib/features/agent/domain/entities/editor_tool_definition.dart`, `domain/registry/editor_tool_registry.dart` | exact schemas and factory-facing parsing. |
| `lib/features/agent/domain/services/tool_call_validator.dart`, `agent_planning_service.dart`, `malformed_output_repair_policy.dart`, `legacy_operation_normalizer.dart` | validation and bounded conversion. |
| `lib/features/agent/data/provider_tool_call_normalizer.dart`, `strict_json_schema_encoder.dart` | provider-to-agent conversion and fallback encoding. |
| `lib/features/agent/presentation/providers/*`, `widgets/edit_plan_*`, `revise_plan_dialog.dart` | plan state and approval UI. |
| project `ProjectCommandFactory` and modular command paths | exact owner of new local IDs and commands. |

## Canonical registry

The registry has exactly: `trim_clip`, `remove_clip_range`, `arrange_clips`, `set_clip_speed`, `set_clip_muted`, `set_clip_volume`, `set_clip_transform`, `set_clip_brightness`, `add_text_overlay`, `add_image_overlay`, `create_tag`, `update_tag`, `delete_tag`, `assign_tag`, `unassign_tag`, `create_marker`, `update_marker`, `delete_marker`.

Schemas use camelCase, `additionalProperties:false`, and at most 20 calls. `remove_clip_range` takes clip-local `startMs`/`endMs`; it leaves positive duration. Brightness accepts inclusive `-1.0..1.0`, including zero. New entity inputs never contain IDs. Paths, URLs, media bytes, raw FFmpeg, shell fragments, executables, `extract_audio`, `generate_thumbnail`, and `change_format` are absent. No automatic visual/audio/transcript/scene/object tagger exists.

## Tasks (4)

### 1. Define sanitized values, payload, schemas, and factory conversion

**Create:** all agent-domain entity/registry paths in the map. **Modify:** project command factory only for parser-facing typed construction. **Test:** `editor_tool_registry_test.dart`, `sanitized_project_snapshot_test.dart`, `tool_argument_shape_test.dart`, `validated_plan_payload_test.dart`.

**Test first — controller command:** `flutter test test/features/agent/domain/editor_tool_registry_test.dart test/features/agent/domain/sanitized_project_snapshot_test.dart test/features/agent/domain/tool_argument_shape_test.dart test/features/agent/domain/validated_plan_payload_test.dart`.

**Expected RED:** schemas mix legacy names, provider-visible values can carry local candidates, and callers can supply new entity IDs.

```dart
// lib/features/agent/domain/entities/validated_plan_payload.dart
// ProjectCommand, ProjectStateSnapshot, and CanonicalCommandSummary are prior project-foundation owners.
final class ValidatedPlanPayload {
  const ValidatedPlanPayload({required this.commands, required this.candidateState, required this.summaries});
  final List<ProjectCommand> commands;
  final ProjectStateSnapshot candidateState;
  final List<CanonicalCommandSummary> summaries;
}
// edit_plan.dart: only a valid plan has this non-null field.
final ValidatedPlanPayload? payload;
```

`SanitizedProjectSnapshot.fromDocument` contains revision and opaque IDs, labels, timing, tag and marker metadata; it excludes source locators, output directories, credentials, chat data, thumbnails, FFmpeg, and bytes. `EditPlan` has statuses `draft`, `valid`, `rejected`, `approved`, `applied`, `cancelled`, `revised`, `failed`; only `valid`/`approved`/`applied` can have a payload. `ModelRequest`, JSON fallback, logs, and provider calls never serialize `ValidatedPlanPayload`.

**GREEN command:** rerun RED. **Expected behavior:** exactly 18 names; no secret/local fields in snapshot; provider request has no payload; factory, rather than model/manual input, allocates IDs. **Exit:** registry only exposes provider-owned `ModelToolDefinition` conversion.

### 2. Normalize, validate, execute candidates, and bound repair/legacy input

**Create:** normalizer, strict encoder, validator, repair policy, legacy normalizer, planning service. **Modify:** legacy agent decode facades only. **Test:** normalizer, validator, repair, legacy, malicious-call, and range-removal tests.

**Test first — controller command:** `flutter test test/features/agent/data/provider_tool_call_normalizer_test.dart test/features/agent/domain/tool_call_validator_test.dart test/features/agent/domain/malformed_output_repair_policy_test.dart test/features/agent/domain/legacy_operation_normalizer_test.dart test/features/agent/domain/malicious_tool_call_test.dart`.

**Expected RED:** unsafe calls can reach commands, negative/zero brightness fails, and no local candidate is bound to a plan.

```dart
// test/features/agent/domain/malicious_tool_call_test.dart
// ToolCall/ToolCallValidator are created here; documentWithAsset is declared below in this test file.
test('rejects a path masquerading as an asset ID before factory conversion', () {
  final call = ToolCall(id: 'call-1', name: 'add_image_overlay', arguments: {
    'trackId': 'track-1', 'assetId': r'C:\secret.mp4', 'startMs': 0, 'endMs': 100,
    'x': 0.0, 'y': 0.0, 'width': 10, 'height': 10,
  });
  final result = ToolCallValidator(EditorToolRegistry.standard()).validate([call], documentWithAsset());
  expect(result.commands, isEmpty);
  expect(result.findings.single.code, 'unknown_asset_id');
});
ProjectDocument documentWithAsset() => ProjectDocument.emptyForTest(assetId: 'asset-1', trackId: 'track-1');
```

`ToolCallValidator` rejects unknown names/fields/types, duplicate call IDs, conflicts, excess calls, unsafe strings, invalid targets/ranges/colors/collisions. It calls `ProjectCommandFactory`, then `ProjectCommandExecutor.applyAll`; on success it constructs the exact `ValidatedPlanPayload`. It never accepts a caller-supplied candidate. Interior range tests prove the right ID came from injected factory and asset/tags/transform survive. Provider normalizer maps `NormalizedModelToolCall` to agent `ToolCall`. Strict fallback only accepts `{summary,operations}` entries of `{name,arguments}`. Repair makes one callback with original sanitized request and findings; a second malformed result is rejected. Legacy names map only with complete unambiguous typed input, otherwise a finding and no command.

**GREEN command:** rerun RED. **Expected behavior:** native/fallback normalized equivalently; one repair only; zero/negative brightness pass; unsafe/ambiguous calls create no command. **Exit:** payload is locally constructed from the current document only.

### 3. Require payload-bound approval and transaction apply

**Create:** agent feature providers/notifier and plan-card widgets. **Modify:** agent chat/top toolbar and legacy pipeline façade. **Test:** notifier, card, chat panel, stale-plan/payload-integrity tests.

**Test first — controller command:** `flutter test test/features/agent/presentation/edit_plan_notifier_test.dart test/features/agent/presentation/edit_plan_card_test.dart test/features/agent/presentation/edit_plan_payload_integrity_test.dart test/widget/agent_chat_panel_test.dart`.

**Expected RED:** apply can rebuild/swap a candidate, stale plans mutate current state, or cancel saves.

```dart
// test/features/agent/presentation/edit_plan_payload_integrity_test.dart
// FakeProjectTransactionService and validPlan are local declarations in this test file.
test('apply uses only the plan payload and rejects stale base revision', () async {
  final service = FakeProjectTransactionService(currentRevision: 4);
  final notifier = EditPlanNotifier(service: service, plan: validPlan(baseRevision: 3));
  await notifier.apply('plan-1');
  expect(service.applyCalls, 0);
  expect(notifier.state.plan!.status, EditPlanStatus.failed);
  expect(notifier.state.plan!.payload, isNotNull);
});
```

`apply(planId)` checks current plan ID, status valid/approved, exact base revision, and non-null payload. It creates `EditTransaction` using exactly payload commands/candidate/summaries; it does not accept candidate or command arguments and does not rerun parsing. It marks applied only after `Success<ProjectSaveOutcome>`, publishes document/warning through project state, and keeps failed plan/payload diagnostic state. `cancel` has no transaction. `revise` marks prior plan revised and generates a new plan ID/payload. Tests attempt a swapped candidate and stale base revision; both have zero service call/mutation.

**GREEN command:** rerun RED. **Expected behavior:** plan identity/payload integrity holds, cancel has zero apply/save, valid apply creates one persisted record, revision creates a distinct plan. **Exit:** no direct agent-to-FFmpeg execution path.

### 4. Retire active legacy execution and lock regression behavior

**Create:** regression tests for canonical schema, direct-execution absence, preview/history, and deferred tools. **Modify:** legacy pipeline/stage facades; remove only inactive legacy files after integration checks. **Test:** those regressions.

**Test first — controller command:** `flutter test test/features/agent/regression/canonical_schema_case_test.dart test/features/agent/regression/preview_transaction_history_test.dart test/features/agent/regression/deferred_tools_test.dart`.

**Expected RED:** active legacy mapper bypasses preview or advertises unsupported output utilities.

Regression tests exercise public planning/presentation behavior rather than grepping source: submit canonical call; assert preview and no save; cancel; assert no save; approve; assert transaction. A legacy ambiguous `cut` has a visible finding/no mutation. Active façade has no rendering executor or local path resolver. **GREEN command:** rerun RED. **Expected behavior:** canonical only, bounded compatibility, no unsafe execution. **Exit criteria:** exact registry, sanitized request, local payload, approval gate, plan-level history. **Exclusions:** provider protocols, manual tagging UI, automatic analysis, publication, generated output. **Next plan:** tagging and markers.
