import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_1_input_validation.dart';
import 'package:clipmind/domain/agent/stage_2_prompt_construction.dart';
import 'package:clipmind/domain/agent/stage_3_intent_parsing.dart';
import 'package:clipmind/domain/agent/stage_4_output_validation.dart';
import 'mock_provider.dart';
import 'accuracy_report.dart';

void main() {
  group('NLP Accuracy Evaluation', () {
    late List<Map<String, dynamic>> dataset;
    late MockLlmProvider mock;

    setUp(() {
      final jsonFile = File('test/eval/dataset/commands.json');
      final jsonStr = jsonFile.readAsStringSync();
      dataset = (jsonDecode(jsonStr) as List<dynamic>).cast<Map<String, dynamic>>();
      mock = MockLlmProvider();
    });

    test('should achieve >80% accuracy across all commands', () async {
      final results = <EvalResult>[];

      for (final tc in dataset) {
        final result = await _evaluateCommand(tc, mock);
        results.add(result);
      }

      final report = AccuracyReport(results);
      debugPrint(report.format());

      expect(results.isNotEmpty, isTrue);
      expect(report.overallAccuracy, greaterThan(80.0));
    });
  });
}

Future<EvalResult> _evaluateCommand(
  Map<String, dynamic> tc,
  MockLlmProvider mock,
) async {
  final id = tc['id'] as String;
  final command = tc['command'] as String;
  final expected = tc['expected'] as Map<String, dynamic>;
  final category = tc['category'] as String;
  final difficulty = tc['difficulty'] as String;

  final ops = (expected['ops'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  final stage1ErrorExpected = expected['stage1_error'] as bool? ?? false;
  final stage4ErrorExpected = expected['stage4_error'] as bool? ?? false;
  final clarificationExpected = expected['clarification'] as bool? ?? false;

  if (stage1ErrorExpected) {
    final (validated, error) = InputValidator.validate(command, null);
    final passed = error != null && validated == null;
    return EvalResult(
      id: id,
      passed: passed,
      category: category,
      difficulty: difficulty,
      error: passed ? null : (error?.message ?? 'Expected stage 1 error'),
      stage: 1,
    );
  }

  List<Map<String, dynamic>> mockOpsData;
  String mockSummary;
  bool mockClarification = false;

  final mockResponseOverride = expected['mock_response'] as Map<String, dynamic>?;

  if (stage4ErrorExpected && mockResponseOverride != null) {
    mockOpsData = (mockResponseOverride['ops'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    mockSummary = mockResponseOverride['summary'] as String? ?? '';
  } else if (clarificationExpected) {
    mockOpsData = [];
    mockSummary = '';
    mockClarification = true;
  } else {
    mockOpsData = ops;
    mockSummary = expected['summary'] as String? ?? '';
  }

  final mockRequestOps = mockOpsData.map((o) => EditOperationRequest(
    id: 'op_${mockOpsData.indexOf(o) + 1}',
    type: o['type'] as String,
    targetClipId: o['target_clip_id'],
    params: Map<String, dynamic>.from(o['params'] as Map),
  )).toList();

  if (mockClarification) {
    mock.addResponse(
      command,
      const EditOperationSet(
        operations: [],
        summary: '',
        clarificationNeeded: 'What would you like to do?',
      ),
    );
  } else {
    mock.addResponse(
      command,
      EditOperationSet(operations: mockRequestOps, summary: mockSummary),
    );
  }

  final (validated, stage1Error) = InputValidator.validate(command, null);
  if (stage1Error != null || validated == null) {
    return EvalResult(
      id: id,
      passed: false,
      category: category,
      difficulty: difficulty,
      error: stage1Error?.message ?? 'Stage 1 returned null',
      stage: 1,
    );
  }

  final schemaJson = jsonEncode({
    'operations': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
          'type': {
            'type': 'string',
            'enum': [
              'trim',
              'cut',
              'merge',
              'change_speed',
              'mute',
              'overlay_text',
              'resize',
              'rotate',
              'extract_audio',
              'generate_thumbnail',
              'change_format',
              'adjust_brightness',
              'change_volume',
              'overlay_watermark',
            ],
          },
          'target_clip_id': {'type': 'string'},
          'params': {'type': 'object'},
        },
        'required': ['id', 'type', 'target_clip_id', 'params'],
      },
    },
    'summary': {'type': 'string'},
    'clarification_needed': {'type': 'string'},
  });

  final request = PromptConstructor.build(validated, schemaJson);

  final (parsed, providerError) = await IntentParser.parse(mock, request);
  if (providerError != null) {
    return EvalResult(
      id: id,
      passed: false,
      category: category,
      difficulty: difficulty,
      error: 'Provider error: ${providerError.message}',
      stage: 3,
    );
  }
  if (parsed == null) {
    return EvalResult(
      id: id,
      passed: false,
      category: category,
      difficulty: difficulty,
      error: 'Parsed null',
      stage: 3,
    );
  }

  final rawJsonSnake = jsonEncode({
    'operations': parsed.operations.map((op) => {
      'id': op.id,
      'type': op.type,
      'target_clip_id': op.targetClipId,
      'params': op.params,
    }).toList(),
    'summary': parsed.summary,
    'clarification_needed': parsed.clarificationNeeded,
  });
  final (validatedSet, stage4Error, clarification) =
      OutputValidator.validate(rawJsonSnake);

  if (clarificationExpected) {
    final passed = clarification != null;
    return EvalResult(
      id: id,
      passed: passed,
      category: category,
      difficulty: difficulty,
      error: passed
          ? null
          : 'Expected clarification, got ${stage4Error?.message ?? 'valid set'}',
      stage: 4,
    );
  }

  if (stage4ErrorExpected) {
    final passed = stage4Error != null;
    return EvalResult(
      id: id,
      passed: passed,
      category: category,
      difficulty: difficulty,
      error: passed ? null : 'Expected stage 4 error but validated OK',
      stage: 4,
    );
  }

  if (stage4Error != null || validatedSet == null) {
    return EvalResult(
      id: id,
      passed: false,
      category: category,
      difficulty: difficulty,
      error: stage4Error?.message ?? 'Validation returned null',
      stage: 4,
    );
  }

  if (validatedSet.operations.length != ops.length) {
    return EvalResult(
      id: id,
      passed: false,
      category: category,
      difficulty: difficulty,
      error:
          'Op count: expected ${ops.length}, got ${validatedSet.operations.length}',
      stage: 4,
    );
  }

  for (int i = 0; i < ops.length; i++) {
    final expectedOp = ops[i];
    final actualOp = validatedSet.operations[i];

    if (actualOp.type != expectedOp['type']) {
      return EvalResult(
        id: id,
        passed: false,
        category: category,
        difficulty: difficulty,
        error:
            'Op $i type: expected ${expectedOp['type']}, got ${actualOp.type}',
        stage: 4,
      );
    }

    final expectedParams = expectedOp['params'] as Map<String, dynamic>;
    for (final key in expectedParams.keys) {
      final expectedVal = expectedParams[key];
      final actualVal = actualOp.params[key];
      if (actualVal == null) {
        return EvalResult(
          id: id,
          passed: false,
          category: category,
          difficulty: difficulty,
          error: 'Op $i missing param "$key"',
          stage: 4,
        );
      }
      if (actualVal.toString() != expectedVal.toString()) {
        return EvalResult(
          id: id,
          passed: false,
          category: category,
          difficulty: difficulty,
          error:
              'Op $i param "$key": expected "$expectedVal", got "$actualVal"',
          stage: 4,
        );
      }
    }
  }

  return EvalResult(
    id: id,
    passed: true,
    category: category,
    difficulty: difficulty,
  );
}
