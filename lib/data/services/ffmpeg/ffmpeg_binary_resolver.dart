import 'dart:io';

class FfmpegBinaryResolver {
  String? _cachedFfmpeg;
  String? _cachedFfprobe;

  String? resolveFfmpeg({String? settingsPath}) {
    if (_cachedFfmpeg != null) return _cachedFfmpeg;
    _cachedFfmpeg = _resolve('ffmpeg', settingsPath: settingsPath);
    return _cachedFfmpeg;
  }

  String? resolveFfprobe({String? settingsPath}) {
    if (_cachedFfprobe != null) return _cachedFfprobe;
    _cachedFfprobe = _resolve('ffprobe', settingsPath: settingsPath);
    return _cachedFfprobe;
  }

  String? _resolve(String binary, {String? settingsPath}) {
    if (settingsPath != null) {
      final f = File(settingsPath);
      if (f.existsSync()) return settingsPath;
    }
    final bundled = _bundledPath(binary);
    if (bundled != null && File(bundled).existsSync()) return bundled;
    return _which(binary);
  }

  String? _bundledPath(String binary) {
    final platform = _executablePlatform();
    final ext = Platform.isWindows ? '.exe' : '';
    return 'assets/bin/$platform/$binary$ext';
  }

  String _executablePlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  String? _which(String binary) {
    try {
      final cmd = Platform.isWindows ? 'where' : 'which';
      final result = Process.runSync(cmd, [binary]);
      if (result.exitCode == 0) {
        final path = (result.stdout as String)
            .trim()
            .split(Platform.lineTerminator)
            .firstWhere((p) => p.isNotEmpty, orElse: () => '');
        return path.isNotEmpty ? path : null;
      }
    } catch (_) {}
    return null;
  }

  void invalidateCache() {
    _cachedFfmpeg = null;
    _cachedFfprobe = null;
  }
}
