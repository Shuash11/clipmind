import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/export_options.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/domain/usecases/export_project_usecase.dart';
import 'package:clipmind/state/project_providers.dart';

/// Cycle 6 Phase 2 Step 2 (D1): export arg-structure unit tests.
///
/// Every test drives the REAL [ExportProjectUseCase.execute] through a
/// capturing fake [FfmpegService] (`extends`, the `cut_range_test.dart`
/// pattern): the fake records the [FfmpegJob], materializes the output file
/// so the `existsSync()` gate passes, and yields scripted progress. No
/// production changes were needed for testability (the service is
/// constructor-injectable).
class _CapturingFfmpeg extends FfmpegService {
  _CapturingFfmpeg(this._tmp) : super(tempDir: _tmp.path);

  final Directory _tmp;
  final List<FfmpegJob> jobs = [];
  int createTempPathCalls = 0;
  int _counter = 0;

  FfmpegJob get lastJob => jobs.last;

  @override
  String createTempPath({String? suffix}) {
    createTempPathCalls++;
    _counter++;
    return '${_tmp.path}/export_arg_$_counter${suffix ?? '.mp4'}';
  }

  @override
  Stream<FfmpegProgress> run(FfmpegJob job) async* {
    jobs.add(job);
    final out = File(job.outputPath);
    out.parent.createSync(recursive: true);
    out.writeAsStringSync('fake-export');
    yield FfmpegProgress(
      percent: 0.5,
      outTimeMs: job.expectedDurationMs ~/ 2,
      speed: '',
      status: 'running',
    );
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

Clip _clip(
  String id,
  String sourcePath, {
  int startMs = 0,
  int endMs = 60000,
  int positionMs = 0,
  bool muted = false,
}) {
  return Clip(
    id: id,
    trackId: 't1',
    sourcePath: sourcePath,
    startMs: startMs,
    endMs: endMs,
    positionMs: positionMs,
    muted: muted,
  );
}

Project _project(
  List<Clip> clips, {
  int durationMs = 90000,
  String name = 'ExportArgs',
}) {
  return Project(
    id: 'p1',
    name: name,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['/v/a.mp4'],
    tracks: [Track(id: 't1', type: TrackType.video, label: 'V', clips: clips)],
    durationMs: durationMs,
  );
}

const _mp4 = ExportOptions(
  format: 'mp4',
  resolution: 'source',
  quality: 'high',
  crf: 18,
  outputPath: '',
);

/// CRLF-safe normalization (the repo mixes CRLF/LF): collapse Windows line
/// endings before substring matching.
String _joined(FfmpegJob job) =>
    job.args.join(' ').replaceAll('\r\n', '\n');

/// Run the real use case against [project] and return the captured job.
/// Fails the test when the export itself reports an error.
Future<FfmpegJob> _export(
  Project project,
  _CapturingFfmpeg fake, {
  ExportOptions options = _mp4,
}) async {
  final useCase = ExportProjectUseCase(ffmpegService: fake);
  try {
    final result = await useCase.execute(project, options: options);
    expect(result.success, isTrue, reason: 'export failed: ${result.error}');
    expect(fake.jobs, hasLength(1));
    return fake.lastJob;
  } finally {
    useCase.dispose();
  }
}

void main() {
  late Directory tmp;
  late _CapturingFfmpeg fake;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipmind_export_args_');
    fake = _CapturingFfmpeg(tmp);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('single full-range clip', () {
    test('trims the full range, concats n=1, maps mp4 codecs', () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')]),
        fake,
      );
      final joined = _joined(job);

      expect(joined, contains('trim=start=0.0:end=60.0'));
      expect(joined, contains('setpts=PTS-STARTPTS'));
      expect(joined, contains('atrim=start=0.0:end=60.0'));
      expect(joined, contains('asetpts=PTS-STARTPTS'));
      expect(joined, contains('concat=n=1:v=1:a=1'));
      expect(job.args, containsAllInOrder(['-map', '[outv]', '-map', '[outa]']));
      expect(job.args, containsAllInOrder(['-c:v', 'libx264']));
      expect(job.args, containsAllInOrder(['-crf', '18']));
      expect(job.args, containsAllInOrder(['-pix_fmt', 'yuv420p']));
      expect(job.args, containsAllInOrder(['-c:a', 'aac']));
      expect(job.args, isNot(contains('-r')));
    });

    test('declares the single input', () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')]),
        fake,
      );
      expect(job.args.where((a) => a == '-i').length, equals(1));
      expect(job.args, containsAllInOrder(['-i', '/v/a.mp4']));
    });
  });

  group('per-clip ranges', () {
    test('mid-range clip times equal startMs/1000 and endMs/1000', () async {
      final job = await _export(
        _project([
          _clip('c1', '/v/a.mp4', startMs: 10500, endMs: 45250),
        ]),
        fake,
      );
      final joined = _joined(job);
      expect(joined, contains('trim=start=10.5:end=45.25'));
      expect(joined, contains('atrim=start=10.5:end=45.25'));
    });

    test('export-after-edit uses the POST-EDIT ranges (MEDIUM gap)', () async {
      // The ranged-cut/step-1 contract: `applyEdit` normalizes the
      // repointed clip from the additive `new_start_ms`/`new_end_ms`
      // params. The export must slice the NEW range, not the stale one.
      final notifier = ProjectNotifier()
        ..setProject(
          _project([_clip('c1', '/v/a.mp4', startMs: 0, endMs: 60000)]),
        );
      notifier.applyEdit(
        EditOperation(
          id: 'op_cut',
          type: EditOperationType.cut,
          targetClipIds: const ['c1'],
          params: const {
            'remove_start': '00:00:05.000',
            'remove_end': '00:00:15.000',
            'new_start_ms': 0,
            'new_end_ms': 50000,
          },
          createdAt: DateTime(2026, 1, 2),
        ),
        '/out/cut.mp4',
      );
      final updated = notifier.state.value!;
      expect(updated.tracks.single.clips.single.endMs, equals(50000));

      final job = await _export(updated, fake);
      final joined = _joined(job);
      expect(joined, contains('trim=start=0.0:end=50.0'));
      expect(joined, contains('atrim=start=0.0:end=50.0'));
      expect(joined, isNot(contains('end=60.0')));
    });
  });

  group('muted clips', () {
    test('muted clip maps silent audio with the clip duration', () async {
      final job = await _export(
        _project([
          _clip('c1', '/v/a.mp4', startMs: 0, endMs: 60000, muted: true),
        ]),
        fake,
      );
      final joined = _joined(job);
      expect(joined, contains('anullsrc=r=44100:d=60.0'));
      expect(joined, isNot(contains('atrim')));
      // Video still trims normally.
      expect(joined, contains('trim=start=0.0:end=60.0'));
    });
  });

  group('input dedup', () {
    test('repeated sourcePath yields one -i with both clips on index 0',
        () async {
      final job = await _export(
        _project([
          _clip('c1', '/v/a.mp4', startMs: 0, endMs: 10000),
          _clip('c2', '/v/a.mp4', startMs: 20000, endMs: 30000),
        ]),
        fake,
      );
      expect(job.args.where((a) => a == '-i').length, equals(1));
      final joined = _joined(job);
      expect(joined, contains('[0:v:0]trim=start=0.0:end=10.0'));
      expect(joined, contains('[0:v:0]trim=start=20.0:end=30.0'));
      expect(joined, contains('concat=n=2:v=1:a=1'));
    });

    test('two sources yield two -i entries with indices 0 and 1', () async {
      final job = await _export(
        _project([
          _clip('c1', '/v/a.mp4', startMs: 0, endMs: 10000),
          _clip('c2', '/v/b.mp4', startMs: 0, endMs: 5000),
        ]),
        fake,
      );
      expect(job.args, containsAllInOrder(['-i', '/v/a.mp4', '-i', '/v/b.mp4']));
      final joined = _joined(job);
      expect(joined, contains('[0:v:0]trim=start=0.0:end=10.0'));
      expect(joined, contains('[1:v:0]trim=start=0.0:end=5.0'));
    });
  });

  group('resolutions', () {
    test('source keeps the concat outputs mapped directly', () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')]),
        fake,
        options: _mp4.copyWith(resolution: 'source'),
      );
      final joined = _joined(job);
      expect(joined, isNot(contains('force_original_aspect_ratio')));
      expect(job.args, containsAllInOrder(['-map', '[outv]']));
      expect(job.args, containsAllInOrder(['-map', '[outa]']));
    });

    test('480p/720p/1080p/4K scale, pad, and map [finalv]', () async {
      const dims = {
        '480p': (854, 480),
        '720p': (1280, 720),
        '1080p': (1920, 1080),
        '4K': (3840, 2160),
      };
      for (final entry in dims.entries) {
        final localFake = _CapturingFfmpeg(tmp);
        final job = await _export(
          _project([_clip('c1', '/v/a.mp4')]),
          localFake,
          options: _mp4.copyWith(resolution: entry.key),
        );
        final (w, h) = entry.value;
        final joined = _joined(job);
        expect(
          joined,
          contains('scale=$w:$h:force_original_aspect_ratio=1'),
          reason: 'resolution ${entry.key}',
        );
        expect(
          joined,
          contains('pad=$w:$h:(ow-iw)/2:(oh-ih)/2'),
          reason: 'resolution ${entry.key}',
        );
        expect(job.args, containsAllInOrder(['-map', '[finalv]']));
        expect(job.args, containsAllInOrder(['-map', '[outa]']));
      }
    });
  });

  group('codec table', () {
    test('mov shares the mp4 libx264+aac mapping with crf', () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')]),
        fake,
        options: _mp4.copyWith(format: 'mov'),
      );
      expect(job.args, containsAllInOrder(['-c:v', 'libx264']));
      expect(job.args, containsAllInOrder(['-crf', '18']));
      expect(job.args, containsAllInOrder(['-c:a', 'aac']));
    });

    test('webm uses libvpx-vp9+libopus and no -crf', () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')]),
        fake,
        options: _mp4.copyWith(format: 'webm'),
      );
      expect(job.args, containsAllInOrder(['-c:v', 'libvpx-vp9']));
      expect(job.args, containsAllInOrder(['-c:a', 'libopus']));
      expect(job.args, isNot(contains('-crf')));
    });

    test('gif uses the gif codec with no audio, no pix_fmt, -r 10',
        () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')]),
        fake,
        options: _mp4.copyWith(format: 'gif'),
      );
      expect(job.args, containsAllInOrder(['-c:v', 'gif']));
      expect(job.args, isNot(contains('-c:a')));
      expect(job.args, isNot(contains('yuv420p')));
      expect(job.args, containsAllInOrder(['-r', '10']));
    });

    test('unknown format and resolution fall back to defaults', () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')]),
        fake,
        options: _mp4.copyWith(format: 'avi', resolution: '8K'),
      );
      // Default codecs (libx264 + aac, with crf).
      expect(job.args, containsAllInOrder(['-c:v', 'libx264']));
      expect(job.args, containsAllInOrder(['-c:a', 'aac']));
      // Default resolution dims (1920x1080) behind the scale/pad.
      final joined = _joined(job);
      expect(
        joined,
        contains('scale=1920:1080:force_original_aspect_ratio=1'),
      );
    });
  });

  group('degenerate branch', () {
    test('zero-length clip uses bare setpts/asetpts without trim', () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4', startMs: 0, endMs: 0)]),
        fake,
      );
      final joined = _joined(job);
      expect(joined, contains('[0:v:0]setpts=PTS-STARTPTS[c0v]'));
      expect(joined, contains('[0:a:0]asetpts=PTS-STARTPTS[c0a]'));
      expect(joined, isNot(contains('trim=')));
      expect(joined, contains('concat=n=1:v=1:a=1'));
    });
  });

  group('job envelope', () {
    test('expectedDurationMs follows the project duration', () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')], durationMs: 123456),
        fake,
      );
      expect(job.expectedDurationMs, equals(123456));
    });

    test('zero project duration falls back to 30000ms', () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')], durationMs: 0),
        fake,
      );
      expect(job.expectedDurationMs, equals(30000));
    });

    test('empty outputPath mints a temp path with the format suffix',
        () async {
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')]),
        fake,
        options: _mp4.copyWith(format: 'webm', outputPath: ''),
      );
      expect(fake.createTempPathCalls, equals(1));
      expect(job.outputPath, endsWith('.webm'));
      expect(job.outputPath, startsWith(tmp.path));
    });

    test('explicit outputPath is honored without minting a temp path',
        () async {
      final out = '${tmp.path}/final.mp4';
      final job = await _export(
        _project([_clip('c1', '/v/a.mp4')]),
        fake,
        options: _mp4.copyWith(outputPath: out),
      );
      expect(fake.createTempPathCalls, equals(0));
      expect(job.outputPath, equals(out));
    });
  });
}
