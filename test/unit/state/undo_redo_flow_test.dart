import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';

class _RecordingRepository extends ProjectRepository {
  int saves = 0;
  Project? lastSaved;

  _RecordingRepository(super.db);

  @override
  Future<void> save(Project project) async {
    saves++;
    lastSaved = project;
  }
}

Project _project() {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['/v/a.mp4'],
    tracks: const [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip_1',
            trackId: 't1',
            sourcePath: '/v/a.mp4',
            startMs: 0,
            endMs: 60000,
          ),
        ],
      ),
    ],
    durationMs: 60000,
    outputDir: '/out',
  );
}

EditOperation _trimOp() => EditOperation(
      id: 'op_1',
      type: EditOperationType.trim,
      targetClipIds: const ['clip_1'],
      params: const {'start': '00:00:05.000', 'end': '00:00:15.000'},
      createdAt: DateTime(2026, 1, 2),
    );

String _sourceOf(ProviderContainer container, String clipId) {
  return container
      .read(projectProvider)
      .value!
      .tracks
      .expand((t) => t.clips)
      .singleWhere((c) => c.id == clipId)
      .sourcePath;
}

void main() {
  group('UndoRedoNotifier flow (real applier wiring)', () {
    late AppDatabase db;
    late _RecordingRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = _RecordingRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          projectRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(_project());
      return container;
    }

    test('apply -> undo restores + persists, redo restores forward',
        () async {
      final container = makeContainer();
      final applier = container.read(agentEditApplierProvider);
      final undoRedo = container.read(undoRedoProvider.notifier);

      await applier.apply(_trimOp(), '/out/b.mp4');
      expect(_sourceOf(container, 'clip_1'), equals('/out/b.mp4'));
      expect(
        container.read(undoRedoProvider).canUndo,
        isTrue,
        reason: 'applier must push the pre-edit snapshot',
      );
      expect(repository.saves, greaterThanOrEqualTo(1));

      final undoneOp = await undoRedo.undo();
      expect(undoneOp?.id, equals('op_1'));
      expect(_sourceOf(container, 'clip_1'), equals('/v/a.mp4'));
      expect(repository.lastSaved, isNotNull);
      expect(
        _sourceOfProject(repository.lastSaved!, 'clip_1'),
        equals('/v/a.mp4'),
        reason: 'restoration must be persisted to the project file',
      );
      expect(container.read(undoRedoProvider).canRedo, isTrue);

      final redoneOp = await undoRedo.redo();
      expect(redoneOp?.id, equals('op_1'));
      expect(_sourceOf(container, 'clip_1'), equals('/out/b.mp4'));
      expect(container.read(undoRedoProvider).canUndo, isTrue);
    });

    test('manual structural push -> undo restores', () async {
      final container = makeContainer();
      final undoRedo = container.read(undoRedoProvider.notifier);
      final before =
          container.read(projectProvider).value!;
      final renamed = before.copyWith(name: 'Renamed');

      undoRedo.pushStructural(before);
      container.read(projectProvider.notifier).setProject(renamed);
      expect(
        container.read(projectProvider).value!.name,
        equals('Renamed'),
      );

      await undoRedo.undo();
      expect(
        container.read(projectProvider).value!.name,
        equals('Test'),
      );
      expect(repository.saves, equals(1));
    });

    test('no project -> undo/redo are no-ops', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          projectRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final undoRedo = container.read(undoRedoProvider.notifier);
      expect(await undoRedo.undo(), isNull);
      expect(await undoRedo.redo(), isNull);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
      expect(repository.saves, equals(0));
    });
  });
}

String _sourceOfProject(Project project, String clipId) {
  return project.tracks
      .expand((t) => t.clips)
      .singleWhere((c) => c.id == clipId)
      .sourcePath;
}

