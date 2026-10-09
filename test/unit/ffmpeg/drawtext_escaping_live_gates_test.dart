import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/filter_escaping.dart';
import 'package:clipmind/data/services/ffmpeg/filter_graph_composer.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle 14 Phase 1: live gates for the two-level `escapeFontFilePath`.
///
/// Reproduces the user-report shape ("No option name near '/Users/...'",
/// exit -22) with a worst-case font path on real Windows: drive colon,
/// space, brackets, comma, apostrophe and semicolon in a directory name.
/// Every gate builds its FFmpeg arguments through real app code
/// ([CommandBuilder], [CommandMapper], [FilterGraphComposer]) — never
/// hand-built filter strings — and runs the app's runtime binary resolved
/// by [FfmpegBinaryResolver].
///
/// Only an absent binary skips ([markTestSkipped]); everything else
/// asserts, so a broken gate can never pass silently.
///
/// Live-verified 2026-10-09 on FFmpeg 8.1.1-essentials: all three gates
/// exit 0 and render visible text (center-band mean luminance > 1).
const _frameW = 320;
const _frameH = 240;

/// Bundled font copied into a worst-case directory name.
const _fontAsset = 'assets/fonts/inter_regular.ttf';
const _specialDirName = "clipmind font [gate],o'brien;v1";

/// Cycle 14 Phase 2 §3 content cases: the app-composed text option must
/// match a `textfile=` reference frame-for-frame on all of these.
/// `50% off` specifically locks the silent-blank expansion regression.
const _contentCases = <String>[
  "it's",
  '50% off',
  'a:b',
  '[x],v;2',
  r'back\slash',
  '  pad  ',
  'a b c',
  "O'Brien [50%], v2",
  'line1\nline2',
];

/// Synthesize a 0.2s 320x240 black clip. Fails the test on error because
/// only an absent binary may skip.
Future<void> _synthDark(String binary, String out) async {
  final result = await Process.run(binary, [
    '-hide_banner', '-y',
    '-f', 'lavfi', '-i', 'color=c=black:s=320x240:r=30:d=0.2',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
    out,
  ]);
  expect(
    result.exitCode,
    equals(0),
    reason: 'synth failed: ${result.stderr}',
  );
  expect(File(out).existsSync(), isTrue, reason: 'synth produced no file');
}

/// Run ffmpeg with [args] to `-f framemd5 -` and return the comma-joined
/// per-frame MD5 list. The blank baseline is always computed in-test
/// (never hardcoded), so frame-count or build drift cannot fake a pass.
Future<String> _framemd5(String binary, List<String> args) async {
  final result = await Process.run(binary, [
    '-hide_banner',
    ...args,
    '-f', 'framemd5', '-',
  ]);
  expect(
    result.exitCode,
    equals(0),
    reason: 'framemd5 failed: ${result.stderr}',
  );
  final lines = (result.stdout as String)
      .split('\n')
      .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
      .toList();
  expect(lines, isNotEmpty, reason: 'framemd5 produced no frame hashes');
  return lines.map((l) => l.split(',').last.trim()).join(',');
}

/// Copy the bundled font into [tmp] under the worst-case directory name and
/// return the full path (drive colon + space + brackets + comma + apostrophe
/// + semicolon — the app's real Windows extraction-path shape).
String _copyFontIntoSpecialDir(Directory tmp) {
  final dir = Directory('${tmp.path}/$_specialDirName');
  dir.createSync(recursive: true);
  final dest = '${dir.path}/inter_regular.ttf';
  File(_fontAsset).copySync(dest);
  return dest;
}

/// Decode a PNG frame to RGB24 bytes; null when any step fails.
Future<Uint8List?> _pngRgb(
  String binary,
  Directory tmp,
  String tag,
  String png,
) async {
  final raw = '${tmp.path}/$tag.rgb';
  final dump = await Process.run(binary, [
    '-hide_banner', '-y',
    '-i', png,
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

/// Center-band mean luminance of a decoded RGB frame (rows 30%-70%).
double _centerBandMean(Uint8List rgb) =>
    _stripMean(rgb, (_frameH * 0.3).round(), (_frameH * 0.7).round());

/// Run [args] to a one-frame PNG, then return the center-band mean
/// luminance. Asserts at every step so a broken gate fails loudly.
Future<double> _centerBandMeanFromPng(
  String binary,
  Directory tmp,
  String tag,
  List<String> args,
) async {
  final png = '${tmp.path}/$tag.png';
  final run = await Process.run(binary, [...args, '-frames:v', '1', png]);
  expect(run.exitCode, equals(0), reason: '$tag failed: ${run.stderr}');
  expect(File(png).existsSync(), isTrue, reason: '$tag produced no file');
  final rgb = await _pngRgb(binary, tmp, tag, png);
  expect(rgb, isNotNull, reason: '$tag frame decode failed');
  final mean = _centerBandMean(rgb!);
  // ignore: avoid_print
  print('$tag center-band mean luminance = $mean');
  return mean;
}

/// First-frame center-band mean luminance of an app-rendered video.
Future<double> _centerBandMeanFromVideo(
  String binary,
  Directory tmp,
  String tag,
  String video,
) async {
  final png = '${tmp.path}/$tag.png';
  final extract = await Process.run(binary, [
    '-hide_banner', '-y',
    '-i', video,
    '-vframes', '1',
    png,
  ]);
  expect(
    extract.exitCode,
    equals(0),
    reason: '$tag frame extract failed: ${extract.stderr}',
  );
  expect(File(png).existsSync(), isTrue);
  final rgb = await _pngRgb(binary, tmp, tag, png);
  expect(rgb, isNotNull, reason: '$tag frame decode failed');
  final mean = _centerBandMean(rgb!);
  // ignore: avoid_print
  print('$tag center-band mean luminance = $mean');
  return mean;
}

void main() {
  group('drawtext fontfile escaping live gates (best effort)', () {
    test(
      'gate A: CommandBuilder.overlayText with worst-case font path',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final binary = FfmpegBinaryResolver().resolveFfmpeg();
        if (binary == null) {
          markTestSkipped('ffmpeg not on PATH');
          return;
        }
        final tmp = await Directory.systemTemp.createTemp('clipmind_font_a_');
        try {
          final input = '${tmp.path}/in.mp4';
          await _synthDark(binary, input);
          final font = _copyFontIntoSpecialDir(tmp);
          expect(font, contains(_specialDirName));
          final args = CommandBuilder.overlayText(
            input,
            text: 'Hello',
            position: 'center',
            start: '0',
            end: '0',
            fontSize: 72,
            color: '#FFFFFF',
            fontFile: font,
          );
          final mean = await _centerBandMeanFromPng(binary, tmp, 'gate_a', args);
          expect(mean, greaterThan(1), reason: 'text did not render');
        } finally {
          await tmp.delete(recursive: true);
        }
      },
    );

    test(
      'gate B: CommandMapper overlay_text with worst-case font path',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final binary = FfmpegBinaryResolver().resolveFfmpeg();
        if (binary == null) {
          markTestSkipped('ffmpeg not on PATH');
          return;
        }
        final tmp = await Directory.systemTemp.createTemp('clipmind_font_b_');
        try {
          final input = '${tmp.path}/in.mp4';
          await _synthDark(binary, input);
          final font = _copyFontIntoSpecialDir(tmp);
          final jobs = CommandMapper.mapOperations(
            EditOperationSet(
              operations: [
                EditOperationRequest(
                  id: 'op_b',
                  type: 'overlay_text',
                  targetClipId: 'c1',
                  params: {
                    'text': 'AgentText',
                    'font_size': 72,
                    'font_file': font,
                  },
                ),
              ],
              summary: 'live gate B',
            ),
            {'c1': input},
            tmp.path,
          );
          expect(jobs, hasLength(1));
          final job = jobs.first;
          final run = await Process.run(binary, [...job.args, job.outputPath]);
          expect(
            run.exitCode,
            equals(0),
            reason: 'gate B failed: ${run.stderr}',
          );
          expect(File(job.outputPath).existsSync(), isTrue);
          final mean = await _centerBandMeanFromVideo(
            binary,
            tmp,
            'gate_b',
            job.outputPath,
          );
          expect(mean, greaterThan(1), reason: 'text did not render');
        } finally {
          await tmp.delete(recursive: true);
        }
      },
    );

    test(
      'gate C: FilterGraphComposer with worst-case font path',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final binary = FfmpegBinaryResolver().resolveFfmpeg();
        if (binary == null) {
          markTestSkipped('ffmpeg not on PATH');
          return;
        }
        final tmp = await Directory.systemTemp.createTemp('clipmind_font_c_');
        try {
          final input = '${tmp.path}/in.mp4';
          await _synthDark(binary, input);
          final font = _copyFontIntoSpecialDir(tmp);
          final out = '${tmp.path}/composed.mp4';
          final jobs = FilterGraphComposer().compose(
            [
              EditOperation(
                id: 'op_c',
                type: EditOperationType.overlayText,
                targetClipIds: const ['c1'],
                params: {
                  'text': 'ComposeText',
                  'font_size': 72,
                  'font_file': font,
                },
                createdAt: DateTime(2026, 10, 9),
              ),
            ],
            input,
            out,
          );
          expect(jobs, hasLength(1));
          final job = jobs.first;
          final run = await Process.run(binary, [...job.args, job.outputPath]);
          expect(
            run.exitCode,
            equals(0),
            reason: 'gate C failed: ${run.stderr}',
          );
          expect(File(job.outputPath).existsSync(), isTrue);
          final mean = await _centerBandMeanFromVideo(
            binary,
            tmp,
            'gate_c',
            job.outputPath,
          );
          expect(mean, greaterThan(1), reason: 'text did not render');
        } finally {
          await tmp.delete(recursive: true);
        }
      },
    );

    test(
      'content hash: app-composed text == textfile reference, never blank',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final binary = FfmpegBinaryResolver().resolveFfmpeg();
        if (binary == null) {
          markTestSkipped('ffmpeg not on PATH');
          return;
        }
        final tmp = await Directory.systemTemp.createTemp(
          'clipmind_text_hash_',
        );
        try {
          final input = '${tmp.path}/in.mp4';
          await _synthDark(binary, input);
          final font = _copyFontIntoSpecialDir(tmp);
          final escapedFont = FilterEscaping.escapeFontFilePath(font);
          // Blank baseline: the same input with no filter (computed here,
          // never hardcoded).
          final blank = await _framemd5(binary, ['-i', input]);
          // ignore: avoid_print
          print('blank(no filter) hash=$blank');

          for (var i = 0; i < _contentCases.length; i++) {
            final text = _contentCases[i];
            final refPath = '${tmp.path}/$_specialDirName/ref_$i.txt';
            // UTF-8, no BOM, no trailing newline — the exact text value.
            File(refPath).writeAsStringSync(text);
            final refFilter =
                'drawtext=textfile=${FilterEscaping.escapeFontFilePath(refPath)}:'
                'fontsize=72:fontcolor=#FFFFFF:x=(w-text_w)/2:y=(h-text_h)/2:'
                'expansion=none:fontfile=$escapedFont';
            final refHash = await _framemd5(binary, [
              '-i', input,
              '-vf', refFilter,
            ]);
            // Real app code builds the filter under test.
            final appHash = await _framemd5(binary, [
              ...CommandBuilder.overlayText(
                input,
                text: text,
                position: 'center',
                start: '0',
                end: '0',
                fontSize: 72,
                color: '#FFFFFF',
                fontFile: font,
              ),
            ]);
            // ignore: avoid_print
            print(
              'case[$i] text=${jsonEncode(text)} '
              'frames=${appHash.split(',').length}\n'
              '  app=$appHash\n'
              '  ref=$refHash',
            );
            expect(
              appHash,
              equals(refHash),
              reason:
                  'case[$i] app-composed text differs from textfile reference',
            );
            expect(
              appHash,
              isNot(equals(blank)),
              reason: 'case[$i] rendered a blank frame',
            );
          }
        } finally {
          await tmp.delete(recursive: true);
        }
      },
    );
  });
}
