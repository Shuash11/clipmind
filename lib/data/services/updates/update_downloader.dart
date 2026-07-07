import 'dart:io';
import 'package:http/http.dart' as http;

class UpdateDownloader {
  final String downloadUrl;
  final void Function(double progress, String status)? onProgress;

  UpdateDownloader({required this.downloadUrl, this.onProgress});

  Future<void> downloadAndInstall() async {
    if (downloadUrl.isEmpty) {
      throw Exception('Download URL is empty - no release asset found');
    }

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
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        throw Exception(
            'Download failed (HTTP ${response.statusCode})');
      }

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

      final written = File(destPath);
      if (!written.existsSync() || written.lengthSync() == 0) {
        throw Exception('Downloaded file is empty');
      }
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
    const script = r'''
param($appDir, $tempPath)

$exePath = Join-Path $appDir "clipmind.exe"
$logPath = Join-Path $appDir "update.log"

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

Start-Sleep -Seconds 1

# Copy files with retry
$maxRetries = 10
for ($i = 0; $i -lt $maxRetries; $i++) {
  try {
    Copy-Item "$tempPath\new\*" $appDir -Recurse -Force
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
Start-Process $exePath
Add-Content $logPath "Started new clipmind.exe"

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
      runInShell: true,
      mode: ProcessStartMode.detached,
    );
    Future.delayed(const Duration(milliseconds: 500), () => exit(0));
  }
}
