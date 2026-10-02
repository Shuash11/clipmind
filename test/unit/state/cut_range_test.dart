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

/// Cycle 6 Phase 2 fixture: a ranged clip (`startMs: 5000`) so the
/// `-ss 5.0`/`-t 55.0` restriction and the shifted `between` times are
/// unambiguous (file times differ from the shifted clip-relative times).
Project _rangedProject(String inputA, String inputB, String outDir) {
  final base = _project(inputA, inputB, outDir);
  final clips = [
    base.tracks.first.clips.first.copyWith(startMs: 5000, endMs: 60000),
    base.tracks.first.clips[1].copyWith(positionMs: 55000),
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
    .value!
    .tracks
    .firstWhere((t) => t.id == 't1')
    .clips;

Clip _clip(ProviderContainer container, String id) =>
    _clips(container).singleWhere((c) => c.id == id);

/// Value following an FFmpeg flag (`-ss 5.0` → 5.0), or null when the flag
/// is absent. Accepts any decimal formatting (`5.0`/`5.00`/`5.000`).
double? _flagValue(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i < 0 || i + 1 >= args.length) return null;
  return double.tryParse(args[i + 1]);
}

/// First `between(t,a,b)` pair in the joined args, or null when absent.
List<double>? _betweenValues(String joined) {
  final m =
      RegExp(r'between\(t,([\d.]+),([\d.]+)\)').firstMatch(joined);
  if (m == null) return null;
  final a = double.tryParse(m.group(1)!);
  final b = double.tryParse(m.group(2)!);
  if (a == null || b == null) return null;
  return [a, b];
}

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
      final container = ProviderContainer.test(
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

    ProviderContainer makeContainer({bool trimmed = false, bool ranged = false}) {
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          projectRepositoryProvider.overrideWithValue(repository),
          ffmpegServiceProvider.overrideWithValue(ffmpeg),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(
            ranged
                ? _rangedProject(inputA, '${tmp.path}/b.mp4', outDir)
                : trimmed
                    ? _trimmedProject(inputA, '${tmp.path}/b.mp4', outDir)
                    : _project(inputA, '${tmp.path}/b.mp4', outDir),
          );
      return container;
    }

    test('handle-trimmed clip cuts at the file time', () async {
      final container = makeContainer(trimmed: true);

      // Timeline [5000, 15000) into the trimmed clip (in-point 10000):
      // the file segment is startMs + local = [15000, 25000). Phase 2
      // restricts the input to that clip extent (-ss 10.0 -t 50.0) and
      // shifts the `between` times by the in-point → [5, 15) clip-relative.
      final result = await container
          .read(manualEditControllerProvider)
          .submitCut(clipId: 'clip_1', startMs: 5000, endMs: 15000);

      expect(result.success, isTrue);
      final args = ffmpeg.lastJob!.args;
      final joined = args.join(' ');
      expect(_flagValue(args, '-ss'), closeTo(10.0, 0.001));
      expect(_flagValue(args, '-t'), closeTo(50.0, 0.001));
      final between = _betweenValues(joined);
      expect(between, isNotNull, reason: 'expected between(t,a,b) in: $joined');
      expect(between![0], closeTo(5.0, 0.001));
      expect(between[1], closeTo(15.0, 0.001));
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
      // Clip-relative [0, 10): the backend formats shifted times without
      // trailing zeros (0.0, not 0.000), so parse instead of matching text.
      final secondBetween =
          _betweenValues(ffmpeg.lastJob!.args.join(' '));
      expect(secondBetween, isNotNull);
      expect(secondBetween![0], closeTo(0.0, 0.001));
      expect(secondBetween[1], closeTo(10.0, 0.001));
      final cut = _clip(container, 'clip_1');
      expect(cut.startMs, equals(0));
      expect(cut.endMs, equals(40000));
      expect(cut.sourcePath, equals(second.outputPath));
      expect(_clip(container, 'clip_2').positionMs, equals(40000));
    });

    test('ranged clip restricts FFmpeg to the clip extent (Phase 2)', () async {
      final container = makeContainer(ranged: true);

      // Clip [5000, 60000) (len 55s) at position 0 → span [0, 55000).
      // Timeline [5000, 15000) → local [5000, 15000) → file [10000, 20000).
      // The backend restricts the input to -ss 5.0 -t 55.0 and shifts the
      // `between` times by the 5.0s in-point → [5, 15).
      final result = await container
          .read(manualEditControllerProvider)
          .submitCut(clipId: 'clip_1', startMs: 5000, endMs: 15000);

      expect(result.success, isTrue);
      final args = ffmpeg.lastJob!.args;
      final joined = args.join(' ');
      final ss = _flagValue(args, '-ss');
      final t = _flagValue(args, '-t');
      expect(ss, isNotNull,
          reason: 'ranged cut must restrict the input with -ss (clip_start_s)');
      expect(t, isNotNull,
          reason: 'ranged cut must restrict the input with -t (clip_len_s)');
      expect(ss!, closeTo(5.0, 0.001));
      expect(t!, closeTo(55.0, 0.001));
      final between = _betweenValues(joined);
      expect(between, isNotNull, reason: 'expected between(t,a,b) in: $joined');
      expect(between![0], closeTo(5.0, 0.001));
      expect(between[1], closeTo(15.0, 0.001));
    });

    test('propagated range equals clipLen minus removedLen (Phase 2)',
        () async {
      final container = makeContainer(ranged: true);

      final result = await container
          .read(manualEditControllerProvider)
          .submitCut(clipId: 'clip_1', startMs: 5000, endMs: 15000);

      expect(result.success, isTrue);
      // clipLen 55s − removed 10s = 45s → [0, 45000]; the follower repins
      // to 45000 so the timeline and the restricted output agree.
      final cut = _clip(container, 'clip_1');
      expect(cut.sourcePath, equals(result.outputPath));
      expect(cut.startMs, equals(0));
      expect(cut.endMs, equals(45000));
      expect(cut.endMs - cut.startMs, equals(45000));
      expect(_clip(container, 'clip_2').positionMs, equals(45000));
      // The restricted output extent implies the same length:
      // -t 55s of clip minus the 10s segment = 45s of output.
      final t = _flagValue(ffmpeg.lastJob!.args, '-t');
      expect(t, isNotNull);
      expect((t! - 10.0) * 1000, closeTo(45000, 1.0));
    });

    test('full-span clip matches the legacy whole-file path (Phase 2)',
        () async {
      final container = makeContainer();

      // Full clip [0, 60000): file times equal local times, so the shift
      // is a no-op and the restriction (-ss 0 / -t 60) is equivalent to
      // the legacy whole-file cut.
      final result = await container
          .read(manualEditControllerProvider)
          .submitCut(clipId: 'clip_1', startMs: 5000, endMs: 15000);

      expect(result.success, isTrue);
      final args = ffmpeg.lastJob!.args;
      final joined = args.join(' ');
      final ss = _flagValue(args, '-ss');
      if (ss != null) expect(ss, closeTo(0.0, 0.001));
      final between = _betweenValues(joined);
      expect(between, isNotNull, reason: 'expected between(t,a,b) in: $joined');
      expect(between![0], closeTo(5.0, 0.001));
      expect(between[1], closeTo(15.0, 0.001));
      // 60s minus the 10s segment → [0, 50000].
      final cut = _clip(container, 'clip_1');
      expect(cut.startMs, equals(0));
      expect(cut.endMs, equals(50000));
      expect(_clip(container, 'clip_2').positionMs, equals(50000));
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
      final container = ProviderContainer.test(
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
