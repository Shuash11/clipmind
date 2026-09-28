import 'dart:io';

import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/scene_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoFfmpeg extends FfmpegBinaryResolver {
  @override
  String? resolveFfmpeg({String? settingsPath}) => null;
}

/// Deterministic binary for fake-runner tests: the injected `runProcess`
/// never executes it, but the service resolves the binary first — without
/// this stub the tests would depend on FFmpeg being installed (green
/// locally, red in CI).
class _FakeResolver extends FfmpegBinaryResolver {
  @override
  String? resolveFfmpeg({String? settingsPath}) => '/fake/ffmpeg';
}

/// Realistic stderr fragment: FFmpeg 8.1.1 `showinfo` lines for a red→blue
/// hard cut at t=1s (verified manually against the bundled-style build).
const _stderrTwoScenes =
    '[Parsed_showinfo_1 @ 0000019d0e5f4d40] n:   0 pts:  15360 pts_time:1       duration:    512 duration_time:0.0333333 \n'
    'fmt:yuv420p cl:left sar:1/1 s:320x240 i:P iskey:1 type:I checksum:7EEB9ECA plane_checksum:[699A0ED0 B1DB541A F17B3BE0] \n'
    'mean:[41 240 110] stdev:[0.0 0.0 0.0]\n'
    '[Parsed_showinfo_1 @ 0000019d0e5f4d40] n:   1 pts:  15872 pts_time:1.03333       duration:    512 duration_time:0.0333333 \n';

void main() {
  group('parseSceneTimestampsMs', () {
    test('extracts ordered ms timestamps from showinfo stderr', () {
      expect(
        SceneDetectionService.parseSceneTimestampsMs(_stderrTwoScenes),
        equals([1000, 1033]),
      );
    });

    test('empty stderr yields no scenes', () {
      expect(SceneDetectionService.parseSceneTimestampsMs(''), isEmpty);
      expect(
        SceneDetectionService.parseSceneTimestampsMs(
          'frame=  100 fps=30 q=-0.0 Lsize=N/A time=00:00:03.33\n',
        ),
        isEmpty,
      );
    });

    test('unrelated numbers (durations, checksums) are ignored', () {
      expect(
        SceneDetectionService.parseSceneTimestampsMs(
          'duration: 512 duration_time:0.0333333 checksum:7EEB9ECA\n',
        ),
        isEmpty,
      );
    });
  });

  group('detectScenes', () {
    late Directory tmp;
    late String video;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_scenes_');
      video = '${tmp.path}/clip.mp4';
      await File(video).writeAsString('fake');
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('runs select+showinfo to null and caps at maxScenes', () async {
      var runs = 0;
      final service = SceneDetectionService(
        resolver: _FakeResolver(),
        runProcess: (exe, args) async {
          runs++;
          expect(
            args.join(' '),
            contains("select='gt(scene,0.3)',showinfo"),
          );
          expect(args, contains('null'));
          final lines = List.generate(
            60,
            (i) => 'n: $i pts: $i pts_time:${i * 0.5}',
          );
          return ProcessResult(0, 0, '', '${lines.join('\n')}\n');
        },
      );

      final result = await service.detectScenes(video, maxScenes: 50);
      expect(runs, equals(1));
      expect(result, isNotNull);
      expect(result!.count, equals(50));
      expect(result.truncated, isTrue);
      expect(result.scenesMs.first, equals(0));
      expect(result.scenesMs.last, equals(24500));
    });

    test('non-zero exit yields null', () async {
      final service = SceneDetectionService(
        resolver: _FakeResolver(),
        runProcess: (_, _) async => ProcessResult(0, 1, '', 'boom'),
      );
      expect(await service.detectScenes(video), isNull);
    });

    test('missing binary yields null', () async {
      final service = SceneDetectionService(
        resolver: _NoFfmpeg(),
        runProcess: (_, _) async {
          fail('must not run without a binary');
        },
      );
      expect(await service.detectScenes(video), isNull);
    });

    test('missing file yields null without running', () async {
      var runs = 0;
      final service = SceneDetectionService(
        resolver: _FakeResolver(),
        runProcess: (_, _) async {
          runs++;
          return ProcessResult(0, 0, '', '');
        },
      );
      expect(await service.detectScenes('${tmp.path}/ghost.mp4'), isNull);
      expect(runs, equals(0));
    });

    test('live ffmpeg smoke: hard cut is detected (best effort)', () async {
      final binary = FfmpegBinaryResolver().resolveFfmpeg();
      if (binary == null) {
        markTestSkipped('ffmpeg not on PATH');
        return;
      }
      final red = '${tmp.path}/red.mp4';
      final blue = '${tmp.path}/blue.mp4';
      final cut = '${tmp.path}/cut.mp4';
      for (final spec in [(red, 'red'), (blue, 'blue')]) {
        final made = await Process.run(binary, [
          '-hide_banner', '-y',
          '-f', 'lavfi',
          '-i', 'color=c=${spec.$2}:s=160x120:r=30:d=1',
          '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
          spec.$1,
        ]);
        if (made.exitCode != 0) {
          markTestSkipped('could not synthesize test video');
          return;
        }
      }
      final concat = await Process.run(binary, [
        '-hide_banner', '-y',
        '-i', red, '-i', blue,
        '-filter_complex', '[0:v][1:v]concat=n=2:v=1:a=0',
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        cut,
      ]);
      if (concat.exitCode != 0) {
        markTestSkipped('could not concat test video');
        return;
      }
      final result = await SceneDetectionService().detectScenes(cut);
      expect(result, isNotNull);
      expect(result!.scenesMs, isNotEmpty);
      // The cut lands at t=1s; allow small encoder tolerance.
      expect(
        result.scenesMs.any((ms) => (ms - 1000).abs() < 150),
        isTrue,
        reason: 'expected a scene near 1000ms, got ${result.scenesMs}',
      );
    });
  });
}
