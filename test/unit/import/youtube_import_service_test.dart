import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clipmind/data/services/import/youtube_import_service.dart';

// Phase 1 (stall watchdog + process-tree kill + typed missing-binary):
// seam-injected fakes keep these arg-level — no yt-dlp binary is spawned.
void main() {
  group('YouTubeImportService healthy path', () {
    test('returns filepath and reaches progress 1.0', () async {
      final fake = _FakeYtDlpProcess(
        stdoutStream: Stream<List<int>>.value(
          utf8.encode('/tmp/clipmind_video.mp4\n'),
        ),
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
          return fake;
        },
        runTreeKill: (exe, args) async {
          treeKillCalls.add([exe, ...args]);
          return ProcessResult(0, 0, '', '');
        },
      );

      final future = service.import('https://youtu.be/x', '/tmp');
      final progress = <double>[];
      final errors = <String>[];
      final progressSub = service.progress.listen(progress.add);
      final errorsSub = service.errors.listen(errors.add);
      final result = await future;
      // Flush deferred broadcast emissions before asserting.
      await Future<void>.delayed(Duration.zero);
      await progressSub.cancel();
      await errorsSub.cancel();

      expect(result, equals('/tmp/clipmind_video.mp4'));
      expect(progress, isNotEmpty);
      expect(progress.last, equals(1.0));
      expect(errors, isEmpty);
      expect(fake.killed, isFalse);
      expect(treeKillCalls, isEmpty);
      expect(service.hasActiveProcess, isFalse);
    });
  });

  group('YouTubeImportService stall watchdog', () {
    test('hung yt-dlp triggers tree-kill plus typed stall failure', () async {
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

      final future = service.import('https://youtu.be/x', '/tmp');
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

      final future = service.import('https://youtu.be/x', '/tmp');
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
    test('missing yt-dlp surfaces the typed actionable failure', () async {
      var started = false;
      final service = YouTubeImportService(
        stallTimeout: const Duration(seconds: 5),
        startProcess: (exe, args) async {
          started = true;
          throw ProcessException('yt-dlp', args, 'not found', 2);
        },
      );

      final future = service.import('https://youtu.be/x', '/tmp');
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
        allOf(contains('yt-dlp not found'), contains('winget')),
      );
      expect(service.hasActiveProcess, isFalse);
    });
  });
}

/// Never-emitting, never-closing byte stream: simulates a hung yt-dlp
/// whose stdout/stderr pipes go silent.
Stream<List<int>> _neverListStream() => StreamController<List<int>>().stream;

/// Minimal fake for the `startProcess` seam: exposes controllable
/// stdout/stderr streams, records [kill], completes a pending exitCode on
/// kill (like a real child dying), and never spawns yt-dlp.
class _FakeYtDlpProcess implements Process {
  _FakeYtDlpProcess({
    required this.stdoutStream,
    required this.stderrStream,
    int? exitCode,
  }) {
    if (exitCode != null) _exitCompleter.complete(exitCode);
  }

  final Stream<List<int>> stdoutStream;
  final Stream<List<int>> stderrStream;
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
    if (!_exitCompleter.isCompleted) _exitCompleter.complete(1);
    return true;
  }
}
