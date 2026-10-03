import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'asset_verifier.dart';

/// Launches a detached process (installer or post-extraction script).
/// Injectable so tests can record invocations without spawning processes.
typedef UpdateProcessStarter =
    Future<void> Function(String executable, List<String> arguments);

Future<void> _defaultProcessStarter(
  String executable,
  List<String> arguments,
) async {
  await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.detached,
  );
}

/// Wraps [value] in PowerShell single quotes, doubling embedded
/// apostrophes so paths like `C:\Users\O'Brien\...` stay one literal.
@visibleForTesting
String psSingleQuoted(String value) => "'${value.replaceAll("'", "''")}'";

/// Thrown when a downloaded update fails artifact verification. The
/// download is deleted and no install step runs.
class UpdateVerificationException implements Exception {
  final String message;
  final AssetVerificationResult result;

  const UpdateVerificationException(this.message, {required this.result});

  @override
  String toString() => 'UpdateVerificationException: $message';
}

class UpdateDownloader {
  final String downloadUrl;
  final String assetType;
  final String? digest;
  final void Function(double? progress, String status)? onProgress;
  final ReleaseAssetVerifier verifier;
  final UpdateProcessStarter processStarter;
  final void Function(int code) exitApp;
  final String? appDirOverride;

  UpdateDownloader({
    required this.downloadUrl,
    this.assetType = 'zip',
    this.onProgress,
    this.digest,
    ReleaseAssetVerifier? verifier,
    UpdateProcessStarter? processStarter,
    void Function(int code)? exitApp,
    this.appDirOverride,
  }) : verifier = verifier ?? const ReleaseAssetVerifier(),
       processStarter = processStarter ?? _defaultProcessStarter,
       exitApp = exitApp ?? exit;

  String get _appDir =>
      appDirOverride ?? File(Platform.resolvedExecutable).parent.path;

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

      onProgress?.call(isInstaller ? 0.9 : 0.7, 'Verifying download...');
      final outcome = verifier.verify(File(filePath), digest);
      if (!outcome.passed) {
        throw UpdateVerificationException(
          'The update failed a security check and was not installed.',
          result: outcome,
        );
      }

      if (isInstaller) {
        await _runInstaller(filePath, tempDir.path);
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
    final newDirPath = '$tempPath\\new';
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Expand-Archive',
      '-Path',
      zipPath,
      '-DestinationPath',
      newDirPath,
      '-Force',
    ]);
    if (result.exitCode != 0) {
      throw Exception('Extraction failed: ${result.stderr}');
    }
    final extractedDir = Directory(newDirPath);
    if (!extractedDir.existsSync() || extractedDir.listSync().isEmpty) {
      throw Exception('Extraction produced no files');
    }
    onProgress?.call(0.85, 'Installing...');
    final appDir = _appDir;

    // Single-quoted PowerShell literals treat backslashes as literal, so
    // the Dart-interpolated paths below are substituted exactly once and
    // need no backslash doubling. psSingleQuoted doubles embedded
    // apostrophes so usernames like O'Brien cannot break quoting.
    final quotedSource = psSingleQuoted('$newDirPath\\*');
    final quotedAppDir = psSingleQuoted(appDir);
    final quotedExe = psSingleQuoted('$appDir\\clipmind.exe');
    final script =
        'Start-Sleep -Seconds 3\n'
        '\$p = Get-Process clipmind -ErrorAction SilentlyContinue\n'
        'if (\$p) { Stop-Process -Name clipmind -Force }\n'
        'Copy-Item $quotedSource $quotedAppDir -Recurse -Force -ErrorAction Stop\n'
        'Start-Process $quotedExe\n';

    final scriptPath = '$tempPath\\update.ps1';
    await File(scriptPath).writeAsString(script);
    await processStarter('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
    ]);
    exitApp(0);
  }

  /// Runs the downloaded installer via a helper script that exits this app
  /// first. A running process holds `libmpv-2.dll` open, so an installer
  /// launched while ClipMind is alive fails its DeleteFile with code 5
  /// (Access is denied). The script waits briefly, force-stops the
  /// `clipmind` process, then launches setup.exe silently and relaunches
  /// ClipMind on a successful install (exit 0). The relaunch runs
  /// non-elevated from this helper, not from the installer's elevated
  /// `[Run]` section. `/CLOSEAPPLICATIONS` remains as a backstop for
  /// other processes. `/RESTARTAPPLICATIONS` was rejected: it is a no-op
  /// for Flutter apps, which never call `RegisterApplicationRestart`.
  Future<void> _runInstaller(String exePath, String tempPath) async {
    onProgress?.call(0.9, 'Running installer...');

    // Single-quoted PowerShell literals treat backslashes as literal, so
    // the Dart-interpolated paths below are substituted exactly once and
    // need no backslash doubling. psSingleQuoted doubles embedded
    // apostrophes so usernames like O'Brien cannot break quoting.
    final appDir = _appDir;
    final quotedExePath = psSingleQuoted(exePath);
    final quotedAppExe = psSingleQuoted('$appDir\\clipmind.exe');
    final script =
        'Start-Sleep -Seconds 3\n'
        '\$p = Get-Process clipmind -ErrorAction SilentlyContinue\n'
        'if (\$p) { Stop-Process -Name clipmind -Force }\n'
        "\$installer = Start-Process -FilePath $quotedExePath -ArgumentList '/VERYSILENT /NORESTART /CLOSEAPPLICATIONS' -Wait -PassThru\n"
        'if (\$installer.ExitCode -eq 0) { Start-Process -FilePath $quotedAppExe }\n';

    final scriptPath = '$tempPath\\update-installer.ps1';
    await File(scriptPath).writeAsString(script);
    await processStarter('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
    ]);
    exitApp(0);
  }
}
