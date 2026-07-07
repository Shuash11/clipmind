import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class UpdateDownloader {
  final String downloadUrl;
  final void Function(double? progress, String status)? onProgress;

  UpdateDownloader({required this.downloadUrl, this.onProgress});

  Future<void> downloadAndInstall() async {
    if (downloadUrl.isEmpty) {
      throw Exception('Download URL is empty - no release asset found');
    }

    onProgress?.call(0, 'Starting download...');

    final tempDir = await Directory.systemTemp.createTemp('clipmind_update_');
    final zipPath = '${tempDir.path}\\update.zip';

    try {
      await _downloadFile(downloadUrl, zipPath);

      onProgress?.call(0.7, 'Extracting...');

      await _extractZip(zipPath, tempDir.path);

      final extractedDir = Directory('${tempDir.path}\\new');
      if (!extractedDir.existsSync() || extractedDir.listSync().isEmpty) {
        throw Exception('Extraction produced no files');
      }

      onProgress?.call(0.85, 'Installing...');

      final appDir = File(Platform.resolvedExecutable).parent.path;
      await _runUpdate(appDir, tempDir.path);
    } catch (e) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _downloadFile(String url, String destPath) async {
    final innerClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    final client = IOClient(innerClient);
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        throw Exception(
            'Download failed (HTTP ${response.statusCode})');
      }

      final total = response.contentLength;
      var received = 0;
      final file = File(destPath);
      final sink = file.openWrite();

      try {
        await for (final chunk in response.stream) {
          received += chunk.length;
          sink.add(chunk);
          if (total != null && total > 0) {
            onProgress?.call(
              (received / total) * 0.7,
              'Downloading (${_formatSize(received)} / ${_formatSize(total)})',
            );
          } else {
            onProgress?.call(
              null,
              'Downloading (${_formatSize(received)}...)',
            );
          }
        }
      } finally {
        await sink.close();
      }

      final written = File(destPath);
      if (!written.existsSync() || written.lengthSync() == 0) {
        throw Exception('Downloaded file is empty');
      }

      final header = await written.openRead(0, 4).first;
      if (header.length < 4 ||
          header[0] != 0x50 ||
          header[1] != 0x4B ||
          header[2] != 0x03 ||
          header[3] != 0x04) {
        throw Exception('Downloaded file is not a valid ZIP archive');
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
    const script = r'''
param($appDir, $tempPath)

$exePath = Join-Path $appDir "clipmind.exe"
$logPath = Join-Path $env:TEMP "clipmind_update.log"

# Let parent process fully release file handles
Start-Sleep -Seconds 3

Add-Content $logPath "Update script started at $(Get-Date)"

# Wait for clipmind to exit
$timeout = 30
$elapsed = 0
while ($elapsed -lt $timeout) {
  $procs = Get-Process -Name "clipmind" -ErrorAction SilentlyContinue
  if ($procs.Count -eq 0) { break }
  Start-Sleep -Seconds 1
  $elapsed++
}

if ($elapsed -ge $timeout) {
  Add-Content $logPath "ERROR: Timed out waiting for clipmind to exit"
  exit 1
}

# Copy files with retry (ErrorAction Stop makes errors catchable)
$maxRetries = 10
for ($i = 0; $i -lt $maxRetries; $i++) {
  try {
    Copy-Item "$tempPath\new\*" $appDir -Recurse -Force -ErrorAction Stop
    Add-Content $logPath "Copied files successfully"
    break
  } catch {
    if ($i -eq $maxRetries - 1) {
      Add-Content $logPath "ERROR: Copy failed after $maxRetries retries: $_"
      exit 1
    }
    Start-Sleep -Seconds 2
  }
}

# Cleanup temp
Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue

# Restart
try {
  Start-Process $exePath
  Add-Content $logPath "Started new clipmind.exe"
} catch {
  Add-Content $logPath "ERROR: Failed to start clipmind.exe: $_"
  exit 1
}

# Self-delete
Start-Sleep -Seconds 2
Remove-Item $PSCommandPath -Force -ErrorAction SilentlyContinue
Remove-Item $logPath -Force -ErrorAction SilentlyContinue
''';

    final scriptPath = '$appDir\\update.ps1';
    await File(scriptPath).writeAsString(script);

    onProgress?.call(1.0, 'Restarting...');

    await Process.start(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-appDir',
        appDir,
        '-tempPath',
        tempPath,
      ],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }
}