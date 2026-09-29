import 'dart:io';

import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/procedural_sound_service.dart';
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

void main() {
  group('ProceduralSoundService.presets', () {
    test('exposes the 6 procedural presets', () {
      expect(
        ProceduralSoundService.presets.map((p) => p.id),
        equals([
          'beep',
          'drone-low',
          'drone-mid',
          'hum',
          'static-noise',
          'alert-chime',
        ]),
      );
      for (final preset in ProceduralSoundService.presets) {
        expect(preset.label, isNotEmpty);
        expect(preset.durationSeconds, greaterThan(0));
        expect(
          CommandBuilder.proceduralSoundSource(preset.id),
          isNotNull,
          reason: 'preset ${preset.id} has no lavfi mapping',
        );
      }
    });

    test('isKnownPreset matches the lavfi mapping', () {
      expect(ProceduralSoundService.isKnownPreset('beep'), isTrue);
      expect(ProceduralSoundService.isKnownPreset('alert-chime'), isTrue);
      expect(ProceduralSoundService.isKnownPreset('nope'), isFalse);
      expect(
        ProceduralSoundService.lavfiSourceFor('hum'),
        contains('frequency=60'),
      );
      expect(ProceduralSoundService.lavfiSourceFor('nope'), isNull);
    });
  });

  group('ProceduralSoundService.generate', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_sounds_');
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('runs lavfi to wav and returns the output path', () async {
      var runs = 0;
      final service = ProceduralSoundService(
        resolver: _FakeResolver(),
        runProcess: (exe, args) async {
          runs++;
          expect(exe, equals('/fake/ffmpeg'));
          expect(args.sublist(0, 3), equals(['-f', 'lavfi', '-i']));
          expect(args, contains('sine=frequency=880:duration=0.3'));
          expect(args, contains('pcm_s16le'));
          final out = args.last;
          await File(out).writeAsBytes([82, 73, 70, 70]);
          return ProcessResult(0, 0, '', '');
        },
      );

      final out = '${tmp.path}/beep.wav';
      expect(await service.generate('beep', outputPath: out), equals(out));
      expect(runs, equals(1));
    });

    test('unknown preset yields null without running', () async {
      var runs = 0;
      final service = ProceduralSoundService(
        resolver: _FakeResolver(),
        runProcess: (_, _) async {
          runs++;
          return ProcessResult(0, 0, '', '');
        },
      );
      expect(
        await service.generate('nope', outputPath: '${tmp.path}/x.wav'),
        isNull,
      );
      expect(runs, equals(0));
    });

    test('missing binary yields null', () async {
      final service = ProceduralSoundService(
        resolver: _NoFfmpeg(),
        runProcess: (_, _) async {
          fail('must not run without a binary');
        },
      );
      expect(
        await service.generate('beep', outputPath: '${tmp.path}/b.wav'),
        isNull,
      );
    });

    test('non-zero exit yields null', () async {
      final service = ProceduralSoundService(
        resolver: _FakeResolver(),
        runProcess: (_, _) async => ProcessResult(0, 1, '', 'boom'),
      );
      expect(
        await service.generate('hum', outputPath: '${tmp.path}/h.wav'),
        isNull,
      );
    });

    test('missing output file yields null', () async {
      final service = ProceduralSoundService(
        resolver: _FakeResolver(),
        runProcess: (_, _) async => ProcessResult(0, 0, '', ''),
      );
      expect(
        await service.generate(
          'drone-low',
          outputPath: '${tmp.path}/ghost.wav',
        ),
        isNull,
      );
    });
  });
}
