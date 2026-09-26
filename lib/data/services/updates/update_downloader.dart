import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class UpdateDownloader {
  final String downloadUrl;
  final String assetType;
  final void Function(double? progress, String status)? onProgress;

  UpdateDownloader({
    required this.downloadUrl,
    this.assetType = 'zip',
    this.onProgress,
  });

  Future<void> downloadAndInstall() async {
    if (downloadUrl.isEmpty) {
      throw Exception('Download URL is empty');
    }

    final isInstaller =
        assetType == 'installer' || downloadUrl.endsWith('.exe');
    onProgress?.call(0, 'Starting download...');

    final tempDir = await Directory.systemTemp.createTemp('clipmind_update');
    final fileName = isInstaller ? 'setup.exe' : 'update.zip';
    final filePath = '${tempDir.path}\\$fileName';

    try {
      await _downloadFile(downloadUrl, filePath, isInstaller);

      if (isInstaller) {
        await _runInstaller(filePath);
      } else {
        await _extractAndInstallZip(filePath, tempDir.path);
      }
    } catch (e) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _downloadFile(
    String url,
    String destPath,
    bool isInstaller,
  ) async {
    final innerClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    final client = IOClient(innerClient);
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        throw Exception('Download failed (HTTP ${response.statusCode})');
      }

      final total = response.contentLength;
      var received = 0;
      final sink = File(destPath).openWrite();

      try {
        await for (final chunk in response.stream) {
          received += chunk.length;
          sink.add(chunk);
          final pct = total != null && total > 0
              ? (received / total) * (isInstaller ? 0.9 : 0.7)
              : null;
          onProgress?.call(
            pct,
            total != null && total > 0
                ? 'Downloading (${_formatSize(received)} / ${_formatSize(total)})'
                : 'Downloading (${_formatSize(received)}...)',
          );
        }
      } finally {
        await sink.close();
      }

      final written = File(destPath);
      if (!written.existsSync() || written.lengthSync() == 0) {
        throw Exception('Downloaded file is empty');
      }
    } finally {
      client.close();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _extractAndInstallZip(String zipPath, String tempPath) async {
    onProgress?.call(0.7, 'Extracting...');
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Expand-Archive',
      '-Path',
      zipPath,
      '-DestinationPath',
      r'$tempPath\new',
      '-Force',
    ]);
    if (result.exitCode != 0) {
      throw Exception('Extraction failed: \${result.stderr}');
    }
    final extractedDir = Directory(r'$tempPath\new');
    if (!extractedDir.existsSync() || extractedDir.listSync().isEmpty) {
      throw Exception('Extraction produced no files');
    }
    onProgress?.call(0.85, 'Installing...');
    final appDir = File(Platform.resolvedExecutable).parent.path;
    final tempEscaped = tempPath.replaceAll(r'\', '\\\\');
    final appEscaped = appDir.replaceAll(r'\', '\\\\');

    const script =
        r"powershell -NoProfile -Command 'Start-Sleep -Seconds 3; \$p = Get-Process clipmind -ErrorAction SilentlyContinue; if (\$p) { Stop-Process -Name clipmind -Force }; Copy-Item ''{0}\new\*'' ''{1}'' -Recurse -Force -ErrorAction Stop; Start-Process ''{1}\clipmind.exe'' '";
    final scriptFilled = script
        .replaceAll('{0}', tempEscaped)
        .replaceAll('{1}', appEscaped);

    const scriptPath = r'$appDir\update.ps1';
    await File(scriptPath).writeAsString(scriptFilled);
    await Process.start('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }

  Future<void> _runInstaller(String exePath) async {
    onProgress?.call(0.9, 'Running installer...');
    await Process.start(exePath, [
      '/VERYSILENT',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}
