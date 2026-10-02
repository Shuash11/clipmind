import 'dart:io';

import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle 8 Phase 2 Step 4: transition-preset live gates (best effort).
///
/// Each of the 8 panel preset names (see `transition_presets.dart`) runs
/// through REAL FFmpeg via [CommandBuilder.transition] — the panel presets
/// are pinned empirically. The `supportedTransitions` vocabulary is the
/// app's authoritative contract; this gate pins each preset name exit-0.
///
/// Live-gate convention (see `export_live_gates_test.dart`): resolve the
/// real binary via [FfmpegBinaryResolver], `markTestSkipped` when FFmpeg is
/// absent or lavfi synthesis fails, temp dirs under [Directory.systemTemp],
/// CRLF-safe assertions, no shell-outs beyond [Process.run].
const _presetNames = [
  'fade',
  'dissolve',
  'wipeleft',
  'wiperight',
  'slideup',
  'slidedown',
  'circleopen',
  'fadeblack',
];

/// Synthesize a 2s 320x240 testsrc + sine clip (the `_synthAv` pattern).
/// True when ffmpeg exited 0 and the file exists.
Future<bool> _synthAv(String binary, String out, {required int freq}) async {
  final result = await Process.run(binary, [
    '-hide_banner', '-y',
    '-f', 'lavfi', '-i', 'testsrc=s=320x240:r=30:d=2',
    '-f', 'lavfi', '-i', 'sine=frequency=$freq:duration=2',
    '-shortest',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-ar', '44100',
    '-t', '2',
    out,
  ]);
  return result.exitCode == 0 && File(out).existsSync();
}

void main() {
  group('transition preset live gates (best effort)', () {
    String? binary;
    late Directory tmp;
    late String first;
    late String second;
    var ready = false;

    setUpAll(() async {
      binary = FfmpegBinaryResolver().resolveFfmpeg();
      if (binary == null) return;
      tmp = await Directory.systemTemp.createTemp(
        'clipmind_transition_live_',
      );
      first = '${tmp.path}/first.mp4';
      second = '${tmp.path}/second.mp4';
      ready =
          await _synthAv(binary!, first, freq: 440) &&
          await _synthAv(binary!, second, freq: 880);
    });

    tearDownAll(() async {
      if (binary != null && ready) {
        await tmp.delete(recursive: true);
      }
    });

    for (final name in _presetNames) {
      test(
        'live xfade preset "$name": real FFmpeg exit 0',
        timeout: const Timeout(Duration(minutes: 2)),
        () async {
          final resolved = binary;
          if (resolved == null) {
            markTestSkipped('ffmpeg not on PATH');
            return;
          }
          if (!ready) {
            markTestSkipped('could not synthesize test clips');
            return;
          }
          final args = CommandBuilder.transition(
            first,
            second,
            transition: name,
            duration: 0.5,
            offset: 1.0,
          );
          expect(args.join(' '), contains('xfade=transition=$name'));
          final out = '${tmp.path}/$name.mp4';
          final result = await Process.run(resolved, [
            '-hide_banner', '-y',
            ...args,
            '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
            '-c:a', 'aac',
            out,
          ]);
          expect(
            result.exitCode,
            equals(0),
            reason: 'xfade "$name" failed: ${result.stderr}',
          );
          expect(File(out).existsSync(), isTrue);
        },
      );
    }
  });
}
