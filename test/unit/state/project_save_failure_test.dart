import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Toggleable fake: saves succeed until [failSave] is set, then [failure] is
/// thrown. [saveCalls] proves the save path was exercised.
class _ToggleableProjectRepository extends ProjectRepository {
  _ToggleableProjectRepository({required AppDatabase db}) : super(db);

  bool failSave = false;
  Object failure =
      const PersistenceFailure('The project could not be saved to disk.');
  int saveCalls = 0;

  @override
  Future<void> save(Project project) async {
    saveCalls++;
    if (failSave) throw failure;
  }
}

Project _project() {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['C:/media/sample.mp4'],
    tracks: const [
      Track(
        id: 'track-1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip-1',
            trackId: 'track-1',
            sourcePath: 'C:/media/sample.mp4',
            startMs: 0,
            endMs: 30000,
            label: 'sample.mp4',
          ),
        ],
      ),
    ],
    durationMs: 30000,
  );
}

void main() {
  group('persistProject', () {
    late AppDatabase db;
    late _ToggleableProjectRepository repository;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = _ToggleableProjectRepository(db: db);
      container = ProviderContainer.test(
        overrides: [projectRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
    });

    test(
      'a failed save records message + timestamp; the next success clears it',
      () async {
        final persist = container.read(persistProjectProvider);
        repository.failSave = true;
        final before = DateTime.now();

        final saved = await persist(_project());

        expect(saved, isFalse);
        expect(repository.saveCalls, 1);
        final failure = container.read(projectSaveFailureProvider);
        expect(failure, isNotNull);
        expect(failure!.message, 'The project could not be saved to disk.');
        expect(failure.failedAt.isBefore(before), isFalse);
        expect(failure.failedAt.isAfter(DateTime.now()), isFalse);

        repository.failSave = false;
        final retried = await persist(_project());

        expect(retried, isTrue);
        expect(repository.saveCalls, 2);
        expect(container.read(projectSaveFailureProvider), isNull);
      },
    );

    test('a non-PersistenceFailure error records the generic fallback', () async {
      final persist = container.read(persistProjectProvider);
      repository.failSave = true;
      repository.failure = StateError('disk on fire');

      final saved = await persist(_project());

      expect(saved, isFalse);
      final failure = container.read(projectSaveFailureProvider);
      expect(failure, isNotNull);
      expect(failure!.message, 'The project could not be saved to disk.');
      expect(failure.message, isNot(contains('disk on fire')));
    });
  });

  group('timeline manual edit save failure', () {
    testWidgets('edit stays in memory while the failure is recorded and shown', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = _ToggleableProjectRepository(db: db)
        ..failSave = true;
      final container = ProviderContainer.test(
        overrides: [projectRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(_project());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: TimelineView())),
        ),
      );
      await tester.pump();

      // Select the clip block, then delete it.
      await tester.tap(find.text('sample.mp4'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump();

      // In-memory first: the edit is visible even though the save failed.
      final project = container.read(projectProvider).value!;
      final clips = [for (final track in project.tracks) ...track.clips];
      expect(clips.where((clip) => clip.id == 'clip-1'), isEmpty);

      // The failure is recorded and surfaced instead of swallowed.
      final failure = container.read(projectSaveFailureProvider);
      expect(failure, isNotNull);
      expect(failure!.message, 'The project could not be saved to disk.');
      expect(
        find.text('Change applied, but it could not be saved to disk.'),
        findsOneWidget,
      );
      expect(find.text('Clip deleted.'), findsNothing);
      expect(repository.saveCalls, 1);
    });
  });
}
