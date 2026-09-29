import 'dart:io';
import 'dart:typed_data';

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
import 'package:clipmind/data/services/ffmpeg/procedural_sound_service.dart';
import 'package:clipmind/data/services/fonts/font_resolver.dart';
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
  _FakeFfprobe(this.meta);

  final VideoMetadata? meta;

  @override
  Future<VideoMetadata?> extractMetadata(String filePath) async => meta;
}

class _FakeSound extends ProceduralSoundService {
  _FakeSound(this.tmpDir);

  final Directory tmpDir;
  final List<String> generatedFor = [];

  @override
  Future<String?> generate(
    String presetId, {
    String? outputPath,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!ProceduralSoundService.isKnownPreset(presetId)) return null;
    generatedFor.add(presetId);
    final out = outputPath ?? '${tmpDir.path}/$presetId.wav';
    await File(out).create(recursive: true);
    await File(out).writeAsString('wav');
    return out;
  }
}

VideoMetadata _meta({required bool hasAudio}) => VideoMetadata(
      durationMs: 60000,
      width: 1920,
      height: 1080,
      fps: 30,
      codec: 'h264',
      hasAudio: hasAudio,
      bitrate: 1000,
    );

Project _project(String inputA, String outDir) {
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
        ],
      ),
    ],
    durationMs: 60000,
    outputDir: outDir,
  );
}

String _sourceOf(ProviderContainer container) => container
    .read(projectProvider)
    .valueOrNull!
    .tracks
    .expand((t) => t.clips)
    .singleWhere((c) => c.id == 'clip_1')
    .sourcePath;

void main() {
  late Directory tmp;
  late AppDatabase db;
  late _RecordingRepository repository;
  late _FakeFfmpeg ffmpeg;
  late _FakeSound sound;
  late String inputA;
  late String outDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipmind_manual_panels_');
    db = AppDatabase(NativeDatabase.memory());
    repository = _RecordingRepository(db);
    ffmpeg = _FakeFfmpeg();
    sound = _FakeSound(tmp);
    inputA = (File('${tmp.path}/a.mp4')..writeAsStringSync('src')).path;
    outDir = (Directory('${tmp.path}/out')..createSync()).path;
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
    await db.close();
  });

  FontResolver seamedFonts() => FontResolver(
        loadAsset: (key) async =>
            ByteData.sublistView(Uint8List.fromList([1, 2, 3])),
        supportDir: () async => Directory('${tmp.path}/support'),
      );

  ProviderContainer makeContainer({VideoMetadata? meta}) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        projectRepositoryProvider.overrideWithValue(repository),
        ffmpegServiceProvider.overrideWithValue(ffmpeg),
        ffprobeServiceProvider.overrideWithValue(
          _FakeFfprobe(meta ?? _meta(hasAudio: true)),
        ),
        fontResolverProvider.overrideWithValue(seamedFonts()),
        proceduralSoundServiceProvider.overrideWithValue(sound),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(projectProvider.notifier)
        .setProject(_project(inputA, outDir));
    return container;
  }

  group('submitRecipe (T10)', () {
    test('unknown preset fails without side effects', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitRecipe('nope', clipId: 'clip_1');

      expect(result.success, isFalse);
      expect(result.message, contains('Unknown effect preset'));
      expect(ffmpeg.jobs, isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('unknown clip fails without side effects', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitRecipe('noir', clipId: 'ghost');

      expect(result.success, isFalse);
      expect(result.message, contains('Unknown clip'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('known recipe composes one job, applies, journals, undoes',
        () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitRecipe('noir', clipId: 'clip_1');

      expect(result.success, isTrue);
      expect(result.outputPath, isNotNull);
      expect(result.message, contains('Noir'));
      // One composed job for the two recipe steps.
      expect(ffmpeg.jobs, hasLength(1));
      final joined = ffmpeg.jobs.single.args.join(' ');
      expect(joined, contains('eq=saturation=0'));
      expect(joined, contains('eq=contrast=1.3'));
      // Repointed, undoable, journaled per step.
      expect(_sourceOf(container), equals(result.outputPath));
      expect(container.read(undoRedoProvider).canUndo, isTrue);
      final journal = await db.getEditHistory('p1');
      expect(journal, hasLength(2));
      expect(
        journal.map((e) => e.type),
        everyElement(equals(EditOperationType.applyEffect)),
      );

      await container.read(undoRedoProvider.notifier).undo();
      await container.read(undoRedoProvider.notifier).undo();
      expect(_sourceOf(container), equals(inputA));
    });
  });

  group('submitOverlayText (T10)', () {
    test('font family resolves into the op params + filter', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitOverlayText(
            clipId: 'clip_1',
            text: 'Hello',
            fontFamily: 'Inter',
          );

      expect(result.success, isTrue);
      expect(ffmpeg.jobs, hasLength(1));
      expect(ffmpeg.jobs.single.args.join(' '), contains('fontfile='));
      final journal = await db.getEditHistory('p1');
      expect(journal, hasLength(1));
      expect(journal.single.type, equals(EditOperationType.overlayText));
      expect(journal.single.params['font'], equals('inter'));
      expect(
        (journal.single.params['font_file'] as String).endsWith(
          'inter_regular.ttf',
        ),
        isTrue,
      );
      expect(_sourceOf(container), equals(result.outputPath));
    });

    test('unknown family fails without side effects', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitOverlayText(
            clipId: 'clip_1',
            text: 'Hello',
            fontFamily: 'comic-sans',
          );

      expect(result.success, isFalse);
      expect(result.message, contains('Unknown font'));
      expect(ffmpeg.jobs, isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('no font keeps the system default (no fontfile)', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitOverlayText(clipId: 'clip_1', text: 'Hello');

      expect(result.success, isTrue);
      expect(ffmpeg.jobs.single.args.join(' '), isNot(contains('fontfile')));
      final journal = await db.getEditHistory('p1');
      expect(journal.single.params.containsKey('font_file'), isFalse);
    });

    test('empty text fails without side effects', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitOverlayText(clipId: 'clip_1', text: '  ');

      expect(result.success, isFalse);
      expect(ffmpeg.jobs, isEmpty);
    });
  });

  group('submitSound (T10)', () {
    test('preset renders a wav and mixes when the clip has audio', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitSound(clipId: 'clip_1', soundSource: 'beep');

      expect(result.success, isTrue);
      expect(sound.generatedFor, equals(['beep']));
      expect(ffmpeg.jobs, hasLength(1));
      final joined = ffmpeg.jobs.single.args.join(' ');
      expect(joined, contains('beep.wav'));
      expect(joined, contains('amix=inputs=2'));
      final journal = await db.getEditHistory('p1');
      expect(journal.single.type, equals(EditOperationType.addSound));
      expect(journal.single.params['has_clip_audio'], isTrue);
      expect(_sourceOf(container), equals(result.outputPath));
      expect(container.read(undoRedoProvider).canUndo, isTrue);
    });

    test('local file is used directly when it exists', () async {
      final snd = (File('${tmp.path}/snd.wav')..writeAsStringSync('wav')).path;
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitSound(clipId: 'clip_1', soundSource: snd);

      expect(result.success, isTrue);
      expect(sound.generatedFor, isEmpty);
      expect(ffmpeg.jobs.single.args.join(' '), contains('snd.wav'));
    });

    test('traversal is rejected without side effects', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitSound(clipId: 'clip_1', soundSource: '../evil.wav');

      expect(result.success, isFalse);
      expect(result.message, contains('traversal'));
      expect(ffmpeg.jobs, isEmpty);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('missing file fails actionably', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitSound(
            clipId: 'clip_1',
            soundSource: '${tmp.path}/missing.wav',
          );

      expect(result.success, isFalse);
      expect(result.message, contains('not found'));
      expect(ffmpeg.jobs, isEmpty);
    });

    test('clipless audio maps the sound track without amix', () async {
      final container =
          makeContainer(meta: _meta(hasAudio: false));
      final result = await container
          .read(manualEditControllerProvider)
          .submitSound(clipId: 'clip_1', soundSource: 'beep');

      expect(result.success, isTrue);
      final args = ffmpeg.jobs.single.args;
      expect(args.join(' '), isNot(contains('amix')));
      expect(args, containsAll(['-map', '0:v', '-map', '1:a']));
      final journal = await db.getEditHistory('p1');
      expect(journal.single.params['has_clip_audio'], isFalse);
    });
  });

  group('panel provider wiring (T10)', () {
    test('font/sound providers and the resolveFont callback resolve',
        () async {
      final container = makeContainer();

      expect(container.read(fontResolverProvider), isA<FontResolver>());
      expect(
        container.read(proceduralSoundServiceProvider),
        isA<ProceduralSoundService>(),
      );
      final resolve = container.read(resolveFontProvider);
      final path = await resolve('inter');
      expect(path, isNotNull);
      expect(path!.endsWith('inter_regular.ttf'), isTrue);
      expect(await resolve('nope'), isNull);
    });
  });
}
