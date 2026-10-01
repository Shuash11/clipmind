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

/// Cycle 6 Phase 1 (middle-end): cut-path range/timebase correctness.
///
/// - D1: `applyEdit` normalizes the repointed clip's `startMs`/`endMs`
///   from the executor's additive `new_start_ms`/`new_end_ms` params.
/// - D2: `submitCut` maps span-relative local times to FILE times
///   (`clip.startMs + local`) for the FFmpeg `cut`.
/// - D3: after a range update the affected track repins cumulatively so
///   the timeline and the export agree.
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

/// Same fixture but with a handle-trimmed first clip (`startMs > 0`).
Project _trimmedProject(String inputA, String inputB, String outDir) {
  final base = _project(inputA, inputB, outDir);
  final clips = [
    base.tracks.first.clips.first.copyWith(startMs: 10000, endMs: 60000),
    base.tracks.first.clips[1].copyWith(positionMs: 50000),
  ];
  return base.copyWith(
    tracks: [base.tracks.first.copyWith(clips: clips)],
  );
}

EditOperation _cutOp(
  String id,
  Map<String, dynamic> params, {
  EditOperationType type = EditOperationType.cut,
}) =>
    EditOperation(
      id: id,
      type: type,
      targetClipIds: const ['clip_1'],
      params: params,
      createdAt: DateTime(2026, 1, 2),
    );

List<Clip> _clips(ProviderContainer container) => container
    .read(projectProvider)
    .valueOrNull!
    .tracks
    .firstWhere((t) => t.id == 't1')
    .clips;

Clip _clip(ProviderContainer container, String id) =>
    _clips(container).singleWhere((c) => c.id == id);

void main() {
  group('applyEdit range normalization + repin (D1+D3, AI path)', () {
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
      container
          .read(projectProvider.notifier)
          .setProject(_project('/v/a.mp4', '/v/b.mp4', '/out'));
      return container;
    }

    test('cut normalizes the range, fixes the display, repins followers',
        () async {
      final container = makeContainer();

      // Mirrors the backend executor: 60s clip minus a 10s segment.
      container.read(projectProvider.notifier).applyEdit(
            _cutOp('op_cut', {
              'remove_start': '00:00:05.000',
              'remove_end': '00:00:15.000',
              'new_start_ms': 0,
              'new_end_ms': 50000,
            }),
            '/out/cut.mp4',
          );

      final cut = _clip(container, 'clip_1');
      expect(cut.sourcePath, equals('/out/cut.mp4'));
      expect(cut.startMs, equals(0));
      expect(cut.endMs, equals(50000));
      // Display duration matches the shorter output file.
      expect(cut.endMs - cut.startMs, equals(50000));
      // Repin: the follower follows the shortened 50s clip (no gap).
      expect(cut.positionMs, equals(0));
      expect(_clip(container, 'clip_2').positionMs, equals(50000));
    });

    test('a subsequent AI cut removes the intended segment', () async {
      final container = makeContainer();
      final notifier = container.read(projectProvider.notifier);

      notifier.applyEdit(
        _cutOp('op_cut1', {
          'remove_start': '00:00:05.000',
          'remove_end': '00:00:15.000',
          'new_start_ms': 0,
          'new_end_ms': 50000,
        }),
        '/out/cut1.mp4',
      );
      // Second cut against the NORMALIZED range: 50s clip minus 10s.
      notifier.applyEdit(
        _cutOp('op_cut2', {
          'remove_start': '00:00:00.000',
          'remove_end': '00:00:10.000',
          'new_start_ms': 0,
          'new_end_ms': 40000,
        }),
        '/out/cut2.mp4',
      );

      final cut = _clip(container, 'clip_1');
      expect(cut.sourcePath, equals('/out/cut2.mp4'));
      expect(cut.startMs, equals(0));
      expect(cut.endMs, equals(40000));
      expect(_clip(container, 'clip_2').positionMs, equals(40000));
    });

    test('absent keys leave the range and positions untouched', () async {
      final container = makeContainer();

      container.read(projectProvider.notifier).applyEdit(
            _cutOp('op_cut', {
              'remove_start': '00:00:05.000',
              'remove_end': '00:00:15.000',
            }),
            '/out/cut.mp4',
          );

      final cut = _clip(container, 'clip_1');
      expect(cut.sourcePath, equals('/out/cut.mp4'));
      expect(cut.startMs, equals(0));
      expect(cut.endMs, equals(60000));
      expect(cut.positionMs, equals(0));
      expect(_clip(container, 'clip_2').positionMs, equals(60000));
    });

    test('other ops repoint without a range update or repin', () async {
      final container = makeContainer();

      container.read(projectProvider.notifier).applyEdit(
            _cutOp('op_mute', const {}, type: EditOperationType.mute),
            '/out/mute.mp4',
          );

      final muted = _clip(container, 'clip_1');
      expect(muted.sourcePath, equals('/out/mute.mp4'));
      expect(muted.startMs, equals(0));
      expect(muted.endMs, equals(60000));
      expect(_clips(container).map((c) => c.positionMs).toList(),
          equals([0, 60000]));
    });

    test('corrupt range keys fail closed (no range update)', () async {
      final container = makeContainer();

      container.read(projectProvider.notifier).applyEdit(
            _cutOp('op_cut', {
              'new_start_ms': 0,
              'new_end_ms': -5,
            }),
            '/out/cut.mp4',
          );

      final cut = _clip(container, 'clip_1');
      expect(cut.startMs, equals(0));
      expect(cut.endMs, equals(60000));
      expect(_clip(container, 'clip_2').positionMs, equals(60000));
    });
  });

  group('manual cut timebase + consistency chain (D2, manual path)', () {
    late Directory tmp;
    late AppDatabase db;
    late _RecordingRepository repository;
    late _FakeFfmpeg ffmpeg;
    late String inputA;
    late String outDir;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_cut_range_');
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

    ProviderContainer makeContainer({bool trimmed = false}) {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          projectRepositoryProvider.overrideWithValue(repository),
          ffmpegServiceProvider.overrideWithValue(ffmpeg),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(
            trimmed
                ? _trimmedProject(inputA, '${tmp.path}/b.mp4', outDir)
                : _project(inputA, '${tmp.path}/b.mp4', outDir),
          );
      return container;
    }

    test('handle-trimmed clip cuts at the file time', () async {
      final container = makeContainer(trimmed: true);

      // Timeline [5000, 15000) into the trimmed clip (in-point 10000):
      // the file time is startMs + local = [15000, 25000).
      final result = await container
          .read(manualEditControllerProvider)
          .submitCut(clipId: 'clip_1', startMs: 5000, endMs: 15000);

      expect(result.success, isTrue);
      expect(
        ffmpeg.lastJob!.args.join(' '),
        contains('between(t,15.000,25.000)'),
      );
      // 50s of source minus the 10s segment → [0, 40000].
      final cut = _clip(container, 'clip_1');
      expect(cut.sourcePath, equals(result.outputPath));
      expect(cut.startMs, equals(0));
      expect(cut.endMs, equals(40000));
      expect(_clip(container, 'clip_2').positionMs, equals(40000));
    });

    test('cut then subsequent manual cut hits the intended segment',
        () async {
      final container = makeContainer();
      final controller = container.read(manualEditControllerProvider);

      final first = await controller.submitCut(
        clipId: 'clip_1',
        startMs: 5000,
        endMs: 15000,
      );
      expect(first.success, isTrue);
      expect(_clip(container, 'clip_1').endMs, equals(50000));

      // The clip now starts at 0 with a 50s span: timeline [0, 10000)
      // maps to file [0, 10000) exactly.
      final second = await controller.submitCut(
        clipId: 'clip_1',
        startMs: 0,
        endMs: 10000,
      );
      expect(second.success, isTrue);
      expect(
        ffmpeg.lastJob!.args.join(' '),
        contains('between(t,0.000,10.000)'),
      );
      final cut = _clip(container, 'clip_1');
      expect(cut.startMs, equals(0));
      expect(cut.endMs, equals(40000));
      expect(cut.sourcePath, equals(second.outputPath));
      expect(_clip(container, 'clip_2').positionMs, equals(40000));
    });
  });

  group('delete ripple (no gaps remain)', () {
    late AppDatabase db;
    late _RecordingRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = _RecordingRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('deleting the head clip repins the follower to 0', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          projectRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(projectProvider.notifier)
          .setProject(_project('/v/a.mp4', '/v/b.mp4', '/out'));

      final applied =
          await container.read(structuralEditApplierProvider).apply(
                EditOperation(
                  id: 'op_del',
                  type: EditOperationType.deleteClip,
                  targetClipIds: const ['clip_1'],
                  params: const {'clip_id': 'clip_1'},
                  createdAt: DateTime(2026, 1, 2),
                ),
              );

      expect(applied, isTrue);
      final clips = _clips(container);
      expect(clips.map((c) => c.id).toList(), equals(['clip_2']));
      expect(clips.single.positionMs, equals(0));
    });
  });
}
