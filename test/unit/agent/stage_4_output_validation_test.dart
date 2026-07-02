import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/domain/agent/stage_4_output_validation.dart';

void main() {
  group('OutputValidator.validateJson', () {
    test('returns empty errors for valid JSON with trim operation', () {
      final json = '''
{
  "operations": [
    {
      "id": "op1",
      "type": "trim",
      "target_clip_id": "clip1",
      "params": { "start": "00:00:05", "end": "00:00:30" }
    }
  ],
  "summary": "Trimmed video"
}
''';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isEmpty);
    });

    test('catches malformed JSON', () {
      final errors = OutputValidator.validateJson('{invalid json}');
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Invalid JSON'));
    });

    test('catches missing operations field with no clarification', () {
      final json = '{}';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('no operations'));
    });

    test('catches empty operations with no clarification', () {
      final json = '{"operations": [], "summary": ""}';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('no operations'));
    });

    test('accepts empty operations with clarification', () {
      final json = '{"operations": [], "summary": "", "clarification_needed": "What duration?"}';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isEmpty);
    });

    test('catches missing operation id', () {
      final json = '''
{
  "operations": [
    { "type": "trim", "target_clip_id": "clip1", "params": {} }
  ],
  "summary": "test"
}
''';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('missing or empty id'));
    });

    test('catches duplicate operation ids', () {
      final json = '''
{
  "operations": [
    { "id": "op1", "type": "trim", "target_clip_id": "clip1", "params": {} },
    { "id": "op1", "type": "mute", "target_clip_id": "clip1", "params": {} }
  ],
  "summary": "test"
}
''';
      final errors = OutputValidator.validateJson(json);
      expect(errors.any((e) => e.contains('duplicate')), isTrue);
    });

    test('catches invalid operation type', () {
      final json = '''
{
  "operations": [
    { "id": "op1", "type": "invalid_op", "target_clip_id": "clip1", "params": {} }
  ],
  "summary": "test"
}
''';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('invalid type'));
    });

    test('catches missing required param', () {
      final json = '''
{
  "operations": [
    { "id": "op1", "type": "trim", "target_clip_id": "clip1", "params": { "start": "00:00" } }
  ],
  "summary": "test"
}
''';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('missing required param "end"'));
    });

    test('catches missing target_clip_id', () {
      final json = '''
{
  "operations": [
    { "id": "op1", "type": "trim", "params": { "start": "0", "end": "10" } }
  ],
  "summary": "test"
}
''';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('missing target_clip_id'));
    });

    test('catches trim end before start', () {
      final json = '''
{
  "operations": [
    {
      "id": "op1",
      "type": "trim",
      "target_clip_id": "clip1",
      "params": { "start": "00:00:30", "end": "00:00:05" }
    }
  ],
  "summary": "test"
}
''';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('must be after start'));
    });

    test('detects duplicate conflict operations (change_format)', () {
      final json = '''
{
  "operations": [
    { "id": "op1", "type": "change_format", "target_clip_id": "clip1", "params": { "target_ext": "mp4" } },
    { "id": "op2", "type": "change_format", "target_clip_id": "clip2", "params": { "target_ext": "webm" } }
  ],
  "summary": "test"
}
''';
      final errors = OutputValidator.validateJson(json);
      expect(errors.any((e) => e.contains('Conflict')), isTrue);
    });

    test('accepts valid merge operation', () {
      final json = '''
{
  "operations": [
    { "id": "op1", "type": "merge", "target_clip_id": "clip1", "params": { "clip_ids": ["clip2", "clip3"] } }
  ],
  "summary": "Merge clips"
}
''';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isEmpty);
    });

    test('accepts valid overlay_text operation', () {
      final json = '''
{
  "operations": [
    { "id": "op1", "type": "overlay_text", "target_clip_id": "clip1", "params": { "text": "Hello" } }
  ],
  "summary": "Add text"
}
''';
      final errors = OutputValidator.validateJson(json);
      expect(errors, isEmpty);
    });
  });

  group('OutputValidator.validate (with return types)', () {
    test('returns EditOperationSet for valid JSON', () {
      final json = '''
{
  "operations": [
    { "id": "op1", "type": "trim", "target_clip_id": "clip1", "params": { "start": "0", "end": "10" } }
  ],
  "summary": "Trimmed"
}
''';
      final (set, failure, clarification) = OutputValidator.validate(json);
      expect(set, isNotNull);
      expect(failure, isNull);
      expect(clarification, isNull);
      expect(set!.operations.length, equals(1));
      expect(set.summary, equals('Trimmed'));
    });

    test('returns ClarificationNeeded when clarification_needed is set', () {
      final json = '''
{
  "operations": [],
  "summary": "",
  "clarification_needed": "What duration would you like?"
}
''';
      final (set, failure, clarification) = OutputValidator.validate(json);
      expect(set, isNull);
      expect(failure, isNull);
      expect(clarification, isNotNull);
      expect(clarification!.question, contains('What duration'));
    });
  });
}
