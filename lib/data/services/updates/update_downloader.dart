import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';

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

/// Thrown when the detached helper script never wrote its started marker
/// within the wait window: the app must not exit into a silent death —
/// the user gets an honest error instead of a vanished update.
class UpdateStartException implements Exception {
  final String message;

  const UpdateStartException([
    this.message =
        'The update could not start. Please try again, or download the '
        'installer from the website.',
  ]);

  @override
  String toString() => message;
}

class UpdateDownloader {
  /// Must match `AppId` in installer/clipmind.iss — per-user updates
  /// resolve the relaunch path from the uninstall registry entry
  /// `HKCU\...\Uninstall\<AppId>_is1\InstallLocation`.
  static const _appId = '{B8F7A3D1-9E4C-4A6B-8D2F-5C1E3A7B9D0F}';

  final String downloadUrl;
  final String assetType;
  final String? digest;

  /// Release tag minus the leading 'v'; recorded in the result JSON as
  /// `expectedVersion` so the next launch can detect version mismatches.
  final String? targetVersion;
  final void Function(double? progress, String status)? onProgress;
  final ReleaseAssetVerifier verifier;
  final UpdateProcessStarter processStarter;
  final void Function(int code) exitApp;
  final String? appDirOverride;

  /// Test seam: overrides the stable updates dir (update.log +
  /// update-result.json). Defaults to `<appSupport>/updates`.
  final String? updatesDirOverride;

  /// How long to wait for the helper script's started marker before
  /// surfacing [UpdateStartException] instead of exiting silently.
  final Duration markerTimeout;

  UpdateDownloader({
    required this.downloadUrl,
    this.assetType = 'zip',
    this.onProgress,
    this.digest,
    this.targetVersion,
    ReleaseAssetVerifier? verifier,
    UpdateProcessStarter? processStarter,
    void Function(int code)? exitApp,
    this.appDirOverride,
    this.updatesDirOverride,
    this.markerTimeout = const Duration(seconds: 5),
  }) : verifier = verifier ?? const ReleaseAssetVerifier(),
       processStarter = processStarter ?? _defaultProcessStarter,
       exitApp = exitApp ?? exit;

  String get _appDir =>
      appDirOverride ?? File(Platform.resolvedExecutable).parent.path;

  /// Stable updates dir: the helper scripts write update.log and
  /// update-result.json here — never into the per-run temp dir, which the
  /// scripts delete when they finish.
  Future<String> _resolveUpdatesDir() async {
    final dir = updatesDirOverride ??
        '${(await getApplicationSupportDirectory()).path}'
        '${Platform.pathSeparator}updates';
    await Directory(dir).create(recursive: true);
    return dir;
  }

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
        final updatesDir = await _resolveUpdatesDir();
        await _runInstaller(filePath, tempDir.path, updatesDir);
      } else {
        final updatesDir = await _resolveUpdatesDir();
        await _extractAndInstallZip(filePath, tempDir.path, updatesDir);
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

  /// Waits for the helper script's started marker. The marker is the
  /// script's FIRST action, so seeing it proves the script actually
  /// launched — the app may then exit safely. Timeout means the script
  /// never started (UAC declined, blocked, missing interpreter): the
  /// caller surfaces [UpdateStartException] instead of exiting silently.
  Future<void> _waitForStartedMarker(String path, Duration timeout) async {
    const attempts = 20;
    final delay = timeout ~/ attempts;
    for (var i = 0; i < attempts; i++) {
      if (File(path).existsSync()) return;
      await Future<void>.delayed(delay);
    }
    throw const UpdateStartException();
  }

  /// Extracts the downloaded zip and installs it via a helper script with
  /// full handoff integrity: a started marker (proving the script ran)
  /// before this app exits, a log, a result JSON, and temp-dir cleanup.
  /// The copy runs against the app dir, which is user-writable with the
  /// per-user installer (PrivilegesRequired=lowest). The relaunch runs
  /// non-elevated from this helper. psSingleQuoted doubles embedded
  /// apostrophes so usernames like O'Brien cannot break quoting.
  Future<void> _extractAndInstallZip(
    String zipPath,
    String tempPath,
    String updatesDir,
  ) async {
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
    final resultPath = '$updatesDir\\update-result.json';
    final logPath = '$updatesDir\\update.log';
    final markerPath = '$tempPath\\update-started.marker';

    // Single-quoted PowerShell literals treat backslashes as literal, so
    // the Dart-interpolated paths below are substituted exactly once and
    // need no backslash doubling. psSingleQuoted doubles embedded
    // apostrophes so usernames like O'Brien cannot break quoting.
    final quotedSource = psSingleQuoted('$newDirPath\\*');
    final quotedAppDir = psSingleQuoted(appDir);
    final quotedExe = psSingleQuoted('$appDir\\clipmind.exe');
    final script =
        'param(\n'
        '  [string]\$ResultPath,\n'
        '  [string]\$LogPath,\n'
        '  [string]\$TargetVersion,\n'
        '  [string]\$OldAppDir\n'
        ')\n'
        "\$ErrorActionPreference = 'Stop'\n"
        'function Log([string]\$message) {\n'
        '  Add-Content -Path \$LogPath -Value '
        "((Get-Date -Format o) + ' ' + \$message) -ErrorAction SilentlyContinue\n"
        '}\n'
        'try {\n'
        '  Set-Content -Path (Join-Path \$PSScriptRoot "update-started.marker") '
        '-Value "started"\n'
        "  Log 'started'\n"
        '  Start-Sleep -Seconds 3\n'
        '\$p = Get-Process clipmind -ErrorAction SilentlyContinue\n'
        'if (\$p) { Stop-Process -Name clipmind -Force }\n'
        "  Log 'clipmind stopped; copying update'\n"
        '  Copy-Item $quotedSource $quotedAppDir -Recurse -Force -ErrorAction Stop\n'
        "  Log 'copy complete'\n"
        '  @{ status = "success"; expectedVersion = "\$TargetVersion"; '
        'finishedAt = (Get-Date -Format o) } | ConvertTo-Json | '
        'Set-Content -Path \$ResultPath\n'
        "  Log 'result written; relaunching'\n"
        '  Start-Process $quotedExe\n'
        '} catch {\n'
        "  Log ('update failed: ' + \$_.Exception.Message)\n"
        '  try {\n'
        '    @{ status = "failed"; reason = \$_.Exception.Message; '
        'finishedAt = (Get-Date -Format o) } | ConvertTo-Json | '
        'Set-Content -Path \$ResultPath -ErrorAction SilentlyContinue\n'
        '  } catch { }\n'
        '  try { Start-Process -FilePath $quotedExe } catch { }\n'
        '} finally {\n'
        '  Remove-Item -Path \$PSScriptRoot -Recurse -Force '
        '-ErrorAction SilentlyContinue\n'
        '}\n';

    final scriptPath = '$tempPath\\update.ps1';
    await File(scriptPath).writeAsString(script);
    await processStarter('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
      resultPath,
      logPath,
      targetVersion ?? '',
      appDir,
    ]);
    await _waitForStartedMarker(markerPath, markerTimeout);
    exitApp(0);
  }

  /// Runs the downloaded installer via a helper script with full handoff
  /// integrity: a started marker (proving the script ran) before this app
  /// exits, a log, a result JSON, and temp-dir cleanup. A running process
  /// holds `libmpv-2.dll` open, so the installer must run after the app
  /// has stopped. The script waits briefly, force-stops the `clipmind`
  /// process, launches setup.exe silently, and relaunches ClipMind from
  /// the registry-recorded install location (fallback old app dir) on a
  /// successful install (exit 0). A failed/errored run writes a failed
  /// result so the next launch surfaces the reason. With the per-user
  /// installer (PrivilegesRequired=lowest) no elevation is involved; the
  /// ExitCode read stays defensive anyway. `/CLOSEAPPLICATIONS` remains
  /// as a backstop for other processes. `/RESTARTAPPLICATIONS` was
  /// rejected: it is a no-op for Flutter apps, which never call
  /// `RegisterApplicationRestart`.
  Future<void> _runInstaller(
    String exePath,
    String tempPath,
    String updatesDir,
  ) async {
    onProgress?.call(0.9, 'Running installer...');
    final appDir = _appDir;
    final resultPath = '$updatesDir\\update-result.json';
    final logPath = '$updatesDir\\update.log';
    final markerPath = '$tempPath\\update-started.marker';

    // Single-quoted PowerShell literals treat backslashes as literal, so
    // the Dart-interpolated paths below are substituted exactly once and
    // need no backslash doubling. psSingleQuoted doubles embedded
    // apostrophes so usernames like O'Brien cannot break quoting.
    final quotedExePath = psSingleQuoted(exePath);
    final quotedAppExe = psSingleQuoted('$appDir\\clipmind.exe');
    final script =
        'param(\n'
        '  [string]\$ResultPath,\n'
        '  [string]\$LogPath,\n'
        '  [string]\$TargetVersion,\n'
        '  [string]\$OldAppDir\n'
        ')\n'
        "\$ErrorActionPreference = 'Stop'\n"
        'function Log([string]\$message) {\n'
        '  Add-Content -Path \$LogPath -Value '
        "((Get-Date -Format o) + ' ' + \$message) -ErrorAction SilentlyContinue\n"
        '}\n'
        'try {\n'
        '  Set-Content -Path (Join-Path \$PSScriptRoot "update-started.marker") '
        '-Value "started"\n'
        "  Log 'started'\n"
        '  Start-Sleep -Seconds 3\n'
        '\$p = Get-Process clipmind -ErrorAction SilentlyContinue\n'
        'if (\$p) { Stop-Process -Name clipmind -Force }\n'
        "  Log 'clipmind stopped; launching installer'\n"
        '  \$installer = Start-Process -FilePath $quotedExePath '
        "-ArgumentList '/VERYSILENT /NORESTART /CLOSEAPPLICATIONS /SUPPRESSMSGBOXES' "
        '-Wait -PassThru\n'
        '  try {\n'
        "    Log ('installer exit code ' + \$installer.ExitCode)\n"
        '  } catch {\n'
        "    Log 'exit code unavailable (elevated installer)'\n"
        '  }\n'
        '  if (\$installer.ExitCode -eq 0) {\n'
        "    Log 'install succeeded'\n"
        '    \$newDir = \$null\n'
        '    try {\n'
        "      \$uninstallKey = Get-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${_appId}_is1' -ErrorAction SilentlyContinue\n"
        '      if (\$uninstallKey -and \$uninstallKey.InstallLocation) {\n'
        '        \$newDir = \$uninstallKey.InstallLocation\n'
        '      }\n'
        '    } catch {\n'
        "      Log 'registry read failed; using old app dir'\n"
        '    }\n'
        '    if (-not \$newDir) { \$newDir = \$OldAppDir }\n'
        '    @{ status = "success"; expectedVersion = "\$TargetVersion"; '
        'finishedAt = (Get-Date -Format o) } | ConvertTo-Json | '
        'Set-Content -Path \$ResultPath\n'
        "    Log ('result written; relaunching from ' + \$newDir)\n"
        '    try {\n'
        "      Start-Process -FilePath (Join-Path \$newDir 'clipmind.exe')\n"
        '    } catch {\n'
        "      Log ('relaunch failed: ' + \$_.Exception.Message)\n"
        '    }\n'
        '  } else {\n'
        "    Log ('installer failed with exit code ' + \$installer.ExitCode)\n"
        '    @{ status = "failed"; reason = ("Installer exited with code " + '
        '\$installer.ExitCode); finishedAt = (Get-Date -Format o) } | '
        'ConvertTo-Json | Set-Content -Path \$ResultPath\n'
        '    try { Start-Process -FilePath $quotedAppExe } catch { }\n'
        '  }\n'
        '} catch {\n'
        "  Log ('update failed: ' + \$_.Exception.Message)\n"
        '  try {\n'
        '    @{ status = "failed"; reason = \$_.Exception.Message; '
        'finishedAt = (Get-Date -Format o) } | ConvertTo-Json | '
        'Set-Content -Path \$ResultPath -ErrorAction SilentlyContinue\n'
        '  } catch { }\n'
        '  try { Start-Process -FilePath $quotedAppExe } catch { }\n'
        '} finally {\n'
        '  Remove-Item -Path \$PSScriptRoot -Recurse -Force '
        '-ErrorAction SilentlyContinue\n'
        '}\n';

    final scriptPath = '$tempPath\\update-installer.ps1';
    await File(scriptPath).writeAsString(script);
    await processStarter('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
      resultPath,
      logPath,
      targetVersion ?? '',
      appDir,
    ]);
    await _waitForStartedMarker(markerPath, markerTimeout);
    exitApp(0);
  }
}
