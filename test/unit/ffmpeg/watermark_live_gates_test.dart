import 'dart:io';

import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle 11 Phase 2: watermark composed-graph live gates (best effort).
///
/// Phase 1 fixed the `overlay_watermark` combo gap at the arg level (see
/// `composed_watermark_mapping_test.dart` — the composed graph gains the
/// extra `-i` inputs plus the pre-chained `[N:v]format=rgba,
/// `colorchannelmixer` opacity legs and the `[$prev][wmN]overlay=<pos>`
/// v-chain links). These gates prove the
/// fixed graphs PARSE and RENDER through REAL FFmpeg — driven through the
/// REAL composer path ([CommandMapper.mapOperations], the same entry the
/// manual/agent paths use), so the arg-level fix flows through.
///
/// Live-gate convention (see `combo_live_gates_test.dart`): resolve the
/// real binary via [FfmpegBinaryResolver], `markTestSkipped` when FFmpeg is
/// absent or lavfi synthesis fails, temp dirs under [Directory.systemTemp],
/// CRLF-safe assertions, no shell-outs beyond [Process.run].
const _clipSeconds = 5;

/// Synthesize a 5s 320x240 testsrc + sine clip (the `_synthAv` pattern).
/// True when ffmpeg exited 0 and the file exists.
Future<bool> _synthAv(String binary, String out, {required int freq}) async {
  final result = await Process.run(binary, [
    '-hide_banner', '-y',
    '-f', 'lavfi', '-i', 'testsrc=s=320x240:r=30:d=$_clipSeconds',
    '-f', 'lavfi', '-i', 'sine=frequency=$freq:duration=$_clipSeconds',
    '-shortest',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-ar', '44100',
    '-t', '$_clipSeconds',
    out,
  ]);
  return result.exitCode == 0 && File(out).existsSync();
}

/// Synthesize a 1-frame PNG watermark from a lavfi `color` source. True
/// when ffmpeg exited 0 and the file exists. A single still frame is safe
/// as an overlay input: framesync `eof_action` defaults to `repeat`, so the
/// still holds for the whole output.
Future<bool> _synthWatermark(String binary, String out) async {
  final result = await Process.run(binary, [
    '-hide_banner', '-y',
    '-f', 'lavfi', '-i', 'color=white@0.5:s=120x80,format=rgba',
    '-frames:v', '1',
    out,
  ]);
  return result.exitCode == 0 && File(out).existsSync();
}

/// Map [ops] through the REAL composer path; every combo here must compose
/// exactly ONE filter-graph job. [watermark] is passed as `projectDir` so
/// the mapper's lexical image-path validation accepts the synthesized PNG
/// (it lives inside the temp project dir).
FfmpegJob _mapSingleJob(
  String clip,
  String outDir,
  List<EditOperationRequest> ops,
) {
  final jobs = CommandMapper.mapOperations(
    EditOperationSet(operations: ops, summary: 'watermark-live-gate'),
    {'clip_1': clip, '_default': clip},
    outDir,
    projectDir: outDir,
  );
  expect(jobs, hasLength(1));
  return jobs.single;
}

/// Render [job] through real FFmpeg with delivery codecs appended (the
/// composer emits filter/map args only — no codecs, no output path).
/// `-c:a aac` is skipped for `-an` (muted) jobs.
Future<ProcessResult> _runJob(String binary, FfmpegJob job, String out) {
  final cmd = <String>['-hide_banner', '-y', ...job.args];
  cmd.addAll(['-c:v', 'libx264', '-pix_fmt', 'yuv420p']);
  if (!job.args.contains('-an')) cmd.addAll(['-c:a', 'aac']);
  cmd.add(out);
  return Process.run(binary, cmd);
}

void main() {
  group('watermark composed-graph live gates (best effort)', () {
    String? binary;
    late Directory tmp;
    late String clip;
    late String watermark;
    var ready = false;

    setUpAll(() async {
      binary = FfmpegBinaryResolver().resolveFfmpeg();
      if (binary == null) return;
      tmp = await Directory.systemTemp.createTemp('clipmind_watermark_live_');
      clip = '${tmp.path}/clip.mp4';
      watermark = '${tmp.path}/wm.png';
      final clipOk = await _synthAv(binary!, clip, freq: 440);
      final wmOk = await _synthWatermark(binary!, watermark);
      ready = clipOk && wmOk;
    });

    tearDownAll(() async {
      if (binary != null && ready) {
        await tmp.delete(recursive: true);
      }
    });

    /// Skip guard shared by every gate (the live-gate convention:
    /// `markTestSkipped` + early `return` — flutter_test's markTestSkipped
    /// marks the skip but does not terminate the test body).
    String? requireReady() {
      final resolved = binary;
      if (resolved == null) {
        markTestSkipped('ffmpeg not on PATH');
        return null;
      }
      if (!ready) {
        markTestSkipped('could not synthesize test clip or watermark');
        return null;
      }
      return resolved;
    }

    test(
      'live resize+watermark (defect-class A subject): graph parses + renders',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final resolved = requireReady();
        if (resolved == null) return;
        // Downscale target (same 4:3 aspect as the 320x240 synth clip):
        // the composer's `scale+crop` resize is shared verbatim with the
        // shipped single-op path, which likewise rejects upscaling a
        // smaller-aspect frame — so the live gate renders the downscale
        // direction.
        final job = _mapSingleJob(clip, tmp.path, [
          const EditOperationRequest(
            id: 'op_resize',
            type: 'resize',
            targetClipId: 'clip_1',
            params: {'width': 160, 'height': 120},
          ),
          EditOperationRequest(
            id: 'op_wm',
            type: 'overlay_watermark',
            targetClipId: 'clip_1',
            params: {'image_path': watermark},
          ),
        ]);
        // The Phase-1 fix flows through: the extra `-i` input, the
        // pre-chained opacity leg, and the overlay v-chain link — the
        // arg-level sanity re-asserted inside the gate so the live run
        // provably exercises the fixed graph.
        expect(job.args.sublist(0, 4), equals(['-i', clip, '-i', watermark]));
        final graph = job.args[job.args.indexOf('-filter_complex') + 1];
        expect(graph, contains('colorchannelmixer'));
        expect(graph, contains('overlay='));
        expect(
          graph,
          contains('[1:v]format=rgba,colorchannelmixer=aa=0.7[wm1]'),
        );
        expect(graph, contains('[v1][wm1]overlay=W-w-10:H-h-10[v2]'));
        expect(job.args, containsAll(['-map', '[v2]']));
        final out = '${tmp.path}/resize_watermark.mp4';
        final result = await _runJob(resolved, job, out);
        expect(
          result.exitCode,
          equals(0),
          reason: 'resize+watermark graph failed: ${result.stderr}',
        );
        expect(File(out).existsSync(), isTrue);
        // Outcome: the full 5s clip renders with the overlay (best effort).
        final meta = await FfprobeService().extractMetadata(out);
        if (meta != null) {
          expect(meta.durationMs, closeTo(5000, 500));
        }
      },
    );

    test(
      'live trim+watermark: overlay chains on the trim output',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final resolved = requireReady();
        if (resolved == null) return;
        final job = _mapSingleJob(clip, tmp.path, [
          const EditOperationRequest(
            id: 'op_trim',
            type: 'trim',
            targetClipId: 'clip_1',
            params: {'start': '1.0', 'end': '5.0'},
          ),
          EditOperationRequest(
            id: 'op_wm',
            type: 'overlay_watermark',
            targetClipId: 'clip_1',
            params: {'image_path': watermark},
          ),
        ]);
        final graph = job.args[job.args.indexOf('-filter_complex') + 1];
        expect(graph, contains('trim=1.0:5.0'));
        expect(graph, contains('colorchannelmixer'));
        expect(graph, contains('[v1][wm1]overlay=W-w-10:H-h-10[v2]'));
        expect(job.args, containsAll(['-map', '[v2]']));
        final out = '${tmp.path}/trim_watermark.mp4';
        final result = await _runJob(resolved, job, out);
        expect(
          result.exitCode,
          equals(0),
          reason: 'trim+watermark graph failed: ${result.stderr}',
        );
        expect(File(out).existsSync(), isTrue);
        // Outcome: trim keeps [1.0, 5.0] = 4.0s under the overlay
        // (best effort).
        final meta = await FfprobeService().extractMetadata(out);
        if (meta != null) {
          expect(meta.durationMs, closeTo(4000, 500));
        }
      },
    );

    test(
      'live watermark positions: default bottom-right + top-left render',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final resolved = requireReady();
        if (resolved == null) return;
        // Both stay on the composed path (resize+watermark) so each live
        // run provably exercises the fixed graph, not the single-op path.
        final defaultJob = _mapSingleJob(clip, tmp.path, [
          const EditOperationRequest(
            id: 'op_resize',
            type: 'resize',
            targetClipId: 'clip_1',
            params: {'width': 160, 'height': 120},
          ),
          EditOperationRequest(
            id: 'op_wm',
            type: 'overlay_watermark',
            targetClipId: 'clip_1',
            params: {'image_path': watermark},
          ),
        ]);
        final defaultGraph =
            defaultJob.args[defaultJob.args.indexOf('-filter_complex') + 1];
        expect(
          defaultGraph,
          contains('[v1][wm1]overlay=W-w-10:H-h-10[v2]'),
        );
        final defaultOut = '${tmp.path}/wm_default.mp4';
        final defaultResult = await _runJob(resolved, defaultJob, defaultOut);
        expect(
          defaultResult.exitCode,
          equals(0),
          reason: 'default-position graph failed: ${defaultResult.stderr}',
        );
        expect(File(defaultOut).existsSync(), isTrue);

        final namedJob = _mapSingleJob(clip, tmp.path, [
          const EditOperationRequest(
            id: 'op_resize',
            type: 'resize',
            targetClipId: 'clip_1',
            params: {'width': 160, 'height': 120},
          ),
          EditOperationRequest(
            id: 'op_wm',
            type: 'overlay_watermark',
            targetClipId: 'clip_1',
            params: {'image_path': watermark, 'position': 'top-left'},
          ),
        ]);
        final namedGraph =
            namedJob.args[namedJob.args.indexOf('-filter_complex') + 1];
        expect(namedGraph, contains('[v1][wm1]overlay=10:10[v2]'));
        final namedOut = '${tmp.path}/wm_top_left.mp4';
        final namedResult = await _runJob(resolved, namedJob, namedOut);
        expect(
          namedResult.exitCode,
          equals(0),
          reason: 'top-left-position graph failed: ${namedResult.stderr}',
        );
        expect(File(namedOut).existsSync(), isTrue);
      },
    );

    test(
      'live watermark opacity 0.5: alpha leg parses + renders',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final resolved = requireReady();
        if (resolved == null) return;
        final job = _mapSingleJob(clip, tmp.path, [
          const EditOperationRequest(
            id: 'op_resize',
            type: 'resize',
            targetClipId: 'clip_1',
            params: {'width': 160, 'height': 120},
          ),
          EditOperationRequest(
            id: 'op_wm',
            type: 'overlay_watermark',
            targetClipId: 'clip_1',
            params: {'image_path': watermark, 'opacity': 0.5},
          ),
        ]);
        final graph = job.args[job.args.indexOf('-filter_complex') + 1];
        expect(
          graph,
          contains('[1:v]format=rgba,colorchannelmixer=aa=0.5[wm1]'),
        );
        expect(graph, contains('overlay='));
        final out = '${tmp.path}/wm_opacity.mp4';
        final result = await _runJob(resolved, job, out);
        expect(
          result.exitCode,
          equals(0),
          reason: 'opacity-0.5 graph failed: ${result.stderr}',
        );
        expect(File(out).existsSync(), isTrue);
      },
    );
  });
}
