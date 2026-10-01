import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/manual_edit_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/structural_edit_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';

class _RecordingRepository extends ProjectRepository {
  int saves = 0;

  _RecordingRepository(super.db);

  @override
  Future<void> save(Project project) async {
    saves++;
  }
}

class _FakeFfmpeg extends FfmpegService {
  FfmpegJob? lastJob;

  _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path);

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    lastJob = job;
    final out = File(job.outputPath);
    await out.parent.create(recursive: true);
    await out.writeAsString('fake');
    return FfmpegResult(success: true, outputPath: job.outputPath, exitCode: 0);
  }
}

Project _project(String inputA, String inputB, String outDir) {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: [inputA],
    tracks: [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip_1',
            trackId: 't1',
            sourcePath: inputA,
            startMs: 0,
            endMs: 60000,
            positionMs: 0,
          ),
          Clip(
            id: 'clip_2',
            trackId: 't1',
            sourcePath: inputB,
            startMs: 0,
            endMs: 30000,
            positionMs: 60000,
          ),
        ],
      ),
    ],
    durationMs: 90000,
    outputDir: outDir,
  );
}

EditOperation _op(
  String id,
  EditOperationType type,
  Map<String, dynamic> params,
) =>
    EditOperation(
      id: id,
      type: type,
      targetClipIds: const ['clip_1'],
      params: params,
      createdAt: DateTime(2026, 1, 2),
    );

List<String> _clipIds(ProviderContainer container, String trackId) {
  return container
      .read(projectProvider)
      .value!
      .tracks
      .firstWhere((t) => t.id == trackId)
      .clips
      .map((c) => c.id)
      .toList();
}

/// First `between(t,a,b)` pair in the joined args, or null when absent.
/// Accepts any decimal formatting (`5.0`/`5.00`/`5.000`) so the assertion
/// is robust to the backend's ms-rounded shortest round-trip format.
List<double>? _betweenValues(String joined) {
  final m = RegExp(r'between\(t,([\d.]+),([\d.]+)\)').firstMatch(joined);
  if (m == null) return null;
  final a = double.tryParse(m.group(1)!);
  final b = double.tryParse(m.group(2)!);
  if (a == null || b == null) return null;
  return [a, b];
}

void main() {
  group('Structural edit flow (real structural wiring)', () {
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
      return container;
    }

    test('deleteClip removes, journals, and undoes', () async {
      final container = makeContainer();
      container.read(projectProvider.notifier).setProject(_project('/v/a.mp4', '/v/b.mp4', '/out'));
      final applier = container.read(structuralEditApplierProvider);

      final applied = await applier.apply(
        _op('op_del', EditOperationType.deleteClip, {'clip_id': 'clip_2'}),
      );

      expect(applied, isTrue);
      expect(_clipIds(container, 't1'), equals(['clip_1']));
      expect(container.read(undoRedoProvider).canUndo, isTrue);
      expect(
        container
            .read(projectProvider)
            .value!
            .editHistory
            .map((e) => e.id),
        contains('op_del'),
      );
      final journal = await db.getEditHistory('p1');
      expect(journal.map((e) => e.id), contains('op_del'));

      await container.read(undoRedoProvider.notifier).undo();
      expect(_clipIds(container, 't1'), equals(['clip_1', 'clip_2']));
    });

    test('unknown clip is a graceful no-op (no undo entry)', () async {
      final container = makeContainer();
      container.read(projectProvider.notifier).setProject(_project('/v/a.mp4', '/v/b.mp4', '/out'));

      final applied = await container
          .read(structuralEditApplierProvider)
          .apply(
            _op('op_nope', EditOperationType.deleteClip, {'clip_id': 'ghost'}),
          );

      expect(applied, isFalse);
      expect(_clipIds(container, 't1'), equals(['clip_1', 'clip_2']));
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('copyClip duplicates after the original', () async {
      final container = makeContainer();
      container.read(projectProvider.notifier).setProject(_project('/v/a.mp4', '/v/b.mp4', '/out'));

      final applied = await container
          .read(structuralEditApplierProvider)
          .apply(_op('op_copy', EditOperationType.copyClip, {'clip_id': 'clip_1'}));

      expect(applied, isTrue);
      final clips = container
          .read(projectProvider)
          .value!
          .tracks
          .firstWhere((t) => t.id == 't1')
          .clips;
      expect(clips.map((c) => c.id).toList(),
          equals(['clip_1', 'clip_1_copy_1', 'clip_2']));
      final copy = clips[1];
      expect(copy.sourcePath, equals('/v/a.mp4'));
      expect(copy.positionMs, equals(60000));
    });

    test('moveClip reorders and repins positions', () async {
      final container = makeContainer();
      container.read(projectProvider.notifier).setProject(_project('/v/a.mp4', '/v/b.mp4', '/out'));

      final applied = await container
          .read(structuralEditApplierProvider)
          .apply(_op('op_move', EditOperationType.moveClip,
              {'clip_id': 'clip_1', 'after_clip_id': 'clip_2'}));

      expect(applied, isTrue);
      final clips = container
          .read(projectProvider)
          .value!
          .tracks
          .firstWhere((t) => t.id == 't1')
          .clips;
      expect(clips.map((c) => c.id).toList(), equals(['clip_2', 'clip_1']));
      expect(clips.map((c) => c.positionMs).toList(), equals([0, 30000]));
    });
  });

  group('Manual cut flow (real mapper/engine/applier)', () {
    late Directory tmp;
    late AppDatabase db;
    late _RecordingRepository repository;
    late _FakeFfmpeg ffmpeg;
    late String inputA;
    late String outDir;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_manual_cut_');
      db = AppDatabase(NativeDatabase.memory());
      repository = _RecordingRepository(db);
      ffmpeg = _FakeFfmpeg();
      inputA = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
      outDir = (Directory('${tmp.path}/out')..createSync()).path;
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
      await db.close();
    });

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          projectRepositoryProvider.overrideWithValue(repository),
          ffmpegServiceProvider.overrideWithValue(ffmpeg),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(
            _project(inputA, '${tmp.path}/b.mp4', outDir),
          );
      return container;
    }

    test('unknown clip and bad ranges fail without side effects', () async {
      final container = makeContainer();
      final cut = container.read(manualEditControllerProvider);

      final unknown =
          await cut.submitCut(clipId: 'ghost', startMs: 0, endMs: 1000);
      expect(unknown.success, isFalse);
      expect(unknown.message, contains('Unknown clip'));

      final inverted =
          await cut.submitCut(clipId: 'clip_1', startMs: 9000, endMs: 1000);
      expect(inverted.success, isFalse);

      final outside =
          await cut.submitCut(clipId: 'clip_1', startMs: 50000, endMs: 80000);
      expect(outside.success, isFalse);

      expect(ffmpeg.lastJob, isNull);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('no project fails gracefully', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          projectRepositoryProvider.overrideWithValue(repository),
          ffmpegServiceProvider.overrideWithValue(ffmpeg),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(manualEditControllerProvider)
          .submitCut(clipId: 'clip_1', startMs: 0, endMs: 1000);
      expect(result.success, isFalse);
      expect(result.message, contains('No project'));
    });

    test('cut executes, repoints, and is undoable + journaled', () async {
      final container = makeContainer();

      final result = await container
          .read(manualEditControllerProvider)
          .submitCut(clipId: 'clip_1', startMs: 5000, endMs: 15000);

      expect(result.success, isTrue);
      expect(result.outputPath, isNotNull);
      expect(result.outputPath!.startsWith(outDir), isTrue);
      // The job ran against the real clip file.
      expect(ffmpeg.lastJob!.inputPath, equals(inputA));
      final joined = ffmpeg.lastJob!.args.join(' ');
      final between = _betweenValues(joined);
      expect(between, isNotNull, reason: 'expected between(t,a,b) in: $joined');
      expect(between![0], closeTo(5.0, 0.001));
      expect(between[1], closeTo(15.0, 0.001));

      String source() => container
          .read(projectProvider)
          .value!
          .tracks
          .expand((t) => t.clips)
          .singleWhere((c) => c.id == 'clip_1')
          .sourcePath;
      expect(source(), equals(result.outputPath));
      expect(container.read(undoRedoProvider).canUndo, isTrue);
      final journal = await db.getEditHistory('p1');
      expect(journal, hasLength(1));
      expect(journal.single.type, equals(EditOperationType.cut));
      expect(repository.saves, greaterThanOrEqualTo(1));

      await container.read(undoRedoProvider.notifier).undo();
      expect(source(), equals(inputA));
    });
  });
}

