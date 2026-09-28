import 'dart:io';
import 'package:flutter/foundation.dart';

/// Configured whisper.cpp locations (from Settings; wired by the state
/// layer through the tool-context `whisperConfig` callback).
class WhisperPaths {
  final String binaryPath;
  final String modelPath;

  const WhisperPaths({required this.binaryPath, required this.modelPath});
}

/// Plain-text transcription of one audio file.
class WhisperTranscript {
  final String text;

  const WhisperTranscript({required this.text});

  int get charCount => text.length;
  bool get isEmpty => text.trim().isEmpty;
}

/// whisper.cpp transcription (Phase 6a).
///
/// The binary is **not bundled**: it resolves a Settings-configured path
/// first, then falls back to PATH (`whisper-cli`, then `whisper`). Every
/// entry point degrades gracefully (null / false, never throws) so the
/// `get_transcript` tool can report an actionable error when whisper is
/// absent.
///
/// UNVERIFIED: no whisper.cpp binary is installed in this environment, so
/// the exact CLI flags below (`-m <model> -f <wav>`, transcript on stdout
/// with `[00:00:00.000 --> 00:00:00.000]` line prefixes) are taken from the
/// whisper.cpp README/USAGE docs and have not been run. Re-verify against a
/// real install before relying on flag details. What IS fixed: whisper.cpp
/// requires 16 kHz mono WAV input — the tool executor extracts that via
/// FFmpeg before calling [transcribe].
class WhisperTranscriptionService {
  /// Process runner seam (defaults to [Process.run]) for unit tests.
  final Future<ProcessResult> Function(String exe, List<String> args) _run;

  WhisperTranscriptionService({
    Future<ProcessResult> Function(String exe, List<String> args)? runProcess,
  }) : _run = runProcess ?? Process.run;

  /// Resolve the whisper binary: configured path first, then PATH fallback.
  /// Returns null when nothing usable is found.
  String? findBinary({String? configuredPath}) {
    if (configuredPath != null &&
        configuredPath.trim().isNotEmpty &&
        isSafeConfiguredPath(configuredPath) &&
        File(configuredPath).existsSync()) {
      return configuredPath;
    }
    return _which('whisper-cli') ?? _which('whisper');
  }

  /// Probe: true when a usable binary resolves.
  bool isAvailable({String? configuredPath}) {
    return findBinary(configuredPath: configuredPath) != null;
  }

  /// Transcribe a 16 kHz mono WAV file with [modelPath] (ggml model).
  ///
  /// Returns null on any failure (missing files, non-zero exit, timeout,
  /// empty transcript). Never throws.
  Future<WhisperTranscript?> transcribe(
    String audioPath,
    String modelPath, {
    String? binaryPath,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final binary = findBinary(configuredPath: binaryPath);
    if (binary == null) return null;
    if (!File(audioPath).existsSync()) return null;
    if (!isSafeConfiguredPath(modelPath) || !File(modelPath).existsSync()) {
      return null;
    }
    try {
      final result = await _run(binary, [
        '-m',
        modelPath,
        '-f',
        audioPath,
      ]).timeout(timeout);
      if (result.exitCode != 0) return null;
      final stdout = result.stdout is String ? result.stdout as String : '';
      final text = parseTranscriptText(stdout);
      if (text.trim().isEmpty) return null;
      return WhisperTranscript(text: text);
    } catch (e, s) {
      debugPrint('WhisperTranscription error: $e\n$s');
      return null;
    }
  }

  /// Pure parser: strip `[start --> end]` timestamp prefixes (and blank /
  /// progress lines), joining the spoken text.
  static String parseTranscriptText(String stdout) {
    final lines = <String>[];
    for (final raw in stdout.split('\n')) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      final bracket = RegExp(r'^\[.*?-->\s*.*?\]\s*').firstMatch(line);
      if (bracket != null) line = line.substring(bracket.end).trim();
      if (line.isEmpty) continue;
      lines.add(line);
    }
    return lines.join('\n');
  }

  /// User-configured paths must be absolute existing-file candidates with
  /// no `..` traversal segments. (PATH-resolved binaries are trusted as-is;
  /// temp/output files always live under the app temp dir.)
  static bool isSafeConfiguredPath(String path) {
    if (path.trim().isEmpty) return false;
    if (path.contains('..')) return false;
    return _isAbsolute(path);
  }

  static bool _isAbsolute(String path) {
    if (Platform.isWindows) {
      return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path) ||
          path.startsWith(r'\\');
    }
    return path.startsWith('/');
  }

  String? _which(String binary) {
    try {
      final cmd = Platform.isWindows ? 'where' : 'which';
      final result = Process.runSync(cmd, [binary]);
      if (result.exitCode == 0) {
        final path = (result.stdout as String)
            .trim()
            .split(Platform.isWindows ? '\r\n' : '\n')
            .map((p) => p.trim())
            .firstWhere((p) => p.isNotEmpty, orElse: () => '');
        if (path.isNotEmpty && File(path).existsSync()) return path;
      }
    } catch (_) {}
    return null;
  }
}
