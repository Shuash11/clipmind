# ClipMind Tagging and Timeline Markers Plan

**Goal:** Deliver manual tag CRUD/assignment, search/filter, and colored point/range markers using the same factory, commands, and transaction service as AI-approved proposals.  
**Architecture:** project owns entities, command factory, handlers, codec, and transactions; tagging owns pure query/layout/controller and Flutter/Riverpod interaction.  
**Tech Stack:** Dart 3.12.1 and Flutter/Riverpod 2.6.1.  
**Prerequisites:** project foundation and agent-tools exits.  
**Links:** [spec](../specs/2026-07-27-clipmind-ai-editor-foundation-design.md) · [master](2026-07-27-clipmind-ai-editor-foundation-master-plan.md).

## File-responsibility map

| Path | Responsibility |
|---|---|
| `lib/features/tagging/domain/tag_query.dart`, `marker_filter.dart`, `marker_layout.dart` | immutable search/filter/layout. |
| `lib/features/tagging/domain/tagging_controller.dart` | manual intents delegated to `ProjectCommandFactory`. |
| `lib/features/tagging/presentation/providers/tagging_providers.dart` | immutable selection/query and transaction composition. |
| `lib/features/tagging/presentation/widgets/media_panel.dart`, `asset_tag_chips.dart`, `clip_tag_inspector.dart`, `tag_editor_dialog.dart` | manual media/tag controls. |
| `lib/features/tagging/presentation/widgets/marker_ruler.dart`, `marker_editor_dialog.dart`, `marker_filter_menu.dart` | ruler and marker controls. |
| `lib/features/agent/presentation/widgets/edit_plan_card.dart`, `edit_plan_operation_row.dart` | summaries from AI candidate preview. |

Tagging declares no second project, tag, marker, command, transaction, repository, or ID generator type. It never directly mutates lists or calls repository save.

## Tasks (3)

### 1. Add query/layout and shared manual command intent

**Create:** tagging domain files and provider composition. **Modify:** project tag/marker handlers only to expose complete affected summaries. **Test:** `tagging_controller_test.dart`, `tag_query_test.dart`, `marker_layout_test.dart`, `tag_marker_command_invariants_test.dart`.

**Test first — controller command:** `flutter test test/features/tagging/domain/tagging_controller_test.dart test/features/tagging/domain/tag_query_test.dart test/features/tagging/domain/marker_layout_test.dart test/features/tagging/domain/tag_marker_command_invariants_test.dart`.

**Expected RED:** manual UI can construct caller-owned IDs or update tag/marker collections outside transactions.

```dart
// test/features/tagging/domain/tagging_controller_test.dart
// SequenceIds is local; ProjectCommandFactory is the completed project-foundation owner.
final class SequenceIds implements IdGenerator {
  SequenceIds(this.value); final String value; bool _used = false;
  @override String next() { if (_used) throw StateError('unexpected ID'); _used = true; return value; }
}
test('manual create tag obtains the ID from factory', () {
  final controller = TaggingController(ProjectCommandFactory(SequenceIds('tag-9')));
  expect(controller.createTag(name: ' Travel ', color: '#123456').tagId, 'tag-9');
});
```

`TagQuery` lowercases/trims text and requires every selected tag. `MarkerFilter` filters without mutation. `MarkerLayout` provides an 8px point target and 4px minimum range band; marker ID is the deterministic overlap tie-break. Handlers validate normalized name uniqueness, `#RRGGBB`, target existence, assignments, and point/range shape. `DeleteTagCommand` summary contains every removed asset/clip assignment.

**GREEN command:** rerun RED. **Expected behavior:** factory-issued IDs, validation failure with no candidate, delete summary targets exact assignments. **Exit:** manual and AI commands are indistinguishable at the project boundary.

### 2. Build accessible transaction-only media and marker UI

**Create:** all tagging presentation widgets in the map. **Modify:** editor/tool rail/timeline integration. **Test:** media panel, tag dialog, clip inspector, marker ruler/editor, and timeline bridge tests.

**Test first — controller command:** `flutter test test/features/tagging/presentation/media_panel_test.dart test/features/tagging/presentation/tag_editor_dialog_test.dart test/features/tagging/presentation/clip_tag_inspector_test.dart test/features/tagging/presentation/marker_ruler_test.dart test/features/tagging/presentation/marker_editor_dialog_test.dart`.

**Expected RED:** rail/timeline controls are placeholders and a manual edit does not persist one transaction.

```dart
// test/features/tagging/presentation/clip_tag_inspector_test.dart
// FakeTransactionService and taggingTestApp are declared in this test file.
testWidgets('remove tag dispatches one manual transaction', (tester) async {
  final service = FakeTransactionService();
  await tester.pumpWidget(taggingTestApp(service));
  await tester.tap(find.bySemanticsLabel('Remove tag Travel from asset asset-1'));
  await tester.pump();
  expect(service.transactions.single.sourceKind, TransactionSourceKind.manual);
  expect(service.transactions.single.commands.single, isA<UnassignTagCommand>());
});
```

`TaggingProviders.applyManual` constructs one candidate through project executor and applies through `ProjectTransactionService`. Media panel has `Search media`, tag chips, filter and empty states. Marker ruler renders point/range colors. Keyboard: Tab focus, Enter edit, Delete remove, arrows move 100ms, Shift+arrows resize 100ms. Range removal invokes `RemoveClipRangeCommand`; old midpoint-cut behavior is removed.

**GREEN command:** rerun RED. **Expected behavior:** search/filter, semantic controls, one durable transaction per action, undo/redo work. **Exit:** UI uses no duplicate persistence path.

### 3. Integrate AI preview, reopen persistence, and scope exclusion

**Create:** AI tag-marker plan, reopen fixture/test, no-automatic-analysis behavior test. **Modify:** plan operation row, project codec serialization coverage, agent chat presentation. **Test:** those three tests.

**Test first — controller command:** `flutter test test/features/tagging/integration/ai_tag_marker_plan_test.dart test/features/tagging/integration/tag_marker_reopen_test.dart test/features/tagging/regression/no_automatic_analysis_test.dart`.

**Expected RED:** AI delete-tag preview trusts model text or tags/markers fail document reopen.

```dart
// test/features/tagging/integration/ai_tag_marker_plan_test.dart
// validDeletePlan is declared in this test and returns an EditPlan with a task-2 summary.
testWidgets('AI delete preview displays handler-derived assignments before apply', (tester) async {
  await tester.pumpWidget(planCardTestApp(validDeletePlan()));
  expect(find.text('asset-1'), findsOneWidget);
  expect(find.text('clip-1'), findsOneWidget);
  await tester.tap(find.text('Cancel'));
  expect(planCardTestAppTransactionCalls, 0);
});
```

The test file defines `validDeletePlan`, `planCardTestApp`, and `planCardTestAppTransactionCalls` with the exact agent/project owners from prior plans. Codec test round-trips separate `test/fixtures/projects/schema2_tags_markers.cmproj` and asserts state snapshots/records are not recursive. No automatic-analysis test drives registry and suggested-prompt behavior: no visual, audio, transcript, scene, or object capability is available. **GREEN command:** rerun RED. **Expected behavior:** handler-derived preview, cancel no transaction, reopened tags/markers intact, scope remains manual/AI-plan-only. **Exit criteria:** complete tag/marker CRUD/filter/ruler/transaction behavior. **Exclusions:** provider implementation, new media analysis, publication, generated output. **Next plan:** integration and verification.
