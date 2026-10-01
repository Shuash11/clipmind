import 'dart:io';
import 'dart:typed_data';

import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/export_options.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/usecases/export_project_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle 6 Phase 2 Step 3: FFmpeg-side live gates (best effort).
///
/// Each gate resolves the real binary via [FfmpegBinaryResolver] and calls
/// `markTestSkipped` when FFmpeg is absent or lavfi synthesis fails — the
/// `scene_detection_service_test.dart` live-smoke pattern. No shell-outs
/// beyond [Process.run]; temp dirs live under [Directory.systemTemp].
///
/// Live-verified 2026-10-01 on FFmpeg 8.1.1-essentials (gyan.dev,
/// `--enable-libass`):
/// - Gate 2 pins LEGACY `\a` semantics for the ASS Style `Alignment` field
///   (`force_style='Alignment=N'`): 6 = top-center, 2 = bottom-center.
///   Numpad 8 renders middle-center here — it belongs to `\an` override
///   tags, not the Style field.
/// - Gate 3 pins that `acrossfade` TOLERATES mismatched input sample rates
///   on this build (auto-resampled to the first input's rate) — exit 0.
/// - Gate 4 pins `gblur=sigma=20.0` (the app's full-strength blur) as
///   valid — exit 0.
const _frameW = 320;
const _frameH = 240;

/// Synthesize a 2s 320x240 testsrc + sine clip with [audioRate] Hz audio.
/// True when ffmpeg exited 0 and the file exists.
Future<bool> _synthAv(
  String binary,
  String out, {
  required int freq,
  required int audioRate,
}) async {
  final result = await Process.run(binary, [
    '-hide_banner', '-y',
    '-f', 'lavfi', '-i', 'testsrc=s=320x240:r=30:d=2',
    '-f', 'lavfi', '-i', 'sine=frequency=$freq:duration=2',
    '-shortest',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-ar', '$audioRate',
    '-t', '2',
    out,
  ]);
  return result.exitCode == 0 && File(out).existsSync();
}

/// Synthesize a 2s 320x240 black clip (caption-burn canvas).
Future<bool> _synthDark(String binary, String out) async {
  final result = await Process.run(binary, [
    '-hide_banner', '-y',
    '-f', 'lavfi', '-i', 'color=c=black:s=320x240:r=30:d=2',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
    out,
  ]);
  return result.exitCode == 0 && File(out).existsSync();
}

/// Decode one frame of [video] at [second]s to RGB24 bytes, or null when
/// any step fails (the caller treats luminance as best effort).
Future<Uint8List?> _frameRgb(
  String binary,
  Directory tmp,
  String tag,
  String video,
) async {
  final frame = '${tmp.path}/$tag.png';
  final raw = '${tmp.path}/$tag.rgb';
  final extract = await Process.run(binary, [
    '-hide_banner', '-y',
    '-ss', '1', '-i', video,
    '-vframes', '1',
    frame,
  ]);
  if (extract.exitCode != 0) return null;
  final dump = await Process.run(binary, [
    '-hide_banner', '-y',
    '-i', frame,
    '-f', 'rawvideo', '-pix_fmt', 'rgb24',
    raw,
  ]);
  if (dump.exitCode != 0) return null;
  final file = File(raw);
  if (!file.existsSync()) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length != _frameW * _frameH * 3) return null;
  return bytes;
}

/// Mean luminance (0-255) of rows [y0, y1).
double _stripMean(Uint8List rgb, int y0, int y1) {
  var sum = 0.0;
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = 0; x < _frameW; x++) {
      final o = (y * _frameW + x) * 3;
      sum += 0.299 * rgb[o] + 0.587 * rgb[o + 1] + 0.114 * rgb[o + 2];
      n++;
    }
  }
  return n == 0 ? 0 : sum / n;
}

void main() {
  group('export live gates (best effort)', () {
    test(
      'live export concat smoke: real use case on 2 lavfi clips',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final binary = FfmpegBinaryResolver().resolveFfmpeg();
        if (binary == null) {
          markTestSkipped('ffmpeg not on PATH');
          return;
        }
        final tmp = await Directory.systemTemp.createTemp(
          'clipmind_export_live_',
        );
        try {
          final a = '${tmp.path}/a.mp4';
          final b = '${tmp.path}/b.mp4';
          final out = '${tmp.path}/export.mp4';
          if (!await _synthAv(binary, a, freq: 440, audioRate: 44100) ||
              !await _synthAv(binary, b, freq: 880, audioRate: 44100)) {
            markTestSkipped('could not synthesize test clips');
            return;
          }
          final now = DateTime(2026, 10, 1);
          final project = Project(
            id: 'live',
            name: 'ExportLiveGate',
            createdAt: now,
            updatedAt: now,
            tracks: [
              Track(
                id: 't1',
                type: TrackType.video,
                clips: [
                  Clip(
                    id: 'c1',
                    trackId: 't1',
                    sourcePath: a,
                    startMs: 0,
                    endMs: 1500,
                  ),
                  Clip(
                    id: 'c2',
                    trackId: 't1',
                    sourcePath: b,
                    startMs: 0,
                    endMs: 1500,
                  ),
                ],
              ),
            ],
            durationMs: 3000,
          );
          final useCase = ExportProjectUseCase();
          final seen = <double>[];
          final sub = useCase.progressStream.listen(seen.add);
          try {
            final result = await useCase.execute(
              project,
              options: const ExportOptions(
                format: 'mp4',
                resolution: 'source',
                quality: 'high',
                crf: 23,
                outputPath: '',
              ).copyWith(outputPath: out),
            );
            await Future<void>.delayed(const Duration(milliseconds: 200));
            expect(
              result.success,
              isTrue,
              reason: 'export failed: ${result.error}',
            );
            expect(File(out).existsSync(), isTrue);
            expect(seen, contains(1.0), reason: 'seen=$seen');
            // Duration via ffprobe, best effort.
            final meta = await FfprobeService().extractMetadata(out);
            if (meta != null) {
              expect(meta.durationMs, greaterThan(0));
            }
          } finally {
            await sub.cancel();
            useCase.dispose();
          }
        } finally {
          await tmp.delete(recursive: true);
        }
      },
    );

    test(
      'live libass + ASS Alignment: legacy 6=top, 2=bottom',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final binary = FfmpegBinaryResolver().resolveFfmpeg();
        if (binary == null) {
          markTestSkipped('ffmpeg not on PATH');
          return;
        }
        final tmp = await Directory.systemTemp.createTemp(
          'clipmind_ass_live_',
        );
        try {
          final dark = '${tmp.path}/dark.mp4';
          if (!await _synthDark(binary, dark)) {
            markTestSkipped('could not synthesize dark clip');
            return;
          }
          final srt = '${tmp.path}/cap.srt';
          await File(srt).writeAsString(
            '1\n00:00:00,000 --> 00:00:02,000\nHELLO CAPTION\n',
          );
          // Pure-static filter strings (unit-callable, CRLF-safe).
          expect(
            CommandBuilder.burnCaptionsFilter(srt, alignment: 6),
            contains('Alignment=6'),
          );
          expect(
            CommandBuilder.burnCaptionsFilter(srt, alignment: 2),
            contains('Alignment=2'),
          );
          // libass presence: both burns must exit 0.
          final outTop = '${tmp.path}/top.mp4';
          final topRun = await Process.run(binary, [
            '-hide_banner', '-y',
            '-i', dark,
            '-vf', CommandBuilder.burnCaptionsFilter(srt, alignment: 6),
            '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
            outTop,
          ]);
          expect(
            topRun.exitCode,
            equals(0),
            reason: 'libass Alignment=6 burn failed: ${topRun.stderr}',
          );
          final outBottom = '${tmp.path}/bottom.mp4';
          final bottomRun = await Process.run(binary, [
            '-hide_banner', '-y',
            '-i', dark,
            '-vf', CommandBuilder.burnCaptionsFilter(srt, alignment: 2),
            '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
            outBottom,
          ]);
          expect(
            bottomRun.exitCode,
            equals(0),
            reason: 'libass Alignment=2 burn failed: ${bottomRun.stderr}',
          );
          // Positional smoke: the rendered text sits in the expected
          // third (best effort — skipped when no text is visible, e.g.
          // no usable font on the machine).
          final rgbTop = await _frameRgb(binary, tmp, 'top', outTop);
          final rgbBottom = await _frameRgb(binary, tmp, 'bot', outBottom);
          if (rgbTop == null || rgbBottom == null) {
            // ignore: avoid_print
            print('ASS luminance check skipped: frame decode failed');
            return;
          }
          final topStrip = (_frameH * 0.3).round();
          final bottomStart = (_frameH * 0.7).round();
          final topOnTop = _stripMean(rgbTop, 0, topStrip);
          final bottomOnTop = _stripMean(rgbTop, bottomStart, _frameH);
          final topOnBottom = _stripMean(rgbBottom, 0, topStrip);
          final bottomOnBottom = _stripMean(rgbBottom, bottomStart, _frameH);
          // ignore: avoid_print
          print(
            'ASS Alignment=6 top=$topOnTop bottom=$bottomOnTop; '
            'Alignment=2 top=$topOnBottom bottom=$bottomOnBottom',
          );
          final peak = [
            topOnTop,
            bottomOnTop,
            topOnBottom,
            bottomOnBottom,
          ].reduce((a, b) => a > b ? a : b);
          if (peak < 1.5) {
            // ignore: avoid_print
            print('ASS luminance check skipped: no visible text rendered');
            return;
          }
          expect(
            topOnTop,
            greaterThan(bottomOnTop),
            reason: 'Alignment=6 must render at the top',
          );
          expect(
            bottomOnBottom,
            greaterThan(topOnBottom),
            reason: 'Alignment=2 must render at the bottom',
          );
        } finally {
          await tmp.delete(recursive: true);
        }
      },
    );

    test(
      'live acrossfade: same-rate and mismatched-rate pairs exit 0',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final binary = FfmpegBinaryResolver().resolveFfmpeg();
        if (binary == null) {
          markTestSkipped('ffmpeg not on PATH');
          return;
        }
        final tmp = await Directory.systemTemp.createTemp(
          'clipmind_xfade_live_',
        );
        try {
          final m1 = '${tmp.path}/m1.mp4';
          final m2 = '${tmp.path}/m2.mp4';
          final m3 = '${tmp.path}/m3.mp4';
          if (!await _synthAv(binary, m1, freq: 440, audioRate: 44100) ||
              !await _synthAv(binary, m2, freq: 660, audioRate: 44100) ||
              !await _synthAv(binary, m3, freq: 440, audioRate: 48000)) {
            markTestSkipped('could not synthesize rate clips');
            return;
          }
          // Same-rate pair through the production builder.
          final args = CommandBuilder.transition(
            m1,
            m2,
            transition: 'fade',
            duration: 0.5,
            offset: 1.0,
          );
          expect(args.join(' '), contains('acrossfade'));
          final outSame = '${tmp.path}/same.mp4';
          final same = await Process.run(binary, [
            '-hide_banner', '-y',
            ...args,
            '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
            '-c:a', 'aac',
            outSame,
          ]);
          expect(
            same.exitCode,
            equals(0),
            reason: 'same-rate acrossfade failed: ${same.stderr}',
          );
          expect(File(outSame).existsSync(), isTrue);
          // Mismatched-rate pair (44100 vs 48000): FFmpeg 8.1.1
          // auto-resamples instead of failing the graph — pin exit 0.
          final outMixed = '${tmp.path}/mixed.mp4';
          final mixed = await Process.run(binary, [
            '-hide_banner', '-y',
            '-i', m1, '-i', m3,
            '-filter_complex',
            '[0:v][1:v]xfade=transition=fade:duration=0.5:offset=1.0[outv];'
                '[0:a][1:a]acrossfade=d=0.5[outa]',
            '-map', '[outv]', '-map', '[outa]',
            '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
            '-c:a', 'aac',
            outMixed,
          ]);
          expect(
            mixed.exitCode,
            equals(0),
            reason: 'mixed-rate acrossfade failed: ${mixed.stderr}',
          );
          expect(File(outMixed).existsSync(), isTrue);
          // Output follows the first input's rate (best effort).
          final meta = await FfprobeService().extractMetadata(outMixed);
          if (meta?.audioSampleRate != null) {
            expect(meta!.audioSampleRate, equals(44100));
          }
        } finally {
          await tmp.delete(recursive: true);
        }
      },
    );

    test(
      'live gblur sigma cap: full-strength blur renders',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final binary = FfmpegBinaryResolver().resolveFfmpeg();
        if (binary == null) {
          markTestSkipped('ffmpeg not on PATH');
          return;
        }
        // App cap: strength 1.0 -> sigma 20 (gblur documents no upper cap).
        final filter = CommandBuilder.effectFilter(
          effect: 'blur',
          strength: 1.0,
        );
        expect(filter, equals('gblur=sigma=20.0'));
        final tmp = await Directory.systemTemp.createTemp(
          'clipmind_blur_live_',
        );
        try {
          final out = '${tmp.path}/blur.mp4';
          final result = await Process.run(binary, [
            '-hide_banner', '-y',
            '-f', 'lavfi', '-i', 'testsrc=s=160x120:r=30:d=1',
            '-vf', filter,
            '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
            out,
          ]);
          expect(
            result.exitCode,
            equals(0),
            reason: 'gblur sigma=20 failed: ${result.stderr}',
          );
          expect(File(out).existsSync(), isTrue);
        } finally {
          await tmp.delete(recursive: true);
        }
      },
    );
  });
}
