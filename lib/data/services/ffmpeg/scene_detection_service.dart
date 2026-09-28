import 'dart:io';
import 'package:flutter/foundation.dart';

import 'ffmpeg_binary_resolver.dart';

/// One detected scene boundary: the timestamp (ms) of the first frame of a
/// new scene.
typedef SceneTimestampMs = int;

/// Result of an FFmpeg scene-detection run.
class SceneDetection {
  /// Ordered start timestamps (ms) of detected scenes.
  final List<int> scenesMs;

  /// Whether the run hit [SceneDetectionService.maxScenesDefault] cap.
  final bool truncated;

  const SceneDetection({required this.scenesMs, this.truncated = false});

  int get count => scenesMs.length;
}

/// Analysis-only scene detection via FFmpeg (Phase 6a).
///
/// Runs `-vf "select='gt(scene,T)',showinfo"` to null output and parses the
/// `pts_time:` values `showinfo` prints to **stderr** — the same
/// `Process.run` pattern as [FfprobeService]. No output file is produced.
///
/// Verified against FFmpeg 8.1.1: a synthetic red→blue hard cut at t=1s
/// yields one showinfo line with `pts_time:1` (value is unpadded, e.g.
/// `pts_time:1.023`). The `scene` score is the select filter's 0–1
/// scene-change metric; frames with `gt(scene,T)` pass.
/// Mirrors [FfprobeService]: resolver-injected, null on missing binary/file.
class SceneDetectionService {
  final FfmpegBinaryResolver _resolver;

  /// Process runner seam (defaults to [Process.run]) for unit tests.
  final Future<ProcessResult> Function(String exe, List<String> args) _run;

  static const double thresholdDefault = 0.3;
  static const int maxScenesDefault = 50;

  SceneDetectionService({
    FfmpegBinaryResolver? resolver,
    Future<ProcessResult> Function(String exe, List<String> args)? runProcess,
  }) : _resolver = resolver ?? FfmpegBinaryResolver(),
       _run = runProcess ?? Process.run;

  /// Detect scene boundaries in [videoPath].
  ///
  /// Returns null when FFmpeg is unavailable, the file is missing, or the
  /// run fails. Never throws.
  Future<SceneDetection?> detectScenes(
    String videoPath, {
    double threshold = thresholdDefault,
    int maxScenes = maxScenesDefault,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final binary = _resolver.resolveFfmpeg();
    if (binary == null) return null;
    if (!File(videoPath).existsSync()) return null;

    final t = threshold.clamp(0.0, 1.0);
    final cap = maxScenes.clamp(1, 500);
    try {
      final result = await _run(binary, [
        '-hide_banner',
        '-i',
        videoPath,
        '-vf',
        "select='gt(scene,$t)',showinfo",
        '-f',
        'null',
        '-',
      ]).timeout(timeout);
      if (result.exitCode != 0) return null;
      final stderr = result.stderr is String ? result.stderr as String : '';
      final all = parseSceneTimestampsMs(stderr);
      final truncated = all.length > cap;
      final scenes = truncated ? all.sublist(0, cap) : all;
      return SceneDetection(scenesMs: scenes, truncated: truncated);
    } catch (e, s) {
      debugPrint('SceneDetection error: $e\n$s');
      return null;
    }
  }

  /// Pure parser: extract ordered scene-start timestamps (ms) from FFmpeg
  /// stderr. Each `showinfo` line carries `pts_time:<seconds>`.
  static List<int> parseSceneTimestampsMs(String stderr) {
    final matches = RegExp(r'pts_time:([0-9]+(?:\.[0-9]+)?)').allMatches(stderr);
    return [for (final m in matches) (double.parse(m.group(1)!) * 1000).round()];
  }
}
