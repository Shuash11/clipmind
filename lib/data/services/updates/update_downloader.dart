import 'dart:io';
import 'package:http/http.dart' as http;

class UpdateDownloader {
  final String downloadUrl;
  final void Function(double progress, String status)? onProgress;

  UpdateDownloader({required this.downloadUrl, this.onProgress});

  Future<void> downloadAndInstall() async {
    onProgress?.call(0, 'Starting download...');

    final tempDir = await Directory.systemTemp.createTemp('clipmind_update_');
    final zipPath = '${tempDir.path}\\update.zip';

    await _downloadFile(downloadUrl, zipPath);

    onProgress?.call(0.7, 'Extracting...');

    await _extractZip(zipPath, tempDir.path);

    onProgress?.call(0.85, 'Installing...');

    final appDir = File(Platform.resolvedExecutable).parent.path;
    await _runUpdate(appDir, tempDir.path);
  }

  Future<void> _downloadFile(String url, String destPath) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      final total = response.contentLength ?? 0;
      var received = 0;
      final file = File(destPath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          onProgress?.call((received / total) * 0.7, 'Downloading...');
        }
      }
      await sink.close();
    } finally {
      client.close();
    }
  }

  Future<void> _extractZip(String zipPath, String destPath) async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Expand-Archive',
        '-Path',
        zipPath,
        '-DestinationPath',
        '$destPath\\new',
        '-Force',
      ],
    );
    if (result.exitCode != 0) {
      throw Exception('Extraction failed: ${result.stderr}');
    }
  }

  Future<void> _runUpdate(String appDir, String tempPath) async {
    final script = '''
@echo off
cd /d "$appDir"
timeout /t 2 /nobreak >nul
xcopy /y /e /q "$tempPath\\new\\*" "$appDir\\"
rmdir /s /q "$tempPath"
start "" "clipmind.exe"
del "%~f0"
''';

    final scriptPath = '$appDir\\update.cmd';
    await File(scriptPath).writeAsString(script);

    onProgress?.call(1.0, 'Restarting...');
    await Process.start('cmd', ['/c', scriptPath],
        runInShell: true, mode: ProcessStartMode.detached);
    exit(0);
  }
}
