import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/export_options.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/state/agent_providers.dart' as agent_state;
import 'package:clipmind/state/export_providers.dart';
import 'package:clipmind/state/ffmpeg_providers.dart' as ffmpeg_state;
import 'package:clipmind/state/manual_edit_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';

/// Cycle 6 Phase 2 Step 2 (D1): export-after-manual-edit integration.
///
/// The MEDIUM test-coverage gap: the app's final output must reflect the
/// POST-EDIT clip ranges. Each test drives a manual path
/// (`submitTrim`/`submitCut`/`submitSplit`) through a ProviderContainer
/// with a capturing fake FFmpeg, then exports the updated project via the
/// REAL [exportUseCaseProvider] and asserts the captured concat graph
/// slices the NEW ranges.
///
/// The fake serves both legs: `runSync` (the cut's mapper/engine leg)
/// and `run` (the export leg, which captures the job and materializes the
/// output file). Both `ffmpegServiceProvider`s are overridden with the
/// same fake — the manual controller reads the agent-scoped one while the
/// export use case watches the ffmpeg-scoped one.
class _RecordingRepository extends ProjectRepository {
  _RecordingRepository(super.db);

  @override
  Future<void> save(Project project) async {}
}

class _EditExportFfmpeg extends FfmpegService {
  _EditExportFfmpeg(this._tmp) : super(tempDir: _tmp.path);

  final Directory _tmp;
  final List<FfmpegJob> exportJobs = [];
  FfmpegJob? lastCutJob;
  int _counter = 0;

  @override
  String createTempPath({String? suffix}) {
    _counter++;
    return '${_tmp.path}/after_edit_$_counter${suffix ?? '.mp4'}';
  }

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    lastCutJob = job;
    final out = File(job.outputPath);
    await out.parent.create(recursive: true);
    await out.writeAsString('fake-cut');
    return FfmpegResult(
      success: true,
      outputPath: job.outputPath,
      exitCode: 0,
    );
  }

  @override
  Stream<FfmpegProgress> run(FfmpegJob job) async* {
    exportJobs.add(job);
    final out = File(job.outputPath);
    out.parent.createSync(recursive: true);
    out.writeAsStringSync('fake-export');
    yield FfmpegProgress(
      percent: 1.0,
      outTimeMs: job.expectedDurationMs,
      speed: '',
      status: 'complete',
    );
  }

  @override
  void cancel() {}
}

Project _project(String inputA, String inputB, String outDir) {
  return Project(
    id: 'p1',
    name: 'AfterEdit',
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

/// CRLF-safe normalization (the repo mixes CRLF/LF).
String _joined(FfmpegJob job) => job.args.join(' ').replaceAll('\r\n', '\n');

void main() {
  late Directory tmp;
  late AppDatabase db;
  late _RecordingRepository repository;
  late _EditExportFfmpeg ffmpeg;
  late String inputA;
  late String inputB;
  late String outDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipmind_export_edit_');
    db = AppDatabase(NativeDatabase.memory());
    repository = _RecordingRepository(db);
    ffmpeg = _EditExportFfmpeg(tmp);
    inputA = (File('${tmp.path}/a.mp4')..writeAsStringSync('src-a')).path;
    inputB = (File('${tmp.path}/b.mp4')..writeAsStringSync('src-b')).path;
    outDir = (Directory('${tmp.path}/out')..createSync()).path;
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
    await db.close();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        projectRepositoryProvider.overrideWithValue(repository),
        agent_state.ffmpegServiceProvider.overrideWithValue(ffmpeg),
        ffmpeg_state.ffmpegServiceProvider.overrideWithValue(ffmpeg),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(projectProvider.notifier)
        .setProject(_project(inputA, inputB, outDir));
    return container;
  }

  Future<String> exportAndJoin(
    ProviderContainer container,
    String name,
  ) async {
    final project = container.read(projectProvider).value!;
    final useCase = container.read(exportUseCaseProvider);
    final result = await useCase.execute(
      project,
      options: ExportOptions(
        format: 'mp4',
        resolution: 'source',
        quality: 'high',
        crf: 18,
        outputPath: '${tmp.path}/$name.mp4',
      ),
    );
    expect(result.success, isTrue, reason: 'export failed: ${result.error}');
    expect(ffmpeg.exportJobs, hasLength(1));
    return _joined(ffmpeg.exportJobs.single);
  }

  group('manual paths flow into the export graph', () {
    test('submitTrim exports the post-trim ranges', () async {
      final container = makeContainer();

      // The structural applier runs no FFmpeg: no output file.
      final trim = await container
          .read(manualEditControllerProvider)
          .submitTrim(clipId: 'clip_1', startMs: 10000, endMs: 50000);
      expect(trim.success, isTrue);
      expect(trim.outputPath, isNull);

      final clips = container
          .read(projectProvider)
          .value!
          .tracks
          .single
          .clips;
      expect(clips.first.startMs, equals(10000));
      expect(clips.first.endMs, equals(50000));

      final joined = await exportAndJoin(container, 'trimmed');
      expect(joined, contains('trim=start=10.0:end=50.0'));
      expect(joined, contains('atrim=start=10.0:end=50.0'));
      expect(joined, isNot(contains('end=60.0')));
    });

    test('submitCut exports the normalized [0, newLen] range (MEDIUM gap)',
        () async {
      final container = makeContainer();

      // 60s clip minus the 10s [5000, 15000) segment: the applier
      // normalizes the repointed clip to [0, 50000] via the additive
      // `new_start_ms`/`new_end_ms` params.
      final cut = await container
          .read(manualEditControllerProvider)
          .submitCut(clipId: 'clip_1', startMs: 5000, endMs: 15000);
      expect(cut.success, isTrue);
      expect(ffmpeg.lastCutJob, isNotNull);

      final cutClip = container
          .read(projectProvider)
          .value!
          .tracks
          .single
          .clips
          .singleWhere((c) => c.id == 'clip_1');
      expect(cutClip.sourcePath, equals(cut.outputPath));
      expect(cutClip.startMs, equals(0));
      expect(cutClip.endMs, equals(50000));

      // The captured concat graph uses the POST-EDIT range: the stale
      // 60s extent must not appear.
      final joined = await exportAndJoin(container, 'cut');
      expect(joined, contains('trim=start=0.0:end=50.0'));
      expect(joined, contains('atrim=start=0.0:end=50.0'));
      expect(joined, isNot(contains('end=60.0')));
    });

    test('submitSplit exports two trim chains in one graph', () async {
      final container = makeContainer();

      final split = await container
          .read(manualEditControllerProvider)
          .submitSplit(clipId: 'clip_1', atProjectMs: 20000);
      expect(split.success, isTrue);
      expect(split.outputPath, isNull);

      final clips = container
          .read(projectProvider)
          .value!
          .tracks
          .single
          .clips;
      expect(clips.length, equals(3));
      expect(clips[0].startMs, equals(0));
      expect(clips[0].endMs, equals(20000));
      expect(clips[1].startMs, equals(20000));
      expect(clips[1].endMs, equals(60000));

      final joined = await exportAndJoin(container, 'split');
      // All three clips (both halves + the follower) concat in one graph.
      expect(joined, contains('concat=n=3:v=1:a=1'));
      expect(joined, contains('trim=start=0.0:end=20.0'));
      expect(joined, contains('trim=start=20.0:end=60.0'));
      expect(joined, contains('trim=start=0.0:end=30.0'));
    });
  });
}
