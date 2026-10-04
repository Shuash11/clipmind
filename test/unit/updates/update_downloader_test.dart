import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/updates/update_downloader.dart';

class _StarterCall {
  _StarterCall(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}

/// Records invocations AND writes the started marker the helper script's
/// first action would write (marker path = script dir + marker name), so
/// the Dart-side handoff wait succeeds without spawning processes.
/// [onMarker] fires when the marker is written so tests can assert the
/// app exits only after the marker appears.
class _MarkerWritingStarter {
  final calls = <_StarterCall>[];
  final void Function()? onMarker;

  _MarkerWritingStarter({this.onMarker});

  Future<void> call(String executable, List<String> arguments) async {
    calls.add(_StarterCall(executable, List.of(arguments)));
    final fileIndex = arguments.indexOf('-File');
    if (fileIndex >= 0) {
      final scriptDir = File(arguments[fileIndex + 1]).parent.path;
      await File('$scriptDir\\update-started.marker')
          .writeAsString('started');
      onMarker?.call();
    }
  }
}

/// Records invocations only: never writes the started marker, so the
/// Dart-side handoff wait times out (the silent-death scenario).
class _RecordingStarter {
  final calls = <_StarterCall>[];

  Future<void> call(String executable, List<String> arguments) async {
    calls.add(_StarterCall(executable, List.of(arguments)));
  }
}

/// Serves [bytes] for every request; closed per-test in tearDown.
Future<HttpServer> _serveBytes(List<int> bytes) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.contentLength = bytes.length;
    request.response.add(bytes);
    await request.response.close();
  });
  return server;
}

Set<String> _updateTempDirs() => Directory.systemTemp
    .listSync()
    .whereType<Directory>()
    .map((d) => d.path)
    .where((p) => p.contains('clipmind_update'))
    .toSet();

void main() {
  group('UpdateDownloader installer path', () {
    late HttpServer server;
    late List<int> payload;
    late String payloadDigest;
    late _MarkerWritingStarter starter;
    late List<String> events;
    late Directory appDir;
    late Directory updatesDir;
    late Set<String> tempBefore;

    setUp(() async {
      final random = Random(7);
      payload = List<int>.generate(64 * 1024, (_) => random.nextInt(256));
      payloadDigest = 'sha256:${sha256.convert(payload)}';
      server = await _serveBytes(payload);
      events = [];
      starter = _MarkerWritingStarter(
        onMarker: () => events.add('marker'),
      );
      appDir = await Directory.systemTemp.createTemp('clipmind_appdir_');
      updatesDir = await Directory.systemTemp.createTemp('clipmind_updates_');
      tempBefore = _updateTempDirs();
    });

    tearDown(() async {
      await server.close(force: true);
      await appDir.delete(recursive: true);
      await updatesDir.delete(recursive: true);
      for (final path in _updateTempDirs().difference(tempBefore)) {
        await Directory(path).delete(recursive: true);
      }
    });

    String url(String file) => 'http://127.0.0.1:${server.port}/$file';

    UpdateDownloader downloader({String? digest, String? targetVersion}) =>
        UpdateDownloader(
          downloadUrl: url('setup.exe'),
          assetType: 'installer',
          digest: digest,
          targetVersion: targetVersion,
          processStarter: starter.call,
          exitApp: (code) => events.add('exit-$code'),
          appDirOverride: appDir.path,
          updatesDirOverride: updatesDir.path,
        );

    test(
        'launches installer with silent args and the handoff payload '
        'through the seam', () async {
      await downloader(digest: payloadDigest, targetVersion: '1.36.4')
          .downloadAndInstall();

      expect(starter.calls, hasLength(1));
      expect(starter.calls.single.executable, 'powershell');

      final created = _updateTempDirs().difference(tempBefore);
      expect(created, hasLength(1));
      final scriptPath = '${created.single}\\update-installer.ps1';
      final resultPath = '${updatesDir.path}\\update-result.json';
      final logPath = '${updatesDir.path}\\update.log';
      expect(starter.calls.single.arguments, contains('-File'));
      expect(starter.calls.single.arguments, contains(scriptPath));
      // Result path, updates dir (log), app dir, and target version are
      // passed as script arguments — never embedded in the script body.
      expect(starter.calls.single.arguments, contains(resultPath));
      expect(starter.calls.single.arguments, contains(logPath));
      expect(starter.calls.single.arguments, contains('1.36.4'));
      expect(starter.calls.single.arguments, contains(appDir.path));

      final script = await File(scriptPath).readAsString();
      // Handoff integrity: started marker is the script's first action.
      expect(script, contains('update-started.marker'));
      final markerIndex = script.indexOf('update-started.marker');
      final sleepIndex = script.indexOf('Start-Sleep');
      expect(markerIndex, lessThan(sleepIndex));
      // Logging + error handling + result JSON + registry + cleanup.
      expect(script, contains('function Log'));
      expect(script, contains('try {'));
      expect(script, contains('catch {'));
      expect(script, contains('ConvertTo-Json'));
      expect(script, contains('"success"'));
      expect(script, contains('"failed"'));
      expect(script, contains('expectedVersion = "\$TargetVersion"'));
      expect(
        script,
        contains(
          r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
          r'\{B8F7A3D1-9E4C-4A6B-8D2F-5C1E3A7B9D0F}_is1',
        ),
      );
      expect(
        script,
        contains('Remove-Item -Path \$PSScriptRoot -Recurse -Force'),
      );
      expect(script, contains('Stop-Process'));
      expect(script, contains('${created.single}\\setup.exe'));
      expect(script, contains('/VERYSILENT'));
      expect(script, contains('/CLOSEAPPLICATIONS'));
      expect(script, contains('/SUPPRESSMSGBOXES'));
      expect(script, contains('Start-Sleep -Seconds 3'));
      expect(script, contains('\$p = Get-Process'));
      expect(
        script,
        contains('\$installer = Start-Process -FilePath'),
      );
      expect(script, contains('-Wait -PassThru'));
      expect(script, contains('ExitCode -eq 0'));
      expect(script, contains('clipmind.exe'));
      expect(script, isNot(contains('powershell -NoProfile -Command')));
      // The literal paths live in the arguments, not the script body.
      expect(script, isNot(contains(resultPath)));
      expect(script, isNot(contains('1.36.4')));

      // The app exits only after the marker appeared (the starter fires
      // onMarker when writing; exitApp follows the marker wait).
      expect(
        File('${created.single}\\update-started.marker').existsSync(),
        isTrue,
      );
      expect(events, ['marker', 'exit-0']);
    });

    test('digest mismatch blocks install and cleans the temp dir', () async {
      final wrong = 'sha256:${sha256.convert([1, 2, 3])}';
      UpdateVerificationException? caught;
      try {
        await downloader(digest: wrong).downloadAndInstall();
      } on UpdateVerificationException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.message, contains('security check'));
      expect(caught.result.reason, 'mismatch');
      expect(starter.calls, isEmpty);
      expect(events, isEmpty);
      expect(_updateTempDirs().difference(tempBefore), isEmpty);
    });

    test('absent digest fails open for backward compatibility', () async {
      await downloader().downloadAndInstall();

      expect(starter.calls, hasLength(1));
      expect(events, ['marker', 'exit-0']);
    });

    test('malformed digest fails closed', () async {
      UpdateVerificationException? caught;
      try {
        await downloader(digest: 'sha256:not-hex').downloadAndInstall();
      } on UpdateVerificationException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.result.reason, 'malformed-digest');
      expect(starter.calls, isEmpty);
      expect(events, isEmpty);
      expect(_updateTempDirs().difference(tempBefore), isEmpty);
    });

    test('helper that never starts throws UpdateStartException, no exit, '
        'temp dir cleaned', () async {
      final silent = _RecordingStarter();
      UpdateStartException? caught;
      try {
        await UpdateDownloader(
          downloadUrl: url('setup.exe'),
          assetType: 'installer',
          digest: payloadDigest,
          processStarter: silent.call,
          exitApp: (code) => events.add('exit-$code'),
          appDirOverride: appDir.path,
          updatesDirOverride: updatesDir.path,
          markerTimeout: const Duration(milliseconds: 100),
        ).downloadAndInstall();
      } on UpdateStartException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.message, contains('could not start'));
      expect(silent.calls, hasLength(1));
      // No silent death: the app never exits on a failed handoff.
      expect(events, isEmpty);
      expect(_updateTempDirs().difference(tempBefore), isEmpty);
    });
  });

  group('UpdateDownloader zip path', () {
    late Directory fixtures;
    late List<int> zipBytes;
    late String zipDigest;

    setUpAll(() async {
      fixtures = await Directory.systemTemp.createTemp('clipmind_zipfix_');
      final stage = Directory('${fixtures.path}\\stage')..createSync();
      await File('${stage.path}\\alpha.txt').writeAsString('alpha');
      await File('${stage.path}\\beta.txt').writeAsString('beta');
      final zipPath = '${fixtures.path}\\fixture.zip';
      final packed = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Compress-Archive',
        '-Path',
        "'${stage.path}\\*'",
        '-DestinationPath',
        "'$zipPath'",
        '-Force',
      ]);
      expect(
        packed.exitCode,
        0,
        reason: 'Compress-Archive failed: ${packed.stderr}',
      );
      zipBytes = await File(zipPath).readAsBytes();
      zipDigest = 'sha256:${sha256.convert(zipBytes)}';
    });

    tearDownAll(() async {
      await fixtures.delete(recursive: true);
    });

    late HttpServer server;
    late _MarkerWritingStarter starter;
    late List<String> events;
    late Directory fakeAppDir;
    late Directory updatesDir;
    late Set<String> tempBefore;

    setUp(() async {
      server = await _serveBytes(zipBytes);
      events = [];
      starter = _MarkerWritingStarter(
        onMarker: () => events.add('marker'),
      );
      fakeAppDir = await Directory.systemTemp.createTemp('clipmind_appdir_');
      updatesDir = await Directory.systemTemp.createTemp('clipmind_updates_');
      tempBefore = _updateTempDirs();
    });

    tearDown(() async {
      await server.close(force: true);
      await fakeAppDir.delete(recursive: true);
      await updatesDir.delete(recursive: true);
      for (final path in _updateTempDirs().difference(tempBefore)) {
        await Directory(path).delete(recursive: true);
      }
    });

    UpdateDownloader downloader({String? targetVersion}) => UpdateDownloader(
          downloadUrl: 'http://127.0.0.1:${server.port}/update.zip',
          assetType: 'zip',
          digest: zipDigest,
          targetVersion: targetVersion,
          processStarter: starter.call,
          exitApp: (code) => events.add('exit-$code'),
          appDirOverride: fakeAppDir.path,
          updatesDirOverride: updatesDir.path,
        );

    test('writes update.ps1 to the temp dir as plain statements', () async {
      await downloader(targetVersion: '1.36.4').downloadAndInstall();

      // The downloader created exactly one temp dir; extraction must have
      // landed in its real `new` subdirectory (not a literal `$tempPath`).
      final created = _updateTempDirs().difference(tempBefore);
      expect(created, hasLength(1));
      final extracted = Directory('${created.single}\\new');
      expect(extracted.existsSync(), isTrue);
      expect(
        extracted.listSync().map((e) => e.path.split('\\').last).toSet(),
        containsAll(['alpha.txt', 'beta.txt']),
      );

      // The script lives in the downloader temp dir (writable) — never in
      // the app dir, which may be admin-owned (C:\Program Files\ClipMind).
      final scriptFile = File('${created.single}\\update.ps1');
      expect(scriptFile.existsSync(), isTrue);
      expect(File('${fakeAppDir.path}\\update.ps1').existsSync(), isFalse);
      final script = await scriptFile.readAsString();
      expect(script, contains('${created.single}\\new\\*'));
      expect(script, contains(fakeAppDir.path));
      expect(
        script,
        contains("Copy-Item '${created.single}\\new\\*' '${fakeAppDir.path}'"),
      );
      expect(script, contains('Start-Sleep -Seconds 3'));
      expect(script, contains('\$p = Get-Process'));
      expect(script, contains('Stop-Process -Name clipmind -Force'));
      expect(script, contains('Start-Process'));
      expect(script, contains('${fakeAppDir.path}\\clipmind.exe'));
      expect(script, isNot(contains('powershell -NoProfile -Command')));
      expect(script, isNot(contains(r'$tempPath')));
      expect(script, isNot(contains(r'$appDir')));
      expect(script, isNot(contains(r'\$p')));

      // Handoff integrity + logging + result JSON + cleanup.
      expect(script, contains('update-started.marker'));
      expect(script, contains('function Log'));
      expect(script, contains('try {'));
      expect(script, contains('catch {'));
      expect(script, contains('ConvertTo-Json'));
      expect(script, contains('"success"'));
      expect(script, contains('"failed"'));
      expect(script, contains('expectedVersion = "\$TargetVersion"'));
      expect(
        script,
        contains('Remove-Item -Path \$PSScriptRoot -Recurse -Force'),
      );
      // Result path, updates dir (log), and target version are script
      // arguments — never embedded in the script body.
      final resultPath = '${updatesDir.path}\\update-result.json';
      expect(starter.calls.single.arguments, contains(resultPath));
      expect(starter.calls.single.arguments,
          contains('${updatesDir.path}\\update.log'));
      expect(starter.calls.single.arguments, contains('1.36.4'));
      expect(starter.calls.single.arguments, contains(fakeAppDir.path));
      expect(script, isNot(contains(resultPath)));
      expect(script, isNot(contains('1.36.4')));

      // The app exits only after the marker appeared (the starter fires
      // onMarker when writing; exitApp follows the marker wait).
      expect(
        File('${created.single}\\update-started.marker').existsSync(),
        isTrue,
      );
      expect(events, ['marker', 'exit-0']);
    });

    test('digest mismatch blocks install and cleans the temp dir', () async {
      final wrong = 'sha256:${sha256.convert([1, 2, 3])}';
      final badDownloader = UpdateDownloader(
        downloadUrl: 'http://127.0.0.1:${server.port}/update.zip',
        assetType: 'zip',
        digest: wrong,
        processStarter: starter.call,
        exitApp: (code) => events.add('exit-$code'),
        appDirOverride: fakeAppDir.path,
        updatesDirOverride: updatesDir.path,
      );

      UpdateVerificationException? caught;
      try {
        await badDownloader.downloadAndInstall();
      } on UpdateVerificationException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.message, contains('security check'));
      expect(caught.result.reason, 'mismatch');
      expect(starter.calls, isEmpty);
      expect(events, isEmpty);
      expect(_updateTempDirs().difference(tempBefore), isEmpty);
    });

    group('psSingleQuoted', () {
      test('wraps a plain path in single quotes', () {
        expect(psSingleQuoted(r'C:\Temp\app'), "'C:\\Temp\\app'");
      });

      test("doubles apostrophes in usernames like O'Brien", () {
        expect(psSingleQuoted("O'Brien"), "'O''Brien'");
      });

      test('keeps an apostrophe path as one PowerShell literal', () {
        expect(
          psSingleQuoted(r"C:\Users\O'Brien\App"),
          "'C:\\Users\\O''Brien\\App'",
        );
      });
    });
  });
}
