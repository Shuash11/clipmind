import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/export_options.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/domain/usecases/export_project_usecase.dart';

/// Cycle 6 Phase 2 Step 2 (D1): export progress/cancel/error/dispose paths.
///
/// The REAL [ExportProjectUseCase] drives a configurable fake
/// [FfmpegService] (`extends`, the `cut_range_test.dart` pattern): scripted
/// progress percents, optional output-file creation, optional mid-run
/// delays for the cancel tests, and an optional throw for the error test.
class _FlowFfmpeg extends FfmpegService {
  _FlowFfmpeg(
    this._tmp, {
    this.script = const [0.25, 0.5],
    this.createFile = true,
    this.delay = Duration.zero,
  }) : super(tempDir: _tmp.path);

  final Directory _tmp;
  List<double> script;
  bool createFile;
  Duration delay;
  bool shouldThrow = false;
  void Function()? onCreateTempPath;

  final List<FfmpegJob> jobs = [];
  int tempCalls = 0;
  bool cancelCalled = false;

  @override
  String createTempPath({String? suffix}) {
    tempCalls++;
    onCreateTempPath?.call();
    return '${_tmp.path}/flow_$tempCalls${suffix ?? '.mp4'}';
  }

  @override
  Stream<FfmpegProgress> run(FfmpegJob job) async* {
    jobs.add(job);
    if (shouldThrow) throw Exception('ffmpeg boom');
    for (final p in script) {
      if (delay != Duration.zero) {
        await Future<void>.delayed(delay);
      }
      yield FfmpegProgress(
        percent: p,
        outTimeMs: (job.expectedDurationMs * p).toInt(),
        speed: '',
        status: 'running',
      );
    }
    if (delay != Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (createFile) {
      final out = File(job.outputPath);
      out.parent.createSync(recursive: true);
      out.writeAsStringSync('fake-export');
    }
    yield FfmpegProgress(
      percent: 1.0,
      outTimeMs: job.expectedDurationMs,
      speed: '',
      status: 'complete',
    );
  }

  @override
  void cancel() {
    cancelCalled = true;
  }
}

Project _project({int durationMs = 60000}) {
  return Project(
    id: 'p1',
    name: 'ExportFlow',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['/v/a.mp4'],
    tracks: const [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'V',
        clips: [
          Clip(
            id: 'c1',
            trackId: 't1',
            sourcePath: '/v/a.mp4',
            startMs: 0,
            endMs: 60000,
          ),
        ],
      ),
    ],
    durationMs: durationMs,
  );
}

ExportOptions _options(Directory tmp, String name) => ExportOptions(
      format: 'mp4',
      resolution: 'source',
      quality: 'high',
      crf: 18,
      outputPath: '${tmp.path}/$name.mp4',
    );

/// Run [useCase] while collecting its broadcast progress emissions.
Future<(ExportResult, List<double>)> _runWithProgress(
  ExportProjectUseCase useCase,
  Project project,
  ExportOptions options,
) async {
  final seen = <double>[];
  final sub = useCase.progressStream.listen(seen.add);
  try {
    final result = await useCase.execute(project, options: options);
    // Broadcast delivery is async: flush before asserting.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return (result, seen);
  } finally {
    await sub.cancel();
  }
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipmind_export_flow_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('success and progress', () {
    test('success writes the file and emits progress 1.0', () async {
      final fake = _FlowFfmpeg(tmp);
      final useCase = ExportProjectUseCase(ffmpegService: fake);
      try {
        final (result, seen) = await _runWithProgress(
          useCase,
          _project(),
          _options(tmp, 'ok'),
        );
        expect(result.success, isTrue);
        expect(result.outputPath, equals('${tmp.path}/ok.mp4'));
        expect(File(result.outputPath).existsSync(), isTrue);
        expect(seen, contains(1.0));
      } finally {
        useCase.dispose();
      }
    });

    test('intermediate percents are surfaced on the progress stream',
        () async {
      final fake = _FlowFfmpeg(tmp, script: const [0.2, 0.45, 0.8]);
      final useCase = ExportProjectUseCase(ffmpegService: fake);
      try {
        final (result, seen) = await _runWithProgress(
          useCase,
          _project(),
          _options(tmp, 'percents'),
        );
        expect(result.success, isTrue);
        expect(seen, contains(0.2));
        expect(seen, contains(0.45));
        expect(seen, contains(0.8));
        expect(seen.last, equals(1.0));
      } finally {
        useCase.dispose();
      }
    });
  });

  group('cancel', () {
    test('cancel mid-run reports Export cancelled', () async {
      final fake = _FlowFfmpeg(
        tmp,
        script: const [0.2, 0.4, 0.6],
        delay: const Duration(milliseconds: 120),
      );
      final useCase = ExportProjectUseCase(ffmpegService: fake);
      try {
        final future =
            useCase.execute(_project(), options: _options(tmp, 'cancel'));
        // Land mid-run: the first scripted yield fires around 120ms.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        useCase.cancel();
        final result = await future;
        expect(result.success, isFalse);
        expect(result.error, contains('cancelled'));
        expect(fake.cancelCalled, isTrue);
      } finally {
        useCase.dispose();
      }
    });

    test('cancel during output-path resolution runs no job', () async {
      final fake = _FlowFfmpeg(tmp);
      final useCase = ExportProjectUseCase(ffmpegService: fake);
      try {
        // Empty outputPath routes through createTempPath; the hook
        // cancels before the args build, so the job never runs.
        fake.onCreateTempPath = useCase.cancel;
        final result = await useCase.execute(
          _project(),
          options: const ExportOptions(
            format: 'mp4',
            resolution: 'source',
            quality: 'high',
            crf: 18,
            outputPath: '',
          ),
        );
        expect(result.success, isFalse);
        expect(result.error, equals('Export cancelled'));
        expect(fake.jobs, isEmpty);
      } finally {
        useCase.dispose();
      }
    });
  });

  group('errors', () {
    test('missing output file reports Output file was not created', () async {
      final fake = _FlowFfmpeg(tmp, createFile: false);
      final useCase = ExportProjectUseCase(ffmpegService: fake);
      try {
        final result = await useCase.execute(
          _project(),
          options: _options(tmp, 'missing'),
        );
        expect(result.success, isFalse);
        expect(result.error, equals('Output file was not created'));
      } finally {
        useCase.dispose();
      }
    });

    test('a throwing service surfaces the error', () async {
      final fake = _FlowFfmpeg(tmp)..shouldThrow = true;
      final useCase = ExportProjectUseCase(ffmpegService: fake);
      try {
        final result = await useCase.execute(
          _project(),
          options: _options(tmp, 'throw'),
        );
        expect(result.success, isFalse);
        expect(result.error, contains('ffmpeg boom'));
      } finally {
        useCase.dispose();
      }
    });

    test('empty project runs no job', () async {
      final fake = _FlowFfmpeg(tmp);
      final useCase = ExportProjectUseCase(ffmpegService: fake);
      try {
        final empty = Project(
          id: 'p0',
          name: 'Empty',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          durationMs: 0,
        );
        final result = await useCase.execute(
          empty,
          options: _options(tmp, 'empty'),
        );
        expect(result.success, isFalse);
        expect(result.error, equals('No clips to export'));
        expect(fake.jobs, isEmpty);
      } finally {
        useCase.dispose();
      }
    });
  });

  group('lifecycle', () {
    test('dispose closes the stream without crashing', () async {
      final fake = _FlowFfmpeg(tmp);
      final useCase = ExportProjectUseCase(ffmpegService: fake);
      final result = await useCase.execute(
        _project(),
        options: _options(tmp, 'dispose'),
      );
      expect(result.success, isTrue);
      useCase.dispose();
      await expectLater(useCase.progressStream, emitsDone);
    });
  });
}
