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
  _RecordingRepository(super.db);

  @override
  Future<void> save(Project project) async {}
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
  Future<VideoMetadata?> extractMetadata(String filePath) async => const VideoMetadata(
        durationMs: 60000,
        width: 1920,
        height: 1080,
        fps: 30,
        codec: 'h264',
        hasAudio: true,
        bitrate: 1000,
      );
}

Project _project(String inputA, String outDir, {int startMs = 0, int endMs = 60000}) {
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

// Cycle 13 Phase 3a (effects stall fix): `submitRecipe` stamps the clip
// extent on the first op (`clip_start_s`/`clip_len_s`, the cut-path
// additive pattern) and the output range on the last op
// (`new_start_ms`/`new_end_ms`), so the composed job restricts FFmpeg to
// the clip (`-ss`/`-t` + `-preset veryfast`) and the clip range
// normalizes to the composed output on the final apply.
void main() {
  late Directory tmp;
  late AppDatabase db;
  late _RecordingRepository repository;
  late _FakeFfmpeg ffmpeg;
  late String inputA;
  late String outDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipmind_recipe_range_');
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

  group('submitRecipe range restriction (Phase 3a)', () {
    test('noir on a trimmed clip restricts, presets, and updates the range',
        () async {
      final container = makeContainer(startMs: 10000, endMs: 40000);
      final result = await container
          .read(manualEditControllerProvider)
          .submitRecipe('noir', clipId: 'clip_1');

      expect(result.success, isTrue);
      expect(ffmpeg.jobs, hasLength(1));
      final args = ffmpeg.jobs.single.args;
      expect(args, containsAll(['-ss', '10.0', '-i', inputA, '-t', '30.0']));
      expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
      expect(args.indexOf('-i'), lessThan(args.indexOf('-t')));
      expect(args, containsAll(['-preset', 'veryfast']));
      final joined = args.join(' ');
      expect(joined, contains('eq=saturation=0'));
      expect(joined, contains('eq=contrast=1.3'));

      // First op carries the input window, last op the output range.
      final journal = await db.getEditHistory('p1');
      expect(journal, hasLength(2));
      expect(journal.first.params['clip_start_s'], equals(10.0));
      expect(journal.first.params['clip_len_s'], equals(30.0));
      expect(journal.last.params['new_start_ms'], equals(0));
      expect(journal.last.params['new_end_ms'], equals(30000));
      expect(
        journal.map((e) => e.type),
        everyElement(equals(EditOperationType.applyEffect)),
      );

      // The clip range normalizes to the composed output.
      final clip = _clipOf(container);
      expect(clip.sourcePath, equals(result.outputPath));
      expect(clip.startMs, equals(0));
      expect(clip.endMs, equals(30000));

      await container.read(undoRedoProvider.notifier).undo();
      await container.read(undoRedoProvider.notifier).undo();
      final restored = _clipOf(container);
      expect(restored.sourcePath, equals(inputA));
      expect(restored.startMs, equals(10000));
      expect(restored.endMs, equals(40000));
    });

    test('single-step preset stamps the window + range on the one op',
        () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitRecipe('brighten', clipId: 'clip_1');

      expect(result.success, isTrue);
      expect(ffmpeg.jobs, hasLength(1));
      final args = ffmpeg.jobs.single.args;
      expect(args, containsAll(['-ss', '0.0', '-i', inputA, '-t', '60.0']));
      expect(args, containsAll(['-preset', 'veryfast']));
      expect(args.join(' '), contains('eq=brightness=0.25'));

      final journal = await db.getEditHistory('p1');
      expect(journal, hasLength(1));
      expect(journal.single.params['clip_start_s'], equals(0.0));
      expect(journal.single.params['clip_len_s'], equals(60.0));
      expect(journal.single.params['new_start_ms'], equals(0));
      expect(journal.single.params['new_end_ms'], equals(60000));

      final clip = _clipOf(container);
      expect(clip.sourcePath, equals(result.outputPath));
      expect(clip.startMs, equals(0));
      expect(clip.endMs, equals(60000));
    });
  });
}
