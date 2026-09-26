import 'package:clipmind/features/agent/data/provider_tool_call_normalizer.dart';
import 'package:clipmind/features/agent/data/strict_json_schema_encoder.dart';
import 'package:clipmind/features/agent/domain/entities/tool_call.dart';
import 'package:clipmind/features/providers/domain/entities/normalized_model_tool_call.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native and strict fallback calls normalize equivalently', () {
    final normalizer = ProviderToolCallNormalizer();
    final native = normalizer.normalize(
      ModelResponse(
        modelId: 'model',
        content: 'Change brightness.',
        toolCalls: [
          NormalizedModelToolCall(
            id: 'native-1',
            name: 'set_clip_brightness',
            arguments: {'clipId': 'clip-1', 'brightness': 0},
          ),
        ],
      ),
    );
    final body = StrictJsonSchemaEncoder().encode(
      summary: 'Change brightness.',
      calls: [
        ToolCall(
          callId: 'local',
          name: 'set_clip_brightness',
          arguments: {'clipId': 'clip-1', 'brightness': 0},
        ),
      ],
    );
    final fallback = normalizer.normalize(
      ModelResponse(modelId: 'model', content: body),
    );

    expect(native.calls.single.name, fallback.calls.single.name);
    expect(native.calls.single.arguments, fallback.calls.single.arguments);
    expect(fallback.calls.single.callId, 'fallback-1');
  });

  test('strict fallback rejects wrappers and unknown fields', () {
    final codec = StrictJsonSchemaEncoder();
    expect(codec.decode('```json {} ```').calls, isEmpty);
    expect(
      codec.decode('{"summary":"ok","operations":[],"extra":false}').findings,
      isNotEmpty,
    );
  });

  test('strict fallback rejection table has no partial calls', () {
    final codec = StrictJsonSchemaEncoder();
    final oversized = List<String>.filled(1001, 'x').join();
    final cases = <String>[
      '',
      'prose {"summary":"ok","operations":[]}',
      '{"summary":"ok","operations":[]} trailing',
      '{"summary":"ok"}',
      '{"summary":"ok","operations":[],"id":"not-allowed"}',
      '{"summary":"","operations":[{"name":"trim_clip","arguments":{}}]}',
      '{"summary":"$oversized","operations":[{"name":"trim_clip","arguments":{}}]}',
      '{"summary":"ok","operations":[{"name":"trim_clip"}]}',
      '{"summary":"ok","operations":[{"name":"trim_clip","arguments":{},"callId":"x"}]}',
      '{"summary":"ok","operations":[{"name":"not_a_tool","arguments":{}}]}',
      '{"summary":"ok","operations":[{"name":"trim_clip","arguments":[]}]}',
      '{"summary":"ok","summary":"again","operations":[{"name":"trim_clip","arguments":{}}]}',
      '{"summary":"ok","operations":[{"name":"trim_clip","arguments":{"clipId":"a","clipId":"b"}}]}',
      '{"summary":"ok","operations":01}',
    ];
    for (final value in cases) {
      final decoded = codec.decode(value);
      expect(
        decoded.calls,
        isEmpty,
        reason: value.length > 80 ? 'oversized case' : value,
      );
      expect(decoded.findings, isNotEmpty);
    }
    final tooMany =
        '{"summary":"ok","operations":['
        '${List<String>.filled(21, '{"name":"trim_clip","arguments":{}}').join(',')}'
        ']}';
    expect(codec.decode(tooMany).calls, isEmpty);
  });

  test('native takes precedence and preserves JSON values immutably', () {
    final normalizer = ProviderToolCallNormalizer();
    final nested = <String, Object?>{
      'zero': 0,
      'negative': -1,
      'false': false,
      'empty': '',
    };
    final output = normalizer.normalize(
      ModelResponse(
        modelId: 'model',
        content:
            '{"summary":"ignored","operations":[{"name":"unknown","arguments":{}}]}',
        toolCalls: [
          NormalizedModelToolCall(
            id: 'native-1',
            name: 'set_clip_brightness',
            arguments: {'clipId': 'clip-1', 'brightness': 0, 'nested': nested},
          ),
        ],
      ),
    );
    nested['zero'] = 9;
    expect(output.findings, isEmpty);
    expect(output.calls.single.arguments['brightness'], 0);
    expect(
      (output.calls.single.arguments['nested'] as Map<String, Object?>)['zero'],
      0,
    );
    expect(() => output.calls.add(output.calls.single), throwsUnsupportedError);
  });

  test(
    'native rejects unknown and oversized calls while retaining duplicate IDs',
    () {
      final normalizer = ProviderToolCallNormalizer();
      final duplicate = normalizer.normalize(
        ModelResponse(
          modelId: 'model',
          content: '',
          toolCalls: [
            NormalizedModelToolCall(
              id: 'same',
              name: 'set_clip_speed',
              arguments: {'clipId': 'clip-1', 'speed': 1},
            ),
            NormalizedModelToolCall(
              id: 'same',
              name: 'set_clip_brightness',
              arguments: {'clipId': 'clip-1', 'brightness': 0},
            ),
          ],
        ),
      );
      expect(duplicate.calls, hasLength(2));
      expect(duplicate.calls.map((call) => call.callId), everyElement('same'));
      expect(
        normalizer
            .normalize(
              ModelResponse(
                modelId: 'model',
                content: '',
                toolCalls: [
                  NormalizedModelToolCall(
                    id: 'x',
                    name: 'unknown_tool',
                    arguments: {},
                  ),
                ],
              ),
            )
            .calls,
        isEmpty,
      );
      expect(
        normalizer
            .normalize(
              ModelResponse(
                modelId: 'model',
                content: '',
                toolCalls: List.generate(
                  21,
                  (index) => NormalizedModelToolCall(
                    id: 'id-$index',
                    name: 'set_clip_speed',
                    arguments: {'clipId': 'clip-1', 'speed': 1},
                  ),
                ),
              ),
            )
            .calls,
        isEmpty,
      );
    },
  );

  test(
    'strict fallback bounds duplicate-key parsing before deep recursion',
    () {
      final codec = StrictJsonSchemaEncoder();
      final deeplyNested = codec.decode(_strictBodyWithNestedArrays(65));
      expect(deeplyNested.calls, isEmpty);
      expect(deeplyNested.findings, isNotEmpty);
    },
  );

  test('strict fallback has a deterministic structural nesting boundary', () {
    final codec = StrictJsonSchemaEncoder();
    // Root, operations, operation, and arguments occupy depths 0 through 3.
    // Sixty nested arrays therefore end at container depth 63; the scalar leaf
    // is allowed at 64, matching the strict JSON copier boundary.
    expect(codec.decode(_strictBodyWithNestedArrays(60)).calls, hasLength(1));
    expect(codec.decode(_strictBodyWithNestedArrays(61)).calls, isEmpty);
  });

  test('nested duplicate keys remain rejected within the supported depth', () {
    final nested =
        '${List<String>.filled(10, '[').join()}'
        '{"same":1,"same":2}'
        '${List<String>.filled(10, ']').join()}';
    final output = StrictJsonSchemaEncoder().decode(
      '{"summary":"ok","operations":[{"name":"set_clip_brightness","arguments":{"nested":$nested}}]}',
    );
    expect(output.calls, isEmpty);
    expect(output.findings, isNotEmpty);
  });

  test('strict encoding rejects an oversized body before returning it', () {
    final huge = List<String>.filled(100001, 'x').join();
    expect(
      () => StrictJsonSchemaEncoder().encode(
        summary: 'safe',
        calls: [
          ToolCall(
            callId: 'call',
            name: 'set_clip_brightness',
            arguments: {'blob': huge},
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}

String _strictBodyWithNestedArrays(int count) {
  final open = List<String>.filled(count, '[').join();
  final close = List<String>.filled(count, ']').join();
  return '{"summary":"ok","operations":[{"name":"set_clip_brightness","arguments":{"nested":$open 0 $close}}]}';
}
