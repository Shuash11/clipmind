import 'dart:convert';
import 'dart:io';

const _invalidReportMessage = 'Invalid local smoke report.';
const _harnessFailureMessage = 'Windows release smoke failed.';
const _cleanupTimeout = Duration(seconds: 2);

const _reportKeys = <String>{
  'projectLoaded',
  'providersRendered',
  'timelineRendered',
  'flutterError',
};

Map<String, Object?> validateSmokeReport(Object? decoded) {
  try {
    if (decoded is! Map ||
        decoded.length != _reportKeys.length ||
        !decoded.keys.every(
          (key) => key is String && _reportKeys.contains(key),
        ) ||
        decoded['projectLoaded'] != true ||
        decoded['providersRendered'] != true ||
        decoded['timelineRendered'] != true ||
        decoded['flutterError'] != null) {
      throw StateError(_invalidReportMessage);
    }

    return <String, Object?>{
      'projectLoaded': true,
      'providersRendered': true,
      'timelineRendered': true,
      'flutterError': null,
    };
  } catch (_) {
    throw StateError(_invalidReportMessage);
  }
}

Future<Map<String, Object?>> waitForSmokeReport(
  File report, {
  Duration timeout = const Duration(seconds: 30),
  Duration pollInterval = const Duration(milliseconds: 50),
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    while (true) {
      final remaining = timeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) break;

      try {
        final exists = await report.exists().timeout(remaining);
        if (exists) {
          final readRemaining = timeout - stopwatch.elapsed;
          if (readRemaining <= Duration.zero) break;
          final contents = await report.readAsString().timeout(readRemaining);
          if (contents.trim().isNotEmpty) {
            return validateSmokeReport(jsonDecode(contents));
          }
        }
      } catch (_) {
        // The writer may have created the file before its JSON is complete.
      }

      final delayRemaining = timeout - stopwatch.elapsed;
      if (delayRemaining <= Duration.zero) break;
      final delay = pollInterval <= Duration.zero
          ? Duration.zero
          : pollInterval < delayRemaining
          ? pollInterval
          : delayRemaining;
      await Future<void>.delayed(delay);
    }
  } finally {
    stopwatch.stop();
  }
  throw StateError(_invalidReportMessage);
}

Future<Map<String, Object?>> runWindowsReleaseSmoke({
  File? executable,
  File? fixture,
  Duration timeout = const Duration(seconds: 30),
}) async {
  Process? process;
  File? report;
  Future<void> Function()? closeStreams;

  try {
    final root = _repositoryRoot();
    final executableFile = executable == null
        ? File(
            '${root.path}${Platform.pathSeparator}'
            'build${Platform.pathSeparator}windows${Platform.pathSeparator}'
            'x64${Platform.pathSeparator}runner${Platform.pathSeparator}'
            'Release${Platform.pathSeparator}clipmind.exe',
          )
        : File(executable.absolute.path);
    final fixtureFile = fixture == null
        ? File(
            '${root.path}${Platform.pathSeparator}'
            'test${Platform.pathSeparator}fixtures${Platform.pathSeparator}'
            'projects${Platform.pathSeparator}'
            'legacy_v1_smoke_project.cmproj',
          )
        : File(fixture.absolute.path);

    if (!_isRegularFile(executableFile) ||
        !_isRegularFile(fixtureFile) ||
        !fixtureFile.path.toLowerCase().endsWith('.cmproj')) {
      throw StateError(_harnessFailureMessage);
    }

    report = _allocateReportPath();
    process = await Process.start(
      executableFile.path,
      <String>[
        '--clipmind-local-smoke',
        '--fixture=${fixtureFile.path}',
        '--report=${report.path}',
      ],
      workingDirectory: root.path,
      runInShell: false,
    );
    final stdoutDrain = process.stdout.listen((_) {}, onError: (_) {});
    final stderrDrain = process.stderr.listen((_) {}, onError: (_) {});
    closeStreams = () async {
      await _awaitSilently(stdoutDrain.cancel());
      await _awaitSilently(stderrDrain.cancel());
    };

    final reportData = await waitForSmokeReport(report, timeout: timeout);
    return validateSmokeReport(reportData);
  } catch (_) {
    throw StateError(_harnessFailureMessage);
  } finally {
    await _cleanupProcess(process, closeStreams);
    await _deleteReport(report);
  }
}

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.isNotEmpty) throw StateError(_harnessFailureMessage);
    await runWindowsReleaseSmoke();
    stdout.writeln('Windows release smoke PASS.');
  } catch (_) {
    exitCode = 1;
  }
}

Directory _repositoryRoot() {
  var directory = Directory.current.absolute;
  for (var depth = 0; depth < 8; depth++) {
    if (_isRegularFile(
      File('${directory.path}${Platform.pathSeparator}pubspec.yaml'),
    )) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError(_harnessFailureMessage);
}

File _allocateReportPath() {
  final temporaryDirectory = Directory.systemTemp.absolute;
  final prefix =
      'clipmind-windows-release-smoke-'
      '${DateTime.now().microsecondsSinceEpoch}';
  for (var attempt = 0; attempt < 20; attempt++) {
    final report = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      '$prefix-$attempt.json',
    );
    if (_isMissing(report)) return report;
  }
  throw StateError(_harnessFailureMessage);
}

bool _isRegularFile(File file) {
  try {
    return FileSystemEntity.typeSync(file.path, followLinks: false) ==
        FileSystemEntityType.file;
  } on FileSystemException {
    return false;
  }
}

bool _isMissing(File file) {
  try {
    return FileSystemEntity.typeSync(file.path, followLinks: false) ==
        FileSystemEntityType.notFound;
  } on FileSystemException {
    return false;
  }
}

Future<void> _cleanupProcess(
  Process? process,
  Future<void> Function()? closeStreams,
) async {
  if (process != null) {
    try {
      process.kill();
    } catch (_) {
      // Cleanup is best effort and must not expose process details.
    }
    try {
      await process.exitCode.timeout(_cleanupTimeout);
    } catch (_) {
      // Do not let a stuck process delay cleanup indefinitely.
    }
  }
  if (closeStreams != null) {
    try {
      await closeStreams();
    } catch (_) {
      // Output draining must not block shutdown or expose stream contents.
    }
  }
}

Future<void> _awaitSilently(Future<void> future) async {
  try {
    await future.timeout(_cleanupTimeout);
  } catch (_) {
    // Output draining must not block shutdown or expose stream contents.
  }
}

Future<void> _deleteReport(File? report) async {
  if (report == null) return;
  try {
    if (await report.exists()) await report.delete();
  } catch (_) {
    // The report contains no durable result and is removed when possible.
  }
}
