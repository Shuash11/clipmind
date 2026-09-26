import 'dart:convert';
import 'dart:io';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/runtime/local_smoke_launch_configuration.dart';
import 'package:clipmind/core/runtime/local_smoke_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

int _pathSequence = 0;

void main() {
  group('LocalSmokeLaunchConfiguration.parse', () {
    test(
      'returns typed absolute fixture and report files for a valid launch',
      () async {
        final fixture = await _unusedSystemTempFile('.cmproj');
        final report = await _unusedSystemTempFile('.json');
        addTearDown(() => _deleteIfPresent(fixture));
        addTearDown(() => _deleteIfPresent(report));
        await fixture.writeAsString('{"project":"smoke"}', flush: true);

        final Result<LocalSmokeLaunchConfiguration> parsed =
            LocalSmokeLaunchConfiguration.parse(<String>[
              '--clipmind-local-smoke',
              '--fixture=${fixture.path}',
              '--report=${report.path}',
            ]);

        expect(parsed, isA<Success<LocalSmokeLaunchConfiguration>>());
        final configuration =
            (parsed as Success<LocalSmokeLaunchConfiguration>).value;
        expect(configuration.fixture.absolute.path, fixture.absolute.path);
        expect(configuration.report.absolute.path, report.absolute.path);
        expect(await configuration.fixture.exists(), isTrue);
        expect(await configuration.report.exists(), isFalse);
      },
    );

    test('rejects malformed, duplicate, and unsafe launch arguments', () async {
      final fixture = await _unusedSystemTempFile('.cmproj');
      final existingReport = await _unusedSystemTempFile('.json');
      final missingFixture = await _unusedSystemTempFile('.cmproj');
      final wrongExtensionFixture = await _unusedSystemTempFile('.json');
      final nonRegularFixture = Directory(
        '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}'
        '${_tempStem('not-a-file')}.cmproj',
      );
      final validReport = await _unusedSystemTempFile('.json');
      final wrongExtensionReport = await _unusedSystemTempFile('.txt');
      final nestedReport = File(
        '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}'
        '${_tempStem('nested')}${Platform.pathSeparator}report.json',
      );
      final outsideSystemTempReport = File(
        '${Directory.systemTemp.absolute.parent.path}${Platform.pathSeparator}'
        '${_tempStem('outside')}.json',
      );
      final lexicalEscapeReport = File(
        '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}..'
        '${Platform.pathSeparator}${_tempStem('escaped')}.json',
      );
      addTearDown(() => _deleteIfPresent(fixture));
      addTearDown(() => _deleteIfPresent(existingReport));
      addTearDown(() => _deleteDirectoryIfPresent(nonRegularFixture));
      await fixture.writeAsString('{"project":"smoke"}', flush: true);
      await existingReport.writeAsString('do-not-replace', flush: true);
      await nonRegularFixture.create();

      List<String> validArguments({File? report}) => <String>[
        '--clipmind-local-smoke',
        '--fixture=${fixture.path}',
        '--report=${(report ?? validReport).path}',
      ];

      final cases = <String, List<String>>{
        'absent marker': validArguments()..removeAt(0),
        'duplicate marker': <String>[
          '--clipmind-local-smoke',
          ...validArguments(),
        ],
        'missing fixture option': <String>[
          '--clipmind-local-smoke',
          '--report=${validReport.path}',
        ],
        'missing report option': <String>[
          '--clipmind-local-smoke',
          '--fixture=${fixture.path}',
        ],
        'duplicate fixture option': <String>[
          ...validArguments(),
          '--fixture=${fixture.path}',
        ],
        'duplicate report option': <String>[
          ...validArguments(),
          '--report=${validReport.path}',
        ],
        'unknown argument': <String>[...validArguments(), '--unexpected=value'],
        'relative fixture': <String>[
          '--clipmind-local-smoke',
          '--fixture=relative.cmproj',
          '--report=${validReport.path}',
        ],
        'missing fixture': <String>[
          '--clipmind-local-smoke',
          '--fixture=${missingFixture.path}',
          '--report=${validReport.path}',
        ],
        'wrong fixture extension': <String>[
          '--clipmind-local-smoke',
          '--fixture=${wrongExtensionFixture.path}',
          '--report=${validReport.path}',
        ],
        'non-regular fixture': <String>[
          '--clipmind-local-smoke',
          '--fixture=${nonRegularFixture.path}',
          '--report=${validReport.path}',
        ],
        'relative report': <String>[
          '--clipmind-local-smoke',
          '--fixture=${fixture.path}',
          '--report=report.json',
        ],
        'existing report': validArguments(report: existingReport),
        'wrong report extension': validArguments(report: wrongExtensionReport),
        'nested system-temp report': validArguments(report: nestedReport),
        'outside system-temp report': validArguments(
          report: outsideSystemTempReport,
        ),
        'lexically escaped report': validArguments(report: lexicalEscapeReport),
      };

      for (final entry in cases.entries) {
        final Result<LocalSmokeLaunchConfiguration> parsed =
            LocalSmokeLaunchConfiguration.parse(entry.value);
        expect(
          parsed,
          isA<Failure<LocalSmokeLaunchConfiguration>>(),
          reason: entry.key,
        );
        expect(
          (parsed as Failure<LocalSmokeLaunchConfiguration>).error,
          isA<AppFailure>(),
          reason: entry.key,
        );
      }
    });
  });

  group('FileLocalSmokeReporter', () {
    test(
      'exclusively writes and flushes the exact smoke report schema',
      () async {
        final reportFile = await _unusedSystemTempFile('.json');
        addTearDown(() => _deleteIfPresent(reportFile));
        final LocalSmokeReporter reporter = FileLocalSmokeReporter(reportFile);
        final report = <String, Object?>{
          'projectLoaded': true,
          'providersRendered': true,
          'timelineRendered': true,
          'flutterError': null,
        };

        await reporter.write(report);

        final decoded = jsonDecode(await reportFile.readAsString());
        expect(decoded, isA<Map<String, dynamic>>());
        expect(decoded, equals(report));
      },
    );

    test('rejects an existing report without changing its bytes', () async {
      final reportFile = await _unusedSystemTempFile('.json');
      addTearDown(() => _deleteIfPresent(reportFile));
      await reportFile.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
      final sentinel = await reportFile.readAsBytes();
      final LocalSmokeReporter reporter = FileLocalSmokeReporter(reportFile);

      await expectLater(
        reporter.write(<String, Object?>{
          'projectLoaded': true,
          'providersRendered': true,
          'timelineRendered': true,
          'flutterError': null,
        }),
        throwsA(isA<FileSystemException>()),
      );

      expect(await reportFile.readAsBytes(), sentinel);
    });
  });
}

Future<File> _unusedSystemTempFile(String extension) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final file = File(
      '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}'
      '${_tempStem('clipmind-local-smoke')}$extension',
    );
    if (!await file.exists()) return file;
  }
  throw StateError('Could not allocate an unused system-temp test path.');
}

String _tempStem(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_pathSequence++}';

Future<void> _deleteIfPresent(File file) async {
  if (await file.exists()) await file.delete();
}

Future<void> _deleteDirectoryIfPresent(Directory directory) async {
  if (await directory.exists()) await directory.delete(recursive: true);
}
