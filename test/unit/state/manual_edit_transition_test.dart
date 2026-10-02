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
  _FakeFfprobe(this.resolve);

  final VideoMetadata? Function(String path) resolve;

  @override
  Future<VideoMetadata?> extractMetadata(String filePath) async =>
      resolve(filePath);
}

VideoMetadata _meta({
  bool hasAudio = true,
  int durationMs = 60000,
  int width = 1920,
  int height = 1080,
  double fps = 30,
}) =>
    VideoMetadata(
      durationMs: durationMs,
      width: width,
      height: height,
      fps: fps,
      codec: 'h264',
      hasAudio: hasAudio,
      bitrate: 1000,
    );

Project _project(
  String inputA,
  String inputB,
  String outDir, {
  int firstStartMs = 0,
  int firstEndMs = 60000,
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
            startMs: firstStartMs,
            endMs: firstEndMs,
            positionMs: 0,
          ),
          Clip(
            id: 'clip_2',
            trackId: 't1',
            sourcePath: inputB,
            startMs: 0,
            endMs: 30000,
            positionMs: firstEndMs - firstStartMs,
          ),
        ],
      ),
    ],
    durationMs: 90000,
    outputDir: outDir,
  );
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late _RecordingRepository repository;
  late _FakeFfmpeg ffmpeg;
  late String inputA;
  late String inputB;
  late String outDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipmind_manual_transition_');
    db = AppDatabase(NativeDatabase.memory());
    repository = _RecordingRepository(db);
    ffmpeg = _FakeFfmpeg();
    inputA = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
    inputB = (File('${tmp.path}/b.mp4')..writeAsStringSync('src')).path;
    outDir = (Directory('${tmp.path}/out')..createSync()).path;
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
    await db.close();
  });

  ProviderContainer makeContainer({
    VideoMetadata? Function(String path)? probe,
    int firstStartMs = 0,
    int firstEndMs = 60000,
  }) {
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        projectRepositoryProvider.overrideWithValue(repository),
        ffmpegServiceProvider.overrideWithValue(ffmpeg),
        ffprobeServiceProvider.overrideWithValue(
          _FakeFfprobe(probe ?? (_) => _meta()),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(projectProvider.notifier).setProject(
          _project(
            inputA,
            inputB,
            outDir,
            firstStartMs: firstStartMs,
            firstEndMs: firstEndMs,
          ),
        );
    return container;
  }

  group('submitTransition', () {
    test('unknown preset fails listing available', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('nope', clipId: 'clip_1');

      expect(result.success, isFalse);
      expect(result.message, contains('Unknown transition preset'));
      expect(result.message, contains('fade'));
      expect(ffmpeg.jobs, isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('unknown clip fails without side effects', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('fade', clipId: 'ghost');

      expect(result.success, isFalse);
      expect(result.message, contains('Unknown clip'));
      expect(ffmpeg.jobs, isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('trailing clip with no follower fails actionably', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('fade', clipId: 'clip_2');

      expect(result.success, isFalse);
      expect(result.message, contains('following clip'));
      expect(ffmpeg.jobs, isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('happy path maps one job, journals, replaces the pair', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('fade', clipId: 'clip_1');

      expect(result.success, isTrue);
      expect(result.outputPath, isNotNull);
      expect(result.message, contains('Fade'));
      // ONE job for the single transition op.
      expect(ffmpeg.jobs, hasLength(1));
      final args = ffmpeg.jobs.single.args;
      final joined = args.join(' ');
      expect(joined, contains('xfade=transition=fade'));
      expect(joined, contains('acrossfade'));
      // The executor's param set rides the journaled op.
      final journal = await db.getEditHistory('p1');
      expect(journal, hasLength(1));
      expect(journal.single.type, equals(EditOperationType.addTransition));
      expect(journal.single.params['second_clip_id'], equals('clip_2'));
      expect(journal.single.params['transition'], equals('fade'));
      expect(journal.single.params['duration'], equals(0.5));
      expect(journal.single.params['offset'], closeTo(59.5, 1e-9));
      expect(journal.single.params['audio_mode'], equals('crossfade'));
      expect(
        journal.single.params['clip_ids'],
        equals(['clip_1', 'clip_2']),
      );
      // Pair replacement: the first clip is repointed, the second removed.
      final clips =
          container.read(projectProvider).value!.tracks.single.clips;
      expect(clips.map((c) => c.id), equals(['clip_1']));
      expect(clips.single.sourcePath, equals(result.outputPath));
      expect(container.read(undoRedoProvider).canUndo, isTrue);
    });

    test('resolution mismatch fails with a resize-first message', () async {
      final container = makeContainer(
        probe: (path) => path == inputA
            ? _meta()
            : _meta(width: 1280, height: 720),
      );
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('dissolve', clipId: 'clip_1');

      expect(result.success, isFalse);
      expect(result.message, contains('resolution'));
      expect(result.message, contains('resize'));
      expect(ffmpeg.jobs, isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('fps mismatch fails actionably', () async {
      final container = makeContainer(
        probe: (path) => path == inputA ? _meta() : _meta(fps: 25),
      );
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('wipeleft', clipId: 'clip_1');

      expect(result.success, isFalse);
      expect(result.message, contains('frame rate'));
      expect(ffmpeg.jobs, isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('first-only audio maps the bearing track', () async {
      final container = makeContainer(
        probe: (path) =>
            path == inputA ? _meta(hasAudio: true) : _meta(hasAudio: false),
      );
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('fade', clipId: 'clip_1');

      expect(result.success, isTrue);
      expect(result.message, contains('crossfade is skipped'));
      final args = ffmpeg.jobs.single.args;
      expect(args.join(' '), isNot(contains('acrossfade')));
      expect(args, containsAll(['-map', '0:a']));
      final journal = await db.getEditHistory('p1');
      expect(journal.single.params['audio_mode'], equals('first'));
    });

    test('second-only audio maps the incoming track', () async {
      final container = makeContainer(
        probe: (path) =>
            path == inputA ? _meta(hasAudio: false) : _meta(hasAudio: true),
      );
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('fade', clipId: 'clip_1');

      expect(result.success, isTrue);
      final args = ffmpeg.jobs.single.args;
      expect(args.join(' '), isNot(contains('acrossfade')));
      expect(args, containsAll(['-map', '1:a']));
      final journal = await db.getEditHistory('p1');
      expect(journal.single.params['audio_mode'], equals('second'));
    });

    test('audio-less pair renders video only', () async {
      final container = makeContainer(
        probe: (_) => _meta(hasAudio: false),
      );
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('fade', clipId: 'clip_1');

      expect(result.success, isTrue);
      expect(ffmpeg.jobs.single.args, contains('-an'));
      final journal = await db.getEditHistory('p1');
      expect(journal.single.params['audio_mode'], equals('none'));
    });

    test('unverifiable probes proceed with a caution', () async {
      final container = makeContainer(probe: (_) => null);
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('fade', clipId: 'clip_1');

      expect(result.success, isTrue);
      expect(result.message, contains('could not be verified'));
      expect(ffmpeg.jobs, hasLength(1));
      final journal = await db.getEditHistory('p1');
      expect(journal.single.params['audio_mode'], equals('crossfade'));
      // Fallback: the clip range (60s) stands in for the probe duration.
      expect(journal.single.params['offset'], closeTo(59.5, 1e-9));
    });

    test('short source clamps the offset at zero', () async {
      final container = makeContainer(
        probe: (path) =>
            path == inputA ? _meta(durationMs: 300) : _meta(),
      );
      final result = await container
          .read(manualEditControllerProvider)
          .submitTransition('fade', clipId: 'clip_1');

      expect(result.success, isTrue);
      final journal = await db.getEditHistory('p1');
      // max(0, 0.3 − 0.5) == 0.
      expect(journal.single.params['offset'], equals(0.0));
    });
  });
}
