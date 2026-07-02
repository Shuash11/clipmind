import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/stage_1_input_validation.dart';

void main() {
  group('InputValidator.validate', () {
    test('returns failure for empty input', () {
      final (cmd, failure) = InputValidator.validate('', null);
      expect(cmd, isNull);
      expect(failure, isNotNull);
      expect(failure!.message, contains('cannot be empty'));
    });

    test('returns failure for whitespace-only input', () {
      final (cmd, failure) = InputValidator.validate('   ', null);
      expect(cmd, isNull);
      expect(failure, isNotNull);
      expect(failure!.message, contains('cannot be empty'));
    });

    test('returns failure for input exceeding max length', () {
      final longInput = 'a' * (InputValidator.maxPromptLength + 1);
      final (cmd, failure) = InputValidator.validate(longInput, null);
      expect(cmd, isNull);
      expect(failure, isNotNull);
      expect(failure!.message, contains('exceeds'));
    });

    test('accepts input at max length boundary', () {
      final exactInput = 'a' * InputValidator.maxPromptLength;
      final (cmd, failure) = InputValidator.validate(exactInput, null);
      expect(cmd, isNotNull);
      expect(failure, isNull);
    });

    test('returns ValidatedCommand for valid input', () {
      final (cmd, failure) = InputValidator.validate('Trim the first 10 seconds', null);
      expect(cmd, isNotNull);
      expect(failure, isNull);
      expect(cmd!.text, equals('Trim the first 10 seconds'));
    });

    test('normalizes timecodes from input', () {
      final (cmd, _) = InputValidator.validate('Trim from 5s to 30s', null);
      expect(cmd, isNotNull);
      expect(cmd!.normalizedTimecodes, isNotEmpty);
      expect(cmd.normalizedTimecodes['5s'], equals(5000));
      expect(cmd.normalizedTimecodes['30s'], equals(30000));
    });

    test('normalizes timecode formats (HH:MM:SS.mmm)', () {
      final (cmd, _) = InputValidator.validate('Cut from 00:01:30.500 to 00:02:00', null);
      expect(cmd, isNotNull);
      expect(cmd!.normalizedTimecodes['00:01:30.500'], equals(90500));
      expect(cmd.normalizedTimecodes['00:02:00'], equals(120000));
    });

    test('normalizes minutes format', () {
      final (cmd, _) = InputValidator.validate('Skip 2min', null);
      expect(cmd, isNotNull);
      expect(cmd!.normalizedTimecodes['2min'], equals(120000));
    });

    test('populates project snapshot from metadata', () {
      const metadata = VideoMetadata(
        durationMs: 120000,
        width: 1920,
        height: 1080,
        fps: 30.0,
        codec: 'h264',
        hasAudio: true,
        bitrate: 5000000,
      );
      final (cmd, _) = InputValidator.validate('Trim to 30 seconds', metadata);
      expect(cmd, isNotNull);
      final snapshot = cmd!.projectSnapshot;
      expect(snapshot.durationMs, equals(120000));
      expect(snapshot.width, equals(1920));
      expect(snapshot.height, equals(1080));
      expect(snapshot.fps, equals(30.0));
      expect(snapshot.codec, equals('h264'));
      expect(snapshot.hasAudio, isTrue);
    });

    test('trims whitespace from input', () {
      final (cmd, _) = InputValidator.validate('  hello world  ', null);
      expect(cmd, isNotNull);
      expect(cmd!.text, equals('hello world'));
    });

    test('ignores non-timecode words', () {
      final (cmd, _) = InputValidator.validate('Add a title at the beginning', null);
      expect(cmd, isNotNull);
      expect(cmd!.normalizedTimecodes, isEmpty);
    });
  });
}
