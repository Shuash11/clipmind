import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/utils/timecode_utils.dart';

void main() {
  group('TimecodeUtils.parseToMilliseconds', () {
    test('parses seconds format "30s"', () {
      expect(TimecodeUtils.parseToMilliseconds('30s'), equals(30000));
    });

    test('parses seconds format "10 seconds"', () {
      expect(TimecodeUtils.parseToMilliseconds('10 seconds'), equals(10000));
    });

    test('parses seconds format "5 second"', () {
      expect(TimecodeUtils.parseToMilliseconds('5 second'), equals(5000));
    });

    test('parses seconds with decimal "1.5s"', () {
      expect(TimecodeUtils.parseToMilliseconds('1.5s'), equals(1500));
    });

    test('parses minutes format "2min"', () {
      expect(TimecodeUtils.parseToMilliseconds('2min'), equals(120000));
    });

    test('parses minutes format "5 minutes"', () {
      expect(TimecodeUtils.parseToMilliseconds('5 minutes'), equals(300000));
    });

    test('parses minutes format "1 minute"', () {
      expect(TimecodeUtils.parseToMilliseconds('1 minute'), equals(60000));
    });

    test('parses minutes with decimal "1.5m"', () {
      expect(TimecodeUtils.parseToMilliseconds('1.5m'), equals(90000));
    });

    test('parses MM:SS format', () => _tc('01:30', equals(90000)));

    test('parses MM:SS.mmm format', () => _tc('01:30.500', equals(90500)));

    test('parses HH:MM:SS format', () => _tc('01:30:00', equals(5400000)));

    test('parses HH:MM:SS.mmm format', () => _tc('01:30:00.250', equals(5400250)));

    test('returns null for non-timecode string', () {
      expect(TimecodeUtils.parseToMilliseconds('hello'), isNull);
    });

    test('returns null for empty string', () {
      expect(TimecodeUtils.parseToMilliseconds(''), isNull);
    });

    test('returns null for random number without suffix', () {
      expect(TimecodeUtils.parseToMilliseconds('123'), isNull);
    });

    test('is case insensitive', () {
      expect(TimecodeUtils.parseToMilliseconds('30S'), equals(30000));
      expect(TimecodeUtils.parseToMilliseconds('2MIN'), equals(120000));
    });

    test('trims whitespace', () {
      expect(TimecodeUtils.parseToMilliseconds('  30s  '), equals(30000));
    });
  });

  group('TimecodeUtils.formatMs', () {
    test('formats MM:SS for values under 1 hour', () {
      expect(TimecodeUtils.formatMs(65000), equals('01:05'));
    });

    test('includes hours when >= 1 hour', () {
      expect(TimecodeUtils.formatMs(3661000), equals('01:01:01.000'));
    });

    test('pad zeros correctly', () {
      expect(TimecodeUtils.formatMs(1000), equals('00:01'));
    });

    test('handles 0', () {
      expect(TimecodeUtils.formatMs(0), equals('00:00'));
    });
  });

  group('TimecodeUtils.formatShort', () {
    test('formats MM:SS without milliseconds', () {
      expect(TimecodeUtils.formatShort(65000), equals('01:05'));
      expect(TimecodeUtils.formatShort(0), equals('00:00'));
      expect(TimecodeUtils.formatShort(3660000), equals('61:00'));
    });

    test('rounds down seconds', () {
      expect(TimecodeUtils.formatShort(1500), equals('00:01'));
      expect(TimecodeUtils.formatShort(100), equals('00:00'));
    });
  });
}

void _tc(String input, Matcher matcher) {
  expect(TimecodeUtils.parseToMilliseconds(input), matcher);
}
