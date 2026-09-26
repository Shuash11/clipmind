# ClipMind Project Foundation Plan

**Goal:** Establish canonical project state, deterministic local IDs, migration, crash-recoverable file persistence, and durable plan-level transactions.  
**Architecture:** `lib/core` owns only shared result/cancellation primitives. Project domain is pure Dart and owns immutable entities, commands, IDs, snapshots, repository contract, and transaction service. Project data owns codec, files, migration, UUID adapter, and Drift cache. Presentation consumes injected contracts.  
**Tech Stack:** Dart 3.12.1, existing Drift, Freezed/json_serializable transitional DTOs, `uuid`, Flutter/Riverpod.  
**Prerequisites:** Master plan; no provider or agent implementation dependency.  
**Links:** [spec](../specs/2026-07-27-clipmind-ai-editor-foundation-design.md) · [master](2026-07-27-clipmind-ai-editor-foundation-master-plan.md).

## File-responsibility map

| Path | Responsibility |
|---|---|
| `lib/core/results/result.dart` | `Result`, direct variants, Dart-legal `AppFailure` and project failures. |
| `lib/core/async/cancellation_token.dart` | pure cancellation contract. |
| `lib/features/projects/domain/ids/id_generator.dart` | `abstract interface class IdGenerator { String next(); }`. |
| `lib/features/projects/data/ids/uuid_id_generator.dart` | UUID implementation of that contract. |
| `lib/features/projects/domain/entities/project_state_snapshot.dart`, `project_document.dart`, `persisted_transaction_record.dart` | non-recursive state/document/history model. |
| `lib/features/projects/domain/entities/media_asset.dart`, `project_clip.dart`, `project_track.dart`, `tag_definition.dart`, `timeline_marker.dart`, `clip_transform.dart`, `project_overlay.dart` | immutable editable entities. |
| `lib/features/projects/domain/commands/project_command.dart` | `sealed class ProjectCommand`, summaries, source kind. |
| `lib/features/projects/domain/commands/clip_commands.dart`, `overlay_commands.dart`, `tag_commands.dart`, `marker_commands.dart` | cohesive canonical command classes. |
| `lib/features/projects/domain/commands/project_command_factory.dart` | sole allocation of IDs before pure handlers run. |
| `lib/features/projects/domain/handlers/clip_command_handler.dart`, `overlay_command_handler.dart`, `tag_command_handler.dart`, `marker_command_handler.dart`, `commands/project_command_executor.dart` | pure grouped execution, ordered all-or-nothing candidate construction. |
| `lib/features/projects/data/project_file_io.dart`, `atomic_project_file_store.dart`, `project_document_codec.dart`, `project_document_migrator.dart`, `legacy_project_adapter.dart` | injected file protocol and v0/v1/v2 conversion. |
| `lib/features/projects/domain/repositories/project_repository.dart`, `domain/transactions/project_file_write_outcome.dart`, `project_save_outcome.dart`, `project_transaction_service.dart`, `data/project_repository_impl.dart` | file-first durable outcomes, typed nonblocking warnings, and visible-state publication. |
| `lib/data/local/database/app_database.dart` | rebuildable Drift project hub index/cache migration. |

Generated `*.g.dart` and `*.freezed.dart` are never handwritten. Legacy horizontal DTOs remain decode-only one-way facades until their listed consumers migrate.

## Required contracts

```dart
// lib/core/results/result.dart
sealed class Result<T> { const Result(); }
final class Success<T> extends Result<T> { const Success(this.value); final T value; }
final class Failure<T> extends Result<T> { const Failure(this.error); final AppFailure error; }
abstract base class AppFailure {
  const AppFailure(this.code, this.message);
  final String code;
  final String message;
}
final class ProjectPersistenceFailure extends AppFailure {
  const ProjectPersistenceFailure(String message) : super('project_persistence', message);
}
abstract base class ProjectSaveWarning {
  const ProjectSaveWarning(this.code, this.message);
  final String code;
  final String message;
}
final class ProjectFileWarning extends ProjectSaveWarning {
  const ProjectFileWarning(String code, String message) : super(code, message);
}
final class ProjectIndexWarning extends ProjectSaveWarning {
  const ProjectIndexWarning(String code, String message) : super(code, message);
}
final class ProjectFileWriteOutcome {
  const ProjectFileWriteOutcome({this.warning});
  final ProjectFileWarning? warning;
}
final class ProjectSaveOutcome {
  const ProjectSaveOutcome({required this.document, this.warnings = const []});
  final ProjectDocument document;
  final List<ProjectSaveWarning> warnings;
}
```

`AtomicProjectFileStore.writeJson` returns `Future<Result<ProjectFileWriteOutcome>>`. A successful `.cmproj` promotion is semantic success. If rollback cleanup fails after promotion, it returns `Success(ProjectFileWriteOutcome(warning: ProjectFileWarning('rollback_cleanup_failed', 'Rollback cleanup failed')))`; the new target remains authoritative and the rollback remains for startup cleanup. Blocking failures before promotion return `Failure`; failed promotion with successful restoration returns `Failure` with the old target; failed promotion plus failed restoration returns `Failure` while retaining rollback evidence.

`ProjectRepository.save(ProjectDocument document)` returns `Future<Result<ProjectSaveOutcome>>`. It starts `warnings` with the optional file warning, then appends `ProjectIndexWarning('project_index_upsert_failed', 'Drift upsert failed')` if the rebuildable Drift upsert fails. It returns `Success(ProjectSaveOutcome(document: document, warnings: warnings))` after every durable file save; it never returns `Failure` after disk has been updated. File failure returns `Failure<ProjectSaveOutcome>`, performs no index update, and leaves presentation state untouched. Bootstrap/recent load reads the authoritative file and attempts an index upsert/rebuild; a rebuild warning is surfaced without hiding the durable document.

`ProjectDocument` owns metadata, `currentState`, revision, records, and cursor. `ProjectStateSnapshot` has no metadata/history/document fields. `PersistedTransactionRecord` holds only `beforeState`, `afterState`, summaries, `appliedAt`, and source. `EditTransaction` contains plan ID, expected revision, before/candidate snapshots, commands, summaries, and source.

## Tasks (4)

### 1. Define primitives, IDs, entities, and modular commands

**Create:** all core/domain paths in the map through `project_command_executor.dart`; `test/features/projects/domain/result_contract_test.dart`, `id_generator_test.dart`, `project_command_factory_test.dart`, `project_command_executor_test.dart`. **Modify:** legacy project/clip/track/edit-operation DTOs only as decode adapters. **Test:** the four named tests.

**Test first — controller command:** `flutter test test/features/projects/domain/result_contract_test.dart test/features/projects/domain/id_generator_test.dart test/features/projects/domain/project_command_factory_test.dart test/features/projects/domain/project_command_executor_test.dart`.

**Expected RED:** no legal externally extensible failure base, no injected ID factory, and no split command executor exists.

```dart
// test/features/projects/domain/id_generator_test.dart
// Owned by this task: IdGenerator at lib/features/projects/domain/ids/id_generator.dart
// and ProjectCommandFactory at lib/features/projects/domain/commands/project_command_factory.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/features/projects/domain/ids/id_generator.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';

final class SequenceIds implements IdGenerator {
  SequenceIds(this.values);
  final List<String> values;
  int _index = 0;
  @override String next() => values[_index++];
}

void main() {
  test('factory, not caller, supplies IDs for new entities and split clips', () {
    final factory = ProjectCommandFactory(SequenceIds(['tag-1', 'right-1']));
    expect(factory.createTag(name: 'Travel', color: '#112233').tagId, 'tag-1');
    expect(factory.removeClipRange(clipId: 'clip-1', startMs: 10, endMs: 20).rightClipId, 'right-1');
  });
}
```

`ProjectCommandFactory` exposes constructors for all canonical commands. Provider and manual requests pass no new tag, marker, overlay, or split-clip ID. `CreateTagCommand`, `CreateMarkerCommand`, `AddTextOverlayCommand`, `AddImageOverlayCommand`, and `RemoveClipRangeCommand` carry factory-allocated IDs. `ProjectCommand` is sealed in its own file; command files are limited to clip (8), overlay (2), tag (5), and marker (3) commands. Handlers are grouped by the same categories.

`remove_clip_range` uses clip-local offsets: `0 <= startMs < endMs <= clip.durationMs`. A prefix/suffix boundary removal trims the existing clip. An interior removal creates left and right clips, gives the right clip the command’s allocated ID, preserves asset ID, tag IDs, transform, speed, mute, volume, brightness, and overlay-independent properties, and closes the removed timeline gap by shifting only later clips on the same track left by `endMs - startMs`. Handler tests cover prefix, suffix, interior, and invalid full-range removal.

**GREEN command:** rerun the RED command. **Expected behavior:** legal external failure subclasses compile; IDs are deterministic; an invalid later command returns `Failure` with no candidate; all 18 command classes occur in the four command files. **Exit:** no generated source and no direct mutable collection update.

### 2. Implement migration and crash-recoverable file protocol

**Create:** `project_file_io.dart`, `atomic_project_file_store.dart`, codec/migrator/legacy adapter, test fake, v0 and v1 fixtures, and `atomic_project_file_store_test.dart`/`project_document_migrator_test.dart`. **Modify:** old file-store facade. **Test:** those two tests.

**Test first — controller command:** `flutter test test/features/projects/data/atomic_project_file_store_test.dart test/features/projects/data/project_document_migrator_test.dart`.

**Expected RED:** a failed promotion can discard the readable target and no v0/v1 conversion preserves source mappings.

```dart
// test/features/projects/data/atomic_project_file_store_test.dart
// ProjectFileIo and AtomicProjectFileStore are created by this task at the mapped paths.
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/data/atomic_project_file_store.dart';
import 'package:clipmind/features/projects/data/project_file_io.dart';

enum FailurePoint { promote, restore }
final class MemoryFileIo implements ProjectFileIo {
  final files = <String, String>{'p.cmproj': 'old'};
  final failures = <FailurePoint>{};
  final operations = <String>[];
  @override Future<bool> exists(String p) async => files.containsKey(p);
  @override Future<String> read(String p) async => files[p]!;
  @override Future<void> writeAndFlush(String p, String v) async { files[p] = v; }
  @override Future<void> copy(String from, String to) async { files[to] = files[from]!; }
  @override Future<void> rename(String from, String to) async {
    operations.add('$from->$to');
    if (from == 'p.cmproj.tmp' && failures.contains(FailurePoint.promote)) throw StateError('promote');
    if (from == 'p.cmproj.rollback' && to == 'p.cmproj' && failures.contains(FailurePoint.restore)) throw StateError('restore');
    files[to] = files.remove(from)!;
  }
  @override Future<void> delete(String p) async { files.remove(p); }
}
void main() => test('promotion failure restores rollback bytes', () async {
   final io = MemoryFileIo()..failures.add(FailurePoint.promote);
   final result = await AtomicProjectFileStore(io).writeJson('p.cmproj', 'new');
   expect(result, isA<Failure<ProjectFileWriteOutcome>>());
  expect(io.files['p.cmproj'], 'old');
  expect(io.files.containsKey('p.cmproj.rollback'), isFalse);
});
```

Write protocol: write and flush same-directory `$path.tmp`; for migration copy existing target to retained `$path.v<fromSchema>.bak`; rename target to `$path.rollback`; rename temp to target; delete rollback after promotion. On promotion failure, attempt rollback restoration and return a typed failure describing whether restore also failed. After promotion, rollback cleanup failure is a `ProjectFileWarning`, never a failure. `recover(path)` validates JSON through the injected project-document decoder before deleting stale rollback; it restores rollback only when target is absent and preserves rollback evidence when target JSON is corrupt. A new file promotes temp directly. This is crash-recoverable Dart I/O, not an OS-level indivisible rename claim.

Codec/migrator reads v0, v1, and v2. It deterministically derives asset IDs during migration from project ID and normalized source path, retains v0 `sourcePath` and v1 `sourceMediaPaths`, maps clips to asset IDs, initializes tags/markers/overlays, and leaves v2 unchanged. Tests inject independent flush, backup-copy, target-to-rollback, promotion, restoration, and cleanup failures, including combined promotion-plus-restoration failure and operation order. Recovery tests use valid codec JSON for stale rollback and prove corrupt target JSON preserves rollback evidence. Tests prove retained backup and Windows separators.

**GREEN command:** rerun the RED command. **Expected behavior:** each injected transition returns typed evidence; original bytes survive recoverable failure; v0/v1 media survives; serialized history never nests a document/history. **Exit:** file store is injectable and migration is idempotent.

### 3. Make `.cmproj` authoritative and transactions file-first

**Create:** repository contract/implementation, `edit_transaction.dart`, `persisted_transaction_record.dart`, `project_transaction_service.dart`, repository fakes and tests. **Modify:** old repository facade, project/undo providers and use case. **Test:** `project_repository_impl_test.dart`, `project_transaction_service_test.dart`, `project_index_repair_test.dart`.

**Test first — controller command:** `flutter test test/features/projects/data/project_repository_impl_test.dart test/features/projects/domain/project_transaction_service_test.dart test/features/projects/data/project_index_repair_test.dart`.

**Expected RED:** durable file success followed by cache failure produces an error/stale UI, and undo/redo can recursively serialize history.

```dart
// test/features/projects/data/project_repository_impl_test.dart
// This task owns ProjectRepository, ProjectSaveOutcome, ProjectIndexWarning,
// ProjectDocumentStore, and ProjectIndex at the exact paths in the map.
test('file success with index failure remains successful and reports warning', () async {
  final files = RecordingProjectFiles();
  final index = FailingProjectIndex();
  final repository = ProjectRepositoryImpl(files: files, index: index);
  final result = await repository.save(minimalDocument());
  final outcome = (result as Success<ProjectSaveOutcome>).value;
  expect(files.writes, 1);
   expect(outcome.warnings.single.code, 'project_index_upsert_failed');
});
final class RecordingProjectFiles implements ProjectDocumentStore {
  int writes = 0;
  @override Future<Result<ProjectFileWriteOutcome>> write(ProjectDocument document) async {
    writes++;
    return const Success(ProjectFileWriteOutcome());
  }
}
final class FailingProjectIndex implements ProjectIndex {
  @override Future<void> upsert(ProjectDocument document) async => throw StateError('index');
}
ProjectDocument minimalDocument() => ProjectDocument.testDocument(id: 'project-1');
```

`ProjectDocument.testDocument` is an exact test fixture constructor declared in `test/features/projects/data/project_test_document.dart`, created by this task; it builds the complete immutable document with an empty snapshot, revision zero, and no history. `ProjectDocumentStore` and `ProjectIndex` are narrow exact contracts declared in `lib/features/projects/domain/repositories/project_repository.dart`. `ProjectTransactionService.apply` verifies expected revision, saves one candidate document with a nonrecursive record, publishes `outcome.document` after every `Success`, and exposes the complete typed `outcome.warnings` list in immutable presentation state. It does not return failure after a disk update. Undo stores the record’s before snapshot, increments revision, moves cursor; redo stores after snapshot, increments revision, and moves cursor. Failure prevents both publication and index update.

Recent-project bootstrap reads `.cmproj`, then upserts the index; missing/corrupt index entries trigger a rebuild from discovered authoritative project files. Index repair is nonblocking and warning-visible. Tests prove: file failure blocks visible mutation/index write; file success plus file-cleanup and/or index warning updates visible document and warnings; warning display bridge receives the complete list; restart repair rebuilds index; no state where UI shows old data while disk has the saved candidate.

**GREEN command:** rerun the RED command. **Expected behavior:** four save/recovery cases pass; apply/undo/redo each persist a snapshot and revision; no recursive history. **Exit:** cache failure is visible but cannot create split-brain state.

### 4. Bridge consumers and migrate the Drift hub index

**Create:** app database migration, import/export asset-resolution, index-rebuild, and timeline transaction tests. **Modify:** `app_database.dart`, import/export use cases, legacy DTO facades, project/undo providers, editor/timeline consumers. **Test:** `app_database_migration_test.dart`, `import_export_asset_resolution_test.dart`, `timeline_transaction_bridge_test.dart`.

**Test first — controller command:** `flutter test test/features/projects/data/app_database_migration_test.dart test/features/projects/data/import_export_asset_resolution_test.dart test/features/projects/presentation/timeline_transaction_bridge_test.dart`.

**Expected RED:** consumers use uncontrolled `sourcePath`, and Drift claims authority over a document it cannot reconstruct.

Drift schema version adds only rebuildable index metadata such as project path, document schema version, and document revision. It is never the canonical project document. Its migration test creates a v1 schema and row with a test-owned `NativeDatabase`/`QueryExecutor`, then instantiates the existing public `AppDatabase(QueryExecutor)` constructor and uses public Drift `customSelect` queries to prove row preservation and nullable columns; it adds no production testing API. Import creates `MediaAsset` and asset-ID clips. Rendering/export resolves an asset ID to a path locally after approved command processing; missing assets are `ProjectValidationFailure`. Timeline manual edits use `ProjectCommandFactory` and `ProjectTransactionService`, not an old operation record API.

**GREEN command:** rerun the RED command. **Expected behavior:** old index rows migrate, asset resolution is local, a manual edit saves one transaction, and a deleted/rebuilt index never changes the `.cmproj`. **Exit criteria:** all project data is canonical, nonrecursive, recoverable, durable, and ready for provider platform. **Exclusions:** provider/agent/tagging implementation, automatic analysis, publication, generated output, dependency changes. **Next plan:** provider platform.
