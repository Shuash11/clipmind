import 'dart:io';
import 'package:flutter/foundation.dart';

import 'command_builder.dart';
import 'ffmpeg_binary_resolver.dart';

/// One procedural sound preset for the sound panel.
///
/// [id] matches a [CommandBuilder.proceduralSoundSource] lavfi mapping;
/// [durationSeconds] documents the generated wav length for the panel UI.
class ProceduralSoundPreset {
  final String id;
  final String label;
  final double durationSeconds;

  const ProceduralSoundPreset({
    required this.id,
    required this.label,
    required this.durationSeconds,
  });
}

/// Procedural sound generation via FFmpeg lavfi (no external audio files).
///
/// The 6 presets follow the verified mcp-video pattern: `sine` tones and
/// `anoisesrc` noise rendered to temp wavs, which the sound panel then
/// layers via the `addSound` op. Mirrors [FfprobeService] /
/// [SceneDetectionService]: resolver-injected, null on missing binary or
/// failed run. Never throws.
class ProceduralSoundService {
  final FfmpegBinaryResolver _resolver;

  /// Process runner seam (defaults to [Process.run]) for unit tests.
  final Future<ProcessResult> Function(String exe, List<String> args) _run;

  static const List<ProceduralSoundPreset> presets = [
    ProceduralSoundPreset(id: 'beep', label: 'Beep', durationSeconds: 0.3),
    ProceduralSoundPreset(
      id: 'drone-low',
      label: 'Drone (low)',
      durationSeconds: 10,
    ),
    ProceduralSoundPreset(
      id: 'drone-mid',
      label: 'Drone (mid)',
      durationSeconds: 10,
    ),
    ProceduralSoundPreset(id: 'hum', label: 'Hum', durationSeconds: 10),
    ProceduralSoundPreset(
      id: 'static-noise',
      label: 'Static noise',
      durationSeconds: 10,
    ),
    ProceduralSoundPreset(
      id: 'alert-chime',
      label: 'Alert chime',
      durationSeconds: 0.6,
    ),
  ];

  ProceduralSoundService({
    FfmpegBinaryResolver? resolver,
    Future<ProcessResult> Function(String exe, List<String> args)? runProcess,
  }) : _resolver = resolver ?? FfmpegBinaryResolver(),
       _run = runProcess ?? Process.run;

  /// True for the 6 known preset ids.
  static bool isKnownPreset(String presetId) {
    return CommandBuilder.proceduralSoundSource(presetId) != null;
  }

  /// Lavfi source string for [presetId], or null when unknown.
  static String? lavfiSourceFor(String presetId) {
    return CommandBuilder.proceduralSoundSource(presetId);
  }

  /// Generate [presetId] to a temp wav file.
  ///
  /// Returns the wav path, or null when the preset is unknown, FFmpeg is
  /// unavailable, or the run fails. Pass [outputPath] to pin the
  /// destination (tests do); otherwise a system-temp file is used.
  Future<String?> generate(
    String presetId, {
    String? outputPath,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final source = CommandBuilder.proceduralSoundSource(presetId);
    if (source == null) return null;
    final binary = _resolver.resolveFfmpeg();
    if (binary == null) return null;

    try {
      final out =
          outputPath ??
          '${Directory.systemTemp.createTempSync('clipmind_sounds_').path}/$presetId.wav';
      File(out).parent.createSync(recursive: true);
      final result = await _run(binary, [
        ...CommandBuilder.lavfiToWav(source),
        '-y',
        out,
      ]).timeout(timeout);
      if (result.exitCode != 0) return null;
      if (!File(out).existsSync()) return null;
      return out;
    } catch (e, s) {
      debugPrint('ProceduralSound error: $e\n$s');
      return null;
    }
  }
}
