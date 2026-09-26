import 'package:flutter_test/flutter_test.dart';

import '../../../tool/smoke/windows_release_smoke.dart' as smoke;

void main() {
  group('Windows release smoke report validation', () {
    test('accepts the exact successful smoke report', () {
      final validated = smoke.validateSmokeReport(_successfulReport());

      expect(validated, _successfulReport());
      expect(validated.keys, unorderedEquals(_successfulReport().keys));
    });

    final rejectionCases = <String, Object?>{
      'a non-map value': <Object?>['untrusted-secret-value'],
      'a report with a missing key': <String, Object?>{
        'projectLoaded': true,
        'providersRendered': true,
        'timelineRendered': true,
      },
      'a report with an extra key': <String, Object?>{
        ..._successfulReport(),
        'unexpected': true,
      },
      'a false success flag': <String, Object?>{
        ..._successfulReport(),
        'timelineRendered': false,
      },
      'a non-boolean success flag': <String, Object?>{
        ..._successfulReport(),
        'providersRendered': 'true',
      },
      'a non-null error': <String, Object?>{
        ..._successfulReport(),
        'flutterError': 'untrusted-secret-value',
      },
      'a path-bearing error': <String, Object?>{
        ..._successfulReport(),
        'flutterError': r'C:\restricted\smoke-report.json',
      },
    };

    for (final entry in rejectionCases.entries) {
      test('rejects ${entry.key} without echoing raw input', () {
        StateError? caught;
        try {
          smoke.validateSmokeReport(entry.value);
        } on StateError catch (error) {
          caught = error;
        }

        expect(caught, isNotNull);
        final message = caught!.message.toString();
        expect(message, isNot(contains('untrusted-secret-value')));
        expect(message, isNot(contains(r'C:\restricted\smoke-report.json')));
      });
    }
  });
}

Map<String, Object?> _successfulReport() => <String, Object?>{
  'projectLoaded': true,
  'providersRendered': true,
  'timelineRendered': true,
  'flutterError': null,
};
