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
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/manual_edit_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
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
  final List<FfmpegJob> jobs = [];

  _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path);

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    jobs.add(job);
    final out = File(job.outputPath);
    await out.parent.create(recursive: true);
    await out.writeAsString('fake');
    return FfmpegResult(success: true, outputPath: job.outputPath, exitCode: 0);
  }
}

class _FakeFfprobe extends FfprobeService {
  @override
  Future<VideoMetadata?> extractMetadata(String filePath) async => null;
}

Project _project(
  String inputA,
  String outDir, {
  int startMs = 0,
  int endMs = 60000,
}) {
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
            startMs: startMs,
            endMs: endMs,
            positionMs: 0,
          ),
        ],
      ),
    ],
    durationMs: endMs - startMs,
    outputDir: outDir,
  );
}

Clip _clipOf(ProviderContainer container) => container
    .read(projectProvider)
    .value!
    .tracks
    .expand((t) => t.clips)
    .singleWhere((c) => c.id == 'clip_1');

void main() {
  late Directory tmp;
  late AppDatabase db;
  late _RecordingRepository repository;
  late _FakeFfmpeg ffmpeg;
  late String inputA;
  late String outDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipmind_manual_adjust_');
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

  ProviderContainer makeContainer({int startMs = 0, int endMs = 60000}) {
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        projectRepositoryProvider.overrideWithValue(repository),
        ffmpegServiceProvider.overrideWithValue(ffmpeg),
        ffprobeServiceProvider.overrideWithValue(_FakeFfprobe()),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(projectProvider.notifier)
        .setProject(_project(inputA, outDir, startMs: startMs, endMs: endMs));
    return container;
  }

  group('submitAdjustments', () {
    test('all-null is a no-op without running FFmpeg', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitAdjustments(clipId: 'clip_1');

      expect(result.success, isTrue);
      expect(result.message, contains('Nothing to adjust'));
      expect(result.outputPath, isNull);
      expect(ffmpeg.jobs, isEmpty);
      expect(await db.getEditHistory('p1'), isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
      expect(_clipOf(container).sourcePath, equals(inputA));
    });

    test('all-neutral values are a no-op without running FFmpeg', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitAdjustments(
            clipId: 'clip_1',
            brightness: 0.0,
            contrast: 1.0,
            saturation: 1.0,
            speed: 1.0,
            volume: 1.0,
          );

      expect(result.success, isTrue);
      expect(result.message, contains('Nothing to adjust'));
      expect(ffmpeg.jobs, isEmpty);
      expect(await db.getEditHistory('p1'), isEmpty);
    });

    test('unknown clip fails without side effects', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitAdjustments(clipId: 'ghost', brightness: 0.2);

      expect(result.success, isFalse);
      expect(result.message, contains('Unknown clip'));
      expect(ffmpeg.jobs, isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('brightness-only maps one job and journals the op', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitAdjustments(clipId: 'clip_1', brightness: 0.2);

      expect(result.success, isTrue);
      expect(result.outputPath, isNotNull);
      expect(ffmpeg.jobs, hasLength(1));
      expect(
        ffmpeg.jobs.single.args.join(' '),
        contains('eq=brightness=0.2'),
      );
      expect(_clipOf(container).sourcePath, equals(result.outputPath));
      final journal = await db.getEditHistory('p1');
      expect(journal, hasLength(1));
      expect(journal.single.type, equals(EditOperationType.adjustBrightness));
      expect(journal.single.params['value'], equals(0.2));

      await container.read(undoRedoProvider.notifier).undo();
      expect(_clipOf(container).sourcePath, equals(inputA));
    });

    test('speed-only restricts to the clip range and updates the range',
        () async {
      // Handle-trimmed clip: the restriction must use the live range
      // ([10s, 40s)), and the new range is [0, 30000/2].
      final container = makeContainer(startMs: 10000, endMs: 40000);
      final result = await container
          .read(manualEditControllerProvider)
          .submitAdjustments(clipId: 'clip_1', speed: 2.0);

      expect(result.success, isTrue);
      expect(ffmpeg.jobs, hasLength(1));
      final args = ffmpeg.jobs.single.args;
      expect(args, containsAll(['-ss', '10.0', '-i', inputA, '-t', '30.0']));
      expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
      expect(args.indexOf('-i'), lessThan(args.indexOf('-t')));
      final joined = args.join(' ');
      expect(joined, contains('setpts=PTS/2.0'));
      expect(joined, contains('atempo=2.0'));

      final journal = await db.getEditHistory('p1');
      expect(journal, hasLength(1));
      expect(journal.single.type, equals(EditOperationType.changeSpeed));
      expect(journal.single.params['factor'], equals(2.0));
      expect(journal.single.params['new_start_ms'], equals(0));
      expect(journal.single.params['new_end_ms'], equals(15000));

      final clip = _clipOf(container);
      expect(clip.sourcePath, equals(result.outputPath));
      expect(clip.startMs, equals(0));
      expect(clip.endMs, equals(15000));

      await container.read(undoRedoProvider.notifier).undo();
      final restored = _clipOf(container);
      expect(restored.sourcePath, equals(inputA));
      expect(restored.startMs, equals(10000));
      expect(restored.endMs, equals(40000));
    });

    test('brightness+speed compose one job with the range on the speed op',
        () async {
      final container = makeContainer(startMs: 10000, endMs: 40000);
      final result = await container
          .read(manualEditControllerProvider)
          .submitAdjustments(
            clipId: 'clip_1',
            brightness: 0.2,
            speed: 2.0,
          );

      expect(result.success, isTrue);
      // ONE composed job for both ops.
      expect(ffmpeg.jobs, hasLength(1));
      final args = ffmpeg.jobs.single.args;
      expect(args, containsAll(['-ss', '10.0', '-i', inputA, '-t', '30.0']));
      final graph = args[args.indexOf('-filter_complex') + 1];
      expect(graph, contains('eq=brightness=0.2'));
      expect(graph, contains('setpts=PTS/2.0'));

      // Two per-step journal rows, both on the composed output; only the
      // speed op carries the new-range keys. (The composed-output
      // pointing is read from the in-memory history: the DB read-back
      // does not round-trip `ffmpegCommand`.)
      final journal = await db.getEditHistory('p1');
      expect(journal, hasLength(2));
      final memoryHistory =
          container.read(projectProvider).value!.editHistory;
      expect(memoryHistory, hasLength(2));
      final composedCommand = args.join(' ');
      expect(
        memoryHistory.map((e) => e.ffmpegCommand),
        everyElement(equals(composedCommand)),
      );
      final brightnessOp = journal.singleWhere(
        (e) => e.type == EditOperationType.adjustBrightness,
      );
      expect(brightnessOp.params['value'], equals(0.2));
      expect(brightnessOp.params.containsKey('new_start_ms'), isFalse);
      final speedOp = journal.singleWhere(
        (e) => e.type == EditOperationType.changeSpeed,
      );
      expect(speedOp.params['new_start_ms'], equals(0));
      expect(speedOp.params['new_end_ms'], equals(15000));

      final clip = _clipOf(container);
      expect(clip.sourcePath, equals(result.outputPath));
      expect(clip.startMs, equals(0));
      expect(clip.endMs, equals(15000));

      await container.read(undoRedoProvider.notifier).undo();
      await container.read(undoRedoProvider.notifier).undo();
      final restored = _clipOf(container);
      expect(restored.sourcePath, equals(inputA));
      expect(restored.startMs, equals(10000));
      expect(restored.endMs, equals(40000));
    });

    test('volume-only maps the factor param', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitAdjustments(clipId: 'clip_1', volume: 0.5);

      expect(result.success, isTrue);
      expect(ffmpeg.jobs, hasLength(1));
      expect(ffmpeg.jobs.single.args.join(' '), contains('volume=0.5'));
      final journal = await db.getEditHistory('p1');
      expect(journal.single.type, equals(EditOperationType.changeVolume));
      expect(journal.single.params['factor'], equals(0.5));
      expect(_clipOf(container).sourcePath, equals(result.outputPath));
    });

    test('contrast maps the apply_effect contrast param', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitAdjustments(clipId: 'clip_1', contrast: 1.3);

      expect(result.success, isTrue);
      expect(ffmpeg.jobs.single.args.join(' '), contains('eq=contrast=1.3'));
      final journal = await db.getEditHistory('p1');
      expect(journal.single.type, equals(EditOperationType.applyEffect));
      expect(journal.single.params['effect'], equals('contrast'));
      expect(journal.single.params['contrast'], equals(1.3));
    });

    test('saturation maps the apply_effect saturation param', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitAdjustments(clipId: 'clip_1', saturation: 1.5);

      expect(result.success, isTrue);
      expect(
        ffmpeg.jobs.single.args.join(' '),
        contains('eq=saturation=1.5'),
      );
      final journal = await db.getEditHistory('p1');
      expect(journal.single.type, equals(EditOperationType.applyEffect));
      expect(journal.single.params['effect'], equals('saturation'));
      expect(journal.single.params['saturation'], equals(1.5));
    });

    test('out-of-bounds values are rejected without side effects', () async {
      final container = makeContainer();
      final controller = container.read(manualEditControllerProvider);

      final badCalls = [
        () => controller.submitAdjustments(
              clipId: 'clip_1',
              brightness: 2.0,
            ),
        () => controller.submitAdjustments(
              clipId: 'clip_1',
              brightness: -1.5,
            ),
        () => controller.submitAdjustments(
              clipId: 'clip_1',
              brightness: double.nan,
            ),
        () => controller.submitAdjustments(
              clipId: 'clip_1',
              contrast: -0.5,
            ),
        () => controller.submitAdjustments(
              clipId: 'clip_1',
              contrast: 3.5,
            ),
        () => controller.submitAdjustments(
              clipId: 'clip_1',
              saturation: 4.0,
            ),
        () => controller.submitAdjustments(
              clipId: 'clip_1',
              speed: 0.1,
            ),
        () => controller.submitAdjustments(
              clipId: 'clip_1',
              speed: 5.0,
            ),
        () => controller.submitAdjustments(
              clipId: 'clip_1',
              volume: -0.5,
            ),
        () => controller.submitAdjustments(
              clipId: 'clip_1',
              volume: 2.5,
            ),
      ];
      for (final call in badCalls) {
        final result = await call();
        expect(result.success, isFalse);
      }
      expect(ffmpeg.jobs, isEmpty);
      expect(await db.getEditHistory('p1'), isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
      expect(_clipOf(container).sourcePath, equals(inputA));
    });
  });
}
