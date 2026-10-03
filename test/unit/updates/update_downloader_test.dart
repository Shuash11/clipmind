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
    late _RecordingStarter starter;
    late List<int> exitCodes;
    late Set<String> tempBefore;

    setUp(() async {
      final random = Random(7);
      payload = List<int>.generate(64 * 1024, (_) => random.nextInt(256));
      payloadDigest = 'sha256:${sha256.convert(payload)}';
      server = await _serveBytes(payload);
      starter = _RecordingStarter();
      exitCodes = [];
      tempBefore = _updateTempDirs();
    });

    tearDown(() async {
      await server.close(force: true);
      for (final path in _updateTempDirs().difference(tempBefore)) {
        await Directory(path).delete(recursive: true);
      }
    });

    String url(String file) => 'http://127.0.0.1:${server.port}/$file';

    UpdateDownloader downloader({String? digest}) => UpdateDownloader(
          downloadUrl: url('setup.exe'),
          assetType: 'installer',
          digest: digest,
          processStarter: starter.call,
          exitApp: exitCodes.add,
        );

    test('launches installer with silent args through the seam', () async {
      await downloader(digest: payloadDigest).downloadAndInstall();

      expect(starter.calls, hasLength(1));
      expect(starter.calls.single.executable, 'powershell');

      final created = _updateTempDirs().difference(tempBefore);
      expect(created, hasLength(1));
      final scriptPath = '${created.single}\\update-installer.ps1';
      expect(starter.calls.single.arguments, contains('-File'));
      expect(starter.calls.single.arguments, contains(scriptPath));

      final script = await File(scriptPath).readAsString();
      expect(script, contains('Stop-Process'));
      expect(script, contains('${created.single}\\setup.exe'));
      expect(script, contains('/VERYSILENT'));
      expect(script, contains('/CLOSEAPPLICATIONS'));
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

      expect(exitCodes, [0]);
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
      expect(exitCodes, isEmpty);
      expect(_updateTempDirs().difference(tempBefore), isEmpty);
    });

    test('absent digest fails open for backward compatibility', () async {
      await downloader().downloadAndInstall();

      expect(starter.calls, hasLength(1));
      expect(exitCodes, [0]);
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
      expect(exitCodes, isEmpty);
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
    late _RecordingStarter starter;
    late List<int> exitCodes;
    late Directory fakeAppDir;
    late Set<String> tempBefore;

    setUp(() async {
      server = await _serveBytes(zipBytes);
      starter = _RecordingStarter();
      exitCodes = [];
      fakeAppDir = await Directory.systemTemp.createTemp('clipmind_appdir_');
      tempBefore = _updateTempDirs();
    });

    tearDown(() async {
      await server.close(force: true);
      await fakeAppDir.delete(recursive: true);
      for (final path in _updateTempDirs().difference(tempBefore)) {
        await Directory(path).delete(recursive: true);
      }
    });

    test('writes update.ps1 to the temp dir as plain statements', () async {
      final downloader = UpdateDownloader(
        downloadUrl: 'http://127.0.0.1:${server.port}/update.zip',
        assetType: 'zip',
        digest: zipDigest,
        processStarter: starter.call,
        exitApp: exitCodes.add,
        appDirOverride: fakeAppDir.path,
      );

      await downloader.downloadAndInstall();

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

      expect(starter.calls, hasLength(1));
      expect(starter.calls.single.executable, 'powershell');
      expect(starter.calls.single.arguments, contains('-File'));
      expect(
        starter.calls.single.arguments,
        contains('${created.single}\\update.ps1'),
      );
      expect(exitCodes, [0]);
    });

    test('digest mismatch blocks install and cleans the temp dir', () async {
      final wrong = 'sha256:${sha256.convert([1, 2, 3])}';
      final downloader = UpdateDownloader(
        downloadUrl: 'http://127.0.0.1:${server.port}/update.zip',
        assetType: 'zip',
        digest: wrong,
        processStarter: starter.call,
        exitApp: exitCodes.add,
        appDirOverride: fakeAppDir.path,
      );

      UpdateVerificationException? caught;
      try {
        await downloader.downloadAndInstall();
      } on UpdateVerificationException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.message, contains('security check'));
      expect(caught.result.reason, 'mismatch');
      expect(starter.calls, isEmpty);
      expect(exitCodes, isEmpty);
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
