import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clipmind/data/services/import/youtube_import_service.dart';

// Phase 1 (stall watchdog + process-tree kill + typed missing-binary) and
// Phase 3 (single-flight busy guard + same-instant race arbitration):
// seam-injected fakes keep these arg-level — no yt-dlp binary is spawned.
// Cycle 12 adds per-import storage: every import creates its own uuid-v4
// folder under the real per-test output directory and removes it unless the
// download succeeded.
void main() {
  group('YouTubeImportService healthy path', () {
    test('returns filepath and reaches progress 1.0', () async {
      final baseDir = await _createTempOutputDir();
      final stdoutCtl = StreamController<List<int>>();
      String? emittedPath;
      final fake = _FakeYtDlpProcess(
        stdoutStream: stdoutCtl.stream,
        stderrStream: Stream<List<int>>.value(
          utf8.encode('[download]  50.0%\n'),
        ),
        exitCode: 0,
      );
      final treeKillCalls = <List<String>>[];
      final service = YouTubeImportService(
        stallTimeout: const Duration(seconds: 5),
        startProcess: (exe, args) async {
          expect(exe, equals('yt-dlp'));
          final folder = _outputFolderOf(args[args.indexOf('-o') + 1]);
          emittedPath = '${_normalize(folder)}/clipmind_video.mp4';
          stdoutCtl.add(utf8.encode('$emittedPath\n'));
          return fake;
        },
        runTreeKill: (exe, args) async {
          treeKillCalls.add([exe, ...args]);
          return ProcessResult(0, 0, '', '');
        },
      );

      final future = service.import('https://youtu.be/x', baseDir.path);
      final progress = <double>[];
      final errors = <String>[];
      final progressSub = service.progress.listen(progress.add);
      final errorsSub = service.errors.listen(errors.add);
      final result = await future;
      // Flush deferred broadcast emissions before asserting.
      await Future<void>.delayed(Duration.zero);
      await progressSub.cancel();
      await errorsSub.cancel();
      await stdoutCtl.close();

      expect(result, equals(emittedPath));
      expect(progress, isNotEmpty);
      expect(progress.last, equals(1.0));
      expect(errors, isEmpty);
      expect(fake.killed, isFalse);
      expect(treeKillCalls, isEmpty);
      expect(service.hasActiveProcess, isFalse);
    });
  });

  group('YouTubeImportService per-import folder', () {
    test('uses a fresh uuid folder under outputDir and returns the emitted '
        'path verbatim', () async {
      final baseDir = await _createTempOutputDir();
      String? capturedTemplate;
      final stdoutCtl = StreamController<List<int>>();
      final fake = _FakeYtDlpProcess(
        stdoutStream: stdoutCtl.stream,
        stderrStream: _neverListStream(),
        exitCode: 0,
      );
      final service = YouTubeImportService(
        startProcess: (exe, args) async {
          final index = args.indexOf('-o');
          expect(index, greaterThanOrEqualTo(0));
          capturedTemplate = args[index + 1];
          final folder = _outputFolderOf(capturedTemplate!);
          stdoutCtl.add(utf8.encode('${_normalize(folder)}/My Video.mp4\n'));
          return fake;
        },
      );

      final outcome = await _runImport(
        service,
        'https://youtu.be/x',
        baseDir.path,
      );
      await stdoutCtl.close();

      expect(capturedTemplate, isNotNull);
      final template = capturedTemplate!;
      expect(template, endsWith('/%(title)s.%(ext)s'));
      final importDir = Directory(_outputFolderOf(template));
      // Exactly one fresh uuid segment: a direct child of the passed
      // outputDir whose basename is a v4 UUID.
      expect(
        _normalize(importDir.parent.path),
        equals(_normalize(baseDir.path)),
      );
      expect(
        _uuidV4.hasMatch(_basename(importDir.path)),
        isTrue,
        reason: 'expected a uuid-v4 per-import folder: ${importDir.path}',
      );
      expect(importDir.existsSync(), isTrue);
      expect(
        outcome.result,
        equals('${_normalize(importDir.path)}/My Video.mp4'),
      );
      expect(outcome.errors, isEmpty);
    });

    test('two consecutive imports never share a folder', () async {
      final baseDir = await _createTempOutputDir();
      final folders = <String>[];
      final service = YouTubeImportService(
        startProcess: (exe, args) async {
          final folder = _outputFolderOf(args[args.indexOf('-o') + 1]);
          folders.add(folder);
          final stdoutCtl = StreamController<List<int>>();
          stdoutCtl.add(utf8.encode('$folder/video-${folders.length}.mp4\n'));
          return _FakeYtDlpProcess(
            stdoutStream: stdoutCtl.stream,
            stderrStream: _neverListStream(),
            exitCode: 0,
          );
        },
      );

      final first = await _runImport(
        service,
        'https://youtu.be/x',
        baseDir.path,
      );
      final second = await _runImport(
        service,
        'https://youtu.be/x',
        baseDir.path,
      );

      expect(first.result, isNotNull);
      expect(second.result, isNotNull);
      expect(folders, hasLength(2));
      expect(folders[0], isNot(equals(folders[1])));
      expect(Directory(folders[0]).existsSync(), isTrue);
      expect(Directory(folders[1]).existsSync(), isTrue);
      expect(first.result, equals('${folders[0]}/video-1.mp4'));
      expect(second.result, equals('${folders[1]}/video-2.mp4'));
    });

    test('failed import (non-zero exit) removes its folder', () async {
      final baseDir = await _createTempOutputDir();
      String? capturedTemplate;
      final fake = _FakeYtDlpProcess(
        stdoutStream: _neverListStream(),
        stderrStream: Stream<List<int>>.value(utf8.encode('ERROR: nope\n')),
        exitCode: 1,
      );
      final service = YouTubeImportService(
        startProcess: (exe, args) async {
          capturedTemplate = args[args.indexOf('-o') + 1];
          return fake;
        },
      );

      final outcome = await _runImport(
        service,
        'https://youtu.be/x',
        baseDir.path,
      );

      expect(outcome.result, isNull);
      final importDir = Directory(_outputFolderOf(capturedTemplate!));
      expect(importDir.existsSync(), isFalse);
      expect(baseDir.listSync(), isEmpty);
    });

    test('stalled import removes its folder', () async {
      final baseDir = await _createTempOutputDir();
      String? capturedTemplate;
      final fake = _FakeYtDlpProcess(
        stdoutStream: _neverListStream(),
        stderrStream: _neverListStream(),
      );
      final service = YouTubeImportService(
        stallTimeout: const Duration(milliseconds: 100),
        startProcess: (exe, args) async {
          capturedTemplate = args[args.indexOf('-o') + 1];
          return fake;
        },
        runTreeKill: (exe, args) async => ProcessResult(0, 0, '', ''),
      );

      final outcome = await _runImport(
        service,
        'https://youtu.be/x',
        baseDir.path,
      );

      expect(outcome.result, isNull);
      expect(
        outcome.errors.single,
        allOf(contains('stalled'), contains('no output')),
      );
      final importDir = Directory(_outputFolderOf(capturedTemplate!));
      expect(importDir.existsSync(), isFalse);
      expect(baseDir.listSync(), isEmpty);
    });

    test('unexpected error removes its folder', () async {
      final baseDir = await _createTempOutputDir();
      String? capturedTemplate;
      final service = YouTubeImportService(
        startProcess: (exe, args) async {
          capturedTemplate = args[args.indexOf('-o') + 1];
          throw StateError('boom');
        },
      );

      final outcome = await _runImport(
        service,
        'https://youtu.be/x',
        baseDir.path,
      );

      expect(outcome.result, isNull);
      expect(outcome.errors, equals(['Bad state: boom']));
      final importDir = Directory(_outputFolderOf(capturedTemplate!));
      expect(importDir.existsSync(), isFalse);
      expect(baseDir.listSync(), isEmpty);
    });
  });

  group('YouTubeImportService stall watchdog', () {
    test('hung yt-dlp triggers tree-kill plus typed stall failure', () async {
      final baseDir = await _createTempOutputDir();
      final fake = _FakeYtDlpProcess(
        stdoutStream: _neverListStream(),
        stderrStream: _neverListStream(),
      );
      final treeKillCalls = <List<String>>[];
      final service = YouTubeImportService(
        stallTimeout: const Duration(milliseconds: 100),
        startProcess: (exe, args) async => fake,
        runTreeKill: (exe, args) async {
          treeKillCalls.add([exe, ...args]);
          return ProcessResult(0, 0, '', '');
        },
      );

      final future = service.import('https://youtu.be/x', baseDir.path);
      final errors = <String>[];
      final errorsSub = service.errors.listen(errors.add);
      final sw = Stopwatch()..start();
      final result = await future;
      sw.stop();
      await Future<void>.delayed(Duration.zero);
      await errorsSub.cancel();

      expect(result, isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      expect(
        errors.single,
        allOf(contains('stalled'), contains('no output')),
      );
      // Tree-kill command issued (taskkill /T /F) plus direct kill fallback
      // so the fake child always dies.
      expect(treeKillCalls, hasLength(1));
      expect(treeKillCalls.single.first, equals('taskkill'));
      expect(treeKillCalls.single, contains('/T'));
      expect(treeKillCalls.single, contains('/F'));
      expect(fake.killed, isTrue);
      expect(service.hasActiveProcess, isFalse);
    });
  });

  group('YouTubeImportService cancel', () {
    test('cancel during in-flight import tree-kills and clears handle',
        () async {
      final baseDir = await _createTempOutputDir();
      final fake = _FakeYtDlpProcess(
        stdoutStream: _neverListStream(),
        stderrStream: _neverListStream(),
      );
      final treeKillCalls = <List<String>>[];
      final service = YouTubeImportService(
        stallTimeout: const Duration(seconds: 5),
        startProcess: (exe, args) async => fake,
        runTreeKill: (exe, args) async {
          treeKillCalls.add([exe, ...args]);
          return ProcessResult(0, 0, '', '');
        },
      );

      final future = service.import('https://youtu.be/x', baseDir.path);
      final errors = <String>[];
      final errorsSub = service.errors.listen(errors.add);
      // Let the import reach the exitCode await before cancelling.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service.hasActiveProcess, isTrue);
      service.cancel();
      // Synchronous clear: the shared handle never goes stale.
      expect(service.hasActiveProcess, isFalse);
      final result = await future;
      await Future<void>.delayed(Duration.zero);
      await errorsSub.cancel();

      expect(result, isNull);
      expect(treeKillCalls, hasLength(1));
      expect(treeKillCalls.single.first, equals('taskkill'));
      expect(fake.killed, isTrue);
      expect(service.hasActiveProcess, isFalse);
    });
  });

  group('YouTubeImportService missing binary', () {
    test('missing yt-dlp surfaces the typed actionable failure and removes '
        'the per-import folder', () async {
      final baseDir = await _createTempOutputDir();
      String? capturedTemplate;
      var started = false;
      final service = YouTubeImportService(
        stallTimeout: const Duration(seconds: 5),
        startProcess: (exe, args) async {
          started = true;
          capturedTemplate = args[args.indexOf('-o') + 1];
          throw ProcessException('yt-dlp', args, 'not found', 2);
        },
      );

      final future = service.import('https://youtu.be/x', baseDir.path);
      final errors = <String>[];
      final errorsSub = service.errors.listen(errors.add);
      final result = await future;
      await Future<void>.delayed(Duration.zero);
      await errorsSub.cancel();

      expect(started, isTrue);
      expect(result, isNull);
      expect(errors, equals([YouTubeImportService.missingBinaryMessage]));
      expect(
        errors.single,
        allOf(
          contains('yt-dlp not found'),
          contains('yt-dlp.exe'),
          isNot(contains('winget')),
          // No in-app yt-dlp path setting exists; the copy must not send
          // users looking for one.
          isNot(contains('settings')),
        ),
      );
      expect(service.hasActiveProcess, isFalse);
      // Spawn failure: the folder created before the spawn is removed.
      expect(
        Directory(_outputFolderOf(capturedTemplate!)).existsSync(),
        isFalse,
      );
      expect(baseDir.listSync(), isEmpty);
    });
  });

  group('YouTubeImportService single-flight', () {
    test('a second concurrent import during startup is rejected with the '
        'typed busy failure', () async {
      final baseDir = await _createTempOutputDir();
      final fake = _FakeYtDlpProcess(
        stdoutStream: _neverListStream(),
        stderrStream: _neverListStream(),
        exitCode: 0,
      );
      final starterGate = Completer<Process>();
      var starts = 0;
      final service = YouTubeImportService(
        stallTimeout: const Duration(seconds: 5),
        startProcess: (exe, args) {
          starts++;
          return starterGate.future;
        },
        runTreeKill: (exe, args) async => ProcessResult(0, 0, '', ''),
      );

      final first = service.import('https://youtu.be/x', baseDir.path);
      // Hold the first import in the startup window (deterministic).
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await expectLater(
        service.import('https://youtu.be/x', baseDir.path),
        throwsA(
          isA<YoutubeImportBusyException>().having(
            (e) => e.message,
            'message',
            equals(
              'YouTube import is busy — another download is already running',
            ),
          ),
        ),
      );
      // The rejected import never reached the starter.
      expect(starts, equals(1));
      starterGate.complete(fake);
      final result = await first;
      expect(result, isNull);
      expect(service.hasActiveProcess, isFalse);
    });

    test('a second concurrent import during flight is rejected with the '
        'typed busy failure', () async {
      final baseDir = await _createTempOutputDir();
      final fake = _FakeYtDlpProcess(
        stdoutStream: _neverListStream(),
        stderrStream: _neverListStream(),
      );
      final service = YouTubeImportService(
        stallTimeout: const Duration(seconds: 5),
        startProcess: (exe, args) async => fake,
        runTreeKill: (exe, args) async => ProcessResult(0, 0, '', ''),
      );

      final first = service.import('https://youtu.be/x', baseDir.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service.hasActiveProcess, isTrue);
      await expectLater(
        service.import('https://youtu.be/x', baseDir.path),
        throwsA(isA<YoutubeImportBusyException>()),
      );
      // The first import is untouched by the rejection.
      expect(service.hasActiveProcess, isTrue);
      service.cancel();
      final result = await first;
      expect(result, isNull);
      expect(service.hasActiveProcess, isFalse);
    });
  });

  group('YouTubeImportService same-instant race', () {
    test('natural exit 0 at the watchdog instant still returns the file',
        () async {
      final baseDir = await _createTempOutputDir();
      final stdoutCtl = StreamController<List<int>>();
      String? emittedPath;
      String? capturedTemplate;
      final fake = _FakeYtDlpProcess(
        stdoutStream: stdoutCtl.stream,
        stderrStream: _neverListStream(),
        // The watchdog's kill must not settle the exit code: the child
        // finishes naturally instead.
        killExitCode: null,
      );
      final treeKillCalls = <List<String>>[];
      final service = YouTubeImportService(
        stallTimeout: const Duration(milliseconds: 100),
        startProcess: (exe, args) async {
          capturedTemplate = args[args.indexOf('-o') + 1];
          final folder = _outputFolderOf(capturedTemplate!);
          emittedPath = '${_normalize(folder)}/clipmind_video.mp4';
          stdoutCtl.add(utf8.encode('$emittedPath\n'));
          return fake;
        },
        runTreeKill: (exe, args) async {
          treeKillCalls.add([exe, ...args]);
          return ProcessResult(0, 0, '', '');
        },
      );

      final future = service.import('https://youtu.be/x', baseDir.path);
      final progress = <double>[];
      final errors = <String>[];
      final progressSub = service.progress.listen(progress.add);
      final errorsSub = service.errors.listen(errors.add);
      // The filepath line arrives immediately (buffered by the fake's
      // single-subscription controller), then the child goes silent.
      // Wait until the watchdog has fired (tree-kill issued), then let the
      // child finish naturally — proving the healthy result wins over the
      // stall message in the same-instant race.
      while (treeKillCalls.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fake.completeExit(0);
      final result = await future;
      await Future<void>.delayed(Duration.zero);
      await progressSub.cancel();
      await errorsSub.cancel();
      await stdoutCtl.close();

      expect(result, equals(emittedPath));
      expect(progress.last, equals(1.0));
      expect(errors, isEmpty);
      expect(treeKillCalls, hasLength(1));
      expect(fake.killed, isTrue);
      expect(service.hasActiveProcess, isFalse);
      // Success keeps the per-import folder on disk.
      expect(Directory(_outputFolderOf(capturedTemplate!)).existsSync(), isTrue);
    });
  });

  group('YouTubeImportService checkAvailability', () {
    test('available: --version output is reported as the version', () async {
      final fake = _FakeYtDlpProcess(
        stdoutStream: Stream<List<int>>.value(utf8.encode('2026.09.05\n')),
        stderrStream: Stream<List<int>>.value(const <int>[]),
        exitCode: 0,
      );
      var probeArgs = const <String>[];
      final service = YouTubeImportService(
        startProcess: (exe, args) async {
          expect(exe, equals('yt-dlp'));
          probeArgs = args;
          return fake;
        },
      );

      final availability = await service.checkAvailability();

      expect(probeArgs, equals(const ['--version']));
      expect(availability.isAvailable, isTrue);
      expect(availability.version, equals('2026.09.05'));
      expect(availability.message, isNull);
      expect(fake.killed, isFalse);
      expect(service.hasActiveProcess, isFalse);
    });

    test('unavailable: ProcessException carries the typed message', () async {
      final service = YouTubeImportService(
        startProcess: (exe, args) async =>
            throw ProcessException('yt-dlp', args, 'not found', 2),
      );

      final availability = await service.checkAvailability();

      expect(availability.isAvailable, isFalse);
      expect(availability.version, isNull);
      expect(
        availability.message,
        equals(YouTubeImportService.missingBinaryMessage),
      );
    });

    test('unavailable: non-zero --version exit', () async {
      final fake = _FakeYtDlpProcess(
        stdoutStream: Stream<List<int>>.value(utf8.encode('boom\n')),
        stderrStream: Stream<List<int>>.value(const <int>[]),
        exitCode: 3,
      );
      final service = YouTubeImportService(
        startProcess: (exe, args) async => fake,
      );

      final availability = await service.checkAvailability();

      expect(availability.isAvailable, isFalse);
      expect(availability.version, isNull);
      expect(
        availability.message,
        equals(YouTubeImportService.missingBinaryMessage),
      );
    });

    test('unavailable: hung probe times out and the child is killed',
        () async {
      final fake = _FakeYtDlpProcess(
        stdoutStream: _neverListStream(),
        stderrStream: _neverListStream(),
      );
      final service = YouTubeImportService(
        probeTimeout: const Duration(milliseconds: 100),
        startProcess: (exe, args) async => fake,
      );

      final sw = Stopwatch()..start();
      final availability = await service.checkAvailability();
      sw.stop();

      expect(availability.isAvailable, isFalse);
      expect(availability.version, isNull);
      expect(
        availability.message,
        equals(YouTubeImportService.missingBinaryMessage),
      );
      expect(fake.killed, isTrue);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('unavailable: unexpected starter failure never escapes', () async {
      final service = YouTubeImportService(
        startProcess: (exe, args) async => throw StateError('boom'),
      );

      final availability = await service.checkAvailability();

      expect(availability.isAvailable, isFalse);
      expect(
        availability.message,
        equals(YouTubeImportService.missingBinaryMessage),
      );
    });
  });

  group('YouTubeImportService URL validation', () {
    test('empty input is rejected without spawning or creating a folder',
        () async {
      final baseDir = await _createTempOutputDir();
      var starts = 0;
      final service = YouTubeImportService(
        startProcess: (exe, args) async {
          starts++;
          throw StateError('must not spawn for invalid input');
        },
      );

      final outcome = await _runImport(service, '', baseDir.path);

      expect(starts, isZero);
      expect(outcome.result, isNull);
      expect(outcome.errors, equals([YouTubeImportService.invalidUrlMessage]));
      expect(service.hasActiveProcess, isFalse);
      expect(baseDir.listSync(), isEmpty);
    });

    test('option-like input is rejected without spawning', () async {
      final baseDir = await _createTempOutputDir();
      var starts = 0;
      final service = YouTubeImportService(
        startProcess: (exe, args) async {
          starts++;
          throw StateError('must not spawn for invalid input');
        },
      );

      final outcome = await _runImport(service, '--exec=calc', baseDir.path);

      expect(starts, isZero);
      expect(outcome.result, isNull);
      expect(outcome.errors, equals([YouTubeImportService.invalidUrlMessage]));
      expect(service.hasActiveProcess, isFalse);
      expect(baseDir.listSync(), isEmpty);
    });

    test('non-http scheme is rejected without spawning', () async {
      final baseDir = await _createTempOutputDir();
      var starts = 0;
      final service = YouTubeImportService(
        startProcess: (exe, args) async {
          starts++;
          throw StateError('must not spawn for invalid input');
        },
      );

      final outcome = await _runImport(
        service,
        'file:///tmp/x.mp4',
        baseDir.path,
      );

      expect(starts, isZero);
      expect(outcome.result, isNull);
      expect(outcome.errors, equals([YouTubeImportService.invalidUrlMessage]));
      expect(service.hasActiveProcess, isFalse);
      expect(baseDir.listSync(), isEmpty);
    });

    test('valid https URL spawns with -- before the URL', () async {
      final baseDir = await _createTempOutputDir();
      final capturedArgs = <String>[];
      final stdoutCtl = StreamController<List<int>>();
      String? emittedPath;
      final fake = _FakeYtDlpProcess(
        stdoutStream: stdoutCtl.stream,
        stderrStream: Stream<List<int>>.value(
          utf8.encode('[download] 100%\n'),
        ),
        exitCode: 0,
      );
      final service = YouTubeImportService(
        startProcess: (exe, args) async {
          expect(exe, equals('yt-dlp'));
          capturedArgs.addAll(args);
          final folder = _outputFolderOf(args[args.indexOf('-o') + 1]);
          emittedPath = '${_normalize(folder)}/clipmind_video.mp4';
          stdoutCtl.add(utf8.encode('$emittedPath\n'));
          return fake;
        },
      );

      final outcome = await _runImport(
        service,
        'https://youtu.be/x',
        baseDir.path,
      );
      await stdoutCtl.close();

      expect(outcome.result, equals(emittedPath));
      expect(outcome.errors, isEmpty);
      expect(capturedArgs, contains('after_move:filepath'));
      // The end-of-options separator must sit immediately before the URL
      // so a valid link can never be parsed as a yt-dlp option.
      final separator = capturedArgs.indexOf('--');
      expect(separator, greaterThanOrEqualTo(0));
      expect(capturedArgs[separator + 1], equals('https://youtu.be/x'));
      expect(capturedArgs.last, equals('https://youtu.be/x'));
    });
  });
}

/// Creates a real per-test output base directory and registers its
/// recursive deletion. The service writes only inside child folders of this
/// base, so tests can assert folder creation and cleanup directly.
Future<Directory> _createTempOutputDir() async {
  final dir = await Directory.systemTemp.createTemp('yt_import_');
  addTearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });
  return dir;
}

/// The per-import folder encoded in the `-o` output template
/// (`<folder>/%(title)s.%(ext)s`).
String _outputFolderOf(String outputTemplate) =>
    outputTemplate.substring(0, outputTemplate.lastIndexOf('/'));

String _normalize(String path) => path.replaceAll('\\', '/');

String _basename(String path) => _normalize(path).split('/').last;

/// v4 UUIDs only (version nibble 4, variant nibble 8/9/a/b).
final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Runs [YouTubeImportService.import] with the production consumer pattern
/// — subscribe right after the call, before awaiting — and returns the
/// settled result plus every error emitted.
Future<({String? result, List<String> errors})> _runImport(
  YouTubeImportService service,
  String url,
  String outputDir,
) async {
  final pending = service.import(url, outputDir);
  final errors = <String>[];
  final subscription = service.errors.listen(errors.add);
  final result = await pending;
  // Flush deferred broadcast emissions before asserting.
  await Future<void>.delayed(Duration.zero);
  await subscription.cancel();
  return (result: result, errors: errors);
}

/// Never-emitting, never-closing byte stream: simulates a hung yt-dlp
/// whose stdout/stderr pipes go silent.
Stream<List<int>> _neverListStream() => StreamController<List<int>>().stream;

/// Minimal fake for the `startProcess` seam: exposes controllable
/// stdout/stderr streams, records [kill], settles a pending exit code on
/// kill (like a real child dying) unless [killExitCode] is null, and never
/// spawns yt-dlp.
class _FakeYtDlpProcess implements Process {
  _FakeYtDlpProcess({
    required this.stdoutStream,
    required this.stderrStream,
    int? exitCode,
    this.killExitCode = 1,
  }) {
    if (exitCode != null) _exitCompleter.complete(exitCode);
  }

  final Stream<List<int>> stdoutStream;
  final Stream<List<int>> stderrStream;

  /// Exit code the kill path settles (like a real child dying); null keeps
  /// the exit code pending so a test can model a natural exit instead.
  final int? killExitCode;

  final Completer<int> _exitCompleter = Completer<int>();

  bool killed = false;

  @override
  int get pid => 4242;

  @override
  Stream<List<int>> get stdout => stdoutStream;

  @override
  Stream<List<int>> get stderr => stderrStream;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    final code = killExitCode;
    if (code != null && !_exitCompleter.isCompleted) {
      _exitCompleter.complete(code);
    }
    return true;
  }

  /// Test helper: settle the exit code manually (models a natural exit).
  void completeExit(int code) {
    if (!_exitCompleter.isCompleted) _exitCompleter.complete(code);
  }
}
