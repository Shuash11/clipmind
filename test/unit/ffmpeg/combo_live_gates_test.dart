import 'dart:io';

import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle 10 Phase 2: composed filter-graph combo live gates (best effort).
///
/// Phase 1 fixed the composed audio-integrity defects at the arg level
/// (see `command_mapper_restriction_test.dart` — defect A: the video-chain
/// break via audio-only ops; defect B: the map-label assumption; defect C:
/// the silently dropped intermediate audio filters). These gates prove the
/// fixed graphs PARSE and RENDER through REAL FFmpeg for the shipped,
/// reachable combos — driven through the REAL composer path
/// ([CommandMapper.mapOperations], the same entry the manual/agent paths
/// use), so the arg-level fix flows through.
///
/// Live-gate convention (see `export_live_gates_test.dart`): resolve the
/// real binary via [FfmpegBinaryResolver], `markTestSkipped` when FFmpeg is
/// absent or lavfi synthesis fails, temp dirs under [Directory.systemTemp],
/// CRLF-safe assertions, no shell-outs beyond [Process.run].
///
/// Live-verified 2026-10-03 on FFmpeg 8.1.1-essentials (gyan.dev).
const _clipSeconds = 5;

/// Synthesize a 5s 320x240 testsrc + sine clip (the `_synthAv` pattern).
/// 5s so the trim combos can keep `[1.0, 5.0]`. True when ffmpeg exited 0
/// and the file exists.
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

/// Map [ops] through the REAL composer path; every combo here must compose
/// exactly ONE filter-graph job.
FfmpegJob _mapSingleJob(String clip, String outDir, List<EditOperationRequest> ops) {
  final jobs = CommandMapper.mapOperations(
    EditOperationSet(operations: ops, summary: 'combo-live-gate'),
    {'clip_1': clip, '_default': clip},
    outDir,
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
  group('composed filter-graph combo live gates (best effort)', () {
    String? binary;
    late Directory tmp;
    late String clip;
    var ready = false;

    setUpAll(() async {
      binary = FfmpegBinaryResolver().resolveFfmpeg();
      if (binary == null) return;
      tmp = await Directory.systemTemp.createTemp('clipmind_combo_live_');
      clip = '${tmp.path}/clip.mp4';
      ready = await _synthAv(binary!, clip, freq: 440);
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
        markTestSkipped('could not synthesize test clip');
        return null;
      }
      return resolved;
    }

    test(
      'live volume+speed (Adjustments combo): graph parses + renders',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final resolved = requireReady();
        if (resolved == null) return;
        final job = _mapSingleJob(clip, tmp.path, const [
          EditOperationRequest(
            id: 'op_vol',
            type: 'change_volume',
            targetClipId: 'clip_1',
            params: {'factor': 0.5},
          ),
          EditOperationRequest(
            id: 'op_speed',
            type: 'change_speed',
            targetClipId: 'clip_1',
            params: {'factor': 2.0},
          ),
        ]);
        // The Phase-1 defect-A fix flows through: chained audio segment,
        // video passthrough for the audio-only op, `[aout]` map.
        final graph = job.args[job.args.indexOf('-filter_complex') + 1];
        expect(graph, contains('[0:a]volume=0.5,atempo=2.0[aout]'));
        expect(graph, contains('[v0]null[v1]'));
        expect(job.args, containsAll(['-map', '[aout]']));
        final out = '${tmp.path}/volume_speed.mp4';
        final result = await _runJob(resolved, job, out);
        expect(
          result.exitCode,
          equals(0),
          reason: 'volume+speed graph failed: ${result.stderr}',
        );
        expect(File(out).existsSync(), isTrue);
        // Outcome: 5s at 2x ≈ 2.5s — A/V stay in sync (best effort).
        final meta = await FfprobeService().extractMetadata(out);
        if (meta != null) {
          expect(meta.durationMs, closeTo(2500, 500));
        }
      },
    );

    test(
      'live brightness+volume+speed: all fragments render',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final resolved = requireReady();
        if (resolved == null) return;
        final job = _mapSingleJob(clip, tmp.path, const [
          EditOperationRequest(
            id: 'op_bright',
            type: 'adjust_brightness',
            targetClipId: 'clip_1',
            params: {'value': 0.2},
          ),
          EditOperationRequest(
            id: 'op_vol',
            type: 'change_volume',
            targetClipId: 'clip_1',
            params: {'factor': 0.5},
          ),
          EditOperationRequest(
            id: 'op_speed',
            type: 'change_speed',
            targetClipId: 'clip_1',
            params: {'factor': 2.0},
          ),
        ]);
        final graph = job.args[job.args.indexOf('-filter_complex') + 1];
        expect(graph, contains('eq=brightness=0.2'));
        expect(graph, contains('[0:a]volume=0.5,atempo=2.0[aout]'));
        final out = '${tmp.path}/brightness_volume_speed.mp4';
        final result = await _runJob(resolved, job, out);
        expect(
          result.exitCode,
          equals(0),
          reason: 'brightness+volume+speed graph failed: ${result.stderr}',
        );
        expect(File(out).existsSync(), isTrue);
      },
    );

    test(
      'live trim+change_speed: atrim kept, duration re-timed (no desync)',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final resolved = requireReady();
        if (resolved == null) return;
        final job = _mapSingleJob(clip, tmp.path, const [
          EditOperationRequest(
            id: 'op_trim',
            type: 'trim',
            targetClipId: 'clip_1',
            params: {'start': '1.0', 'end': '5.0'},
          ),
          EditOperationRequest(
            id: 'op_speed',
            type: 'change_speed',
            targetClipId: 'clip_1',
            params: {'factor': 2.0},
          ),
        ]);
        // The Phase-1 defect-C fix flows through: the intermediate `atrim`
        // survives composition instead of being silently dropped.
        final graph = job.args[job.args.indexOf('-filter_complex') + 1];
        expect(
          graph,
          contains('[0:a]atrim=1.0:5.0,asetpts=PTS-STARTPTS,atempo=2.0[aout]'),
        );
        final out = '${tmp.path}/trim_speed.mp4';
        final result = await _runJob(resolved, job, out);
        expect(
          result.exitCode,
          equals(0),
          reason: 'trim+speed graph failed: ${result.stderr}',
        );
        expect(File(out).existsSync(), isTrue);
        // Outcome: trim keeps [1.0, 5.0] = 4.0s, 2x speed → ≈ 2.0s on
        // BOTH streams (best effort — proves no A/V desync).
        final meta = await FfprobeService().extractMetadata(out);
        if (meta != null) {
          expect(meta.durationMs, closeTo(2000, 500));
        }
      },
    );

    test(
      'live trim+resize (video-only last op): no undefined a-label',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final resolved = requireReady();
        if (resolved == null) return;
        // Downscale target (same 4:3 aspect as the 320x240 synth clip):
        // the composer's `scale+crop` resize is shared verbatim with the
        // shipped single-op path, which likewise rejects upscaling a
        // smaller-aspect frame (crop larger than the scaled frame) — so
        // the live gate renders the downscale direction. The defect-B
        // subject (chained `[aout]` + `-map [aout]` with a video-only
        // last op) is identical either way.
        final job = _mapSingleJob(clip, tmp.path, const [
          EditOperationRequest(
            id: 'op_trim',
            type: 'trim',
            targetClipId: 'clip_1',
            params: {'start': '1.0', 'end': '5.0'},
          ),
          EditOperationRequest(
            id: 'op_resize',
            type: 'resize',
            targetClipId: 'clip_1',
            params: {'width': 160, 'height': 120},
          ),
        ]);
        // The Phase-1 defect-B fix flows through: the audio side is the
        // chained `[aout]` (never `a{ops.length - 1}`).
        final graph = job.args[job.args.indexOf('-filter_complex') + 1];
        expect(
          graph,
          contains('[0:a]atrim=1.0:5.0,asetpts=PTS-STARTPTS[aout]'),
        );
        expect(job.args, containsAll(['-map', '[aout]']));
        final out = '${tmp.path}/trim_resize.mp4';
        final result = await _runJob(resolved, job, out);
        expect(
          result.exitCode,
          equals(0),
          reason: 'trim+resize graph failed: ${result.stderr}',
        );
        expect(File(out).existsSync(), isTrue);
      },
    );

    test(
      'live change_volume+resize (agent ordering): no undefined label',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final resolved = requireReady();
        if (resolved == null) return;
        // Downscale target — same rationale as the trim+resize gate above:
        // the live clip is 320x240, so the gate renders the downscale
        // direction the shipped resize supports.
        final job = _mapSingleJob(clip, tmp.path, const [
          EditOperationRequest(
            id: 'op_vol',
            type: 'change_volume',
            targetClipId: 'clip_1',
            params: {'factor': 0.5},
          ),
          EditOperationRequest(
            id: 'op_resize',
            type: 'resize',
            targetClipId: 'clip_1',
            params: {'width': 160, 'height': 120},
          ),
        ]);
        final graph = job.args[job.args.indexOf('-filter_complex') + 1];
        expect(graph, contains('[0:a]volume=0.5[aout]'));
        expect(job.args, containsAll(['-map', '[aout]']));
        final out = '${tmp.path}/volume_resize.mp4';
        final result = await _runJob(resolved, job, out);
        expect(
          result.exitCode,
          equals(0),
          reason: 'volume+resize graph failed: ${result.stderr}',
        );
        expect(File(out).existsSync(), isTrue);
      },
    );

    test(
      'live mute+video-op: chain intact, -an, renders silent',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final resolved = requireReady();
        if (resolved == null) return;
        final job = _mapSingleJob(clip, tmp.path, const [
          EditOperationRequest(
            id: 'op_mute',
            type: 'mute',
            targetClipId: 'clip_1',
            params: {},
          ),
          EditOperationRequest(
            id: 'op_bright',
            type: 'adjust_brightness',
            targetClipId: 'clip_1',
            params: {'value': 0.2},
          ),
        ]);
        final graph = job.args[job.args.indexOf('-filter_complex') + 1];
        expect(graph, contains('[v0]null[v1]'));
        expect(graph, contains('eq=brightness=0.2'));
        expect(job.args, contains('-an'));
        final out = '${tmp.path}/mute_brightness.mp4';
        final result = await _runJob(resolved, job, out);
        expect(
          result.exitCode,
          equals(0),
          reason: 'mute+brightness graph failed: ${result.stderr}',
        );
        expect(File(out).existsSync(), isTrue);
        // Outcome: the output carries no audio stream (best effort).
        final meta = await FfprobeService().extractMetadata(out);
        if (meta != null) {
          expect(meta.hasAudio, isFalse);
        }
      },
    );
  });
}
