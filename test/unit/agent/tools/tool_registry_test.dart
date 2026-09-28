import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/llm/anthropic_provider.dart';
import 'package:clipmind/data/services/llm/gemini_provider.dart';
import 'package:clipmind/data/services/llm/nvidia_nim_provider.dart';
import 'package:clipmind/data/services/llm/ollama_provider.dart';
import 'package:clipmind/data/services/llm/openai_provider.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';

class _StubExecutor implements ToolExecutor {
  @override
  Future<ToolResult> execute(ToolCall call) async =>
      ToolResult.ok(summary: call.name);
}

void main() {
  group('ToolRegistry surface', () {
    test('exposes exactly the 20 curated tools (at the <= 20 cap)', () {
      final defs = ToolRegistry.defaultDefinitions();
      expect(defs, hasLength(20));
      expect(defs.length, lessThanOrEqualTo(20));
    });

    test('names are unique, short and charset-valid', () {
      final names =
          ToolRegistry.defaultDefinitions().map((d) => d.name).toList();
      expect(names.toSet(), hasLength(names.length));
      for (final name in names) {
        expect(name.length, lessThanOrEqualTo(64), reason: name);
        expect(ToolRegistry.validName.hasMatch(name), isTrue, reason: name);
      }
    });

    test('read/edit categories cover the curated surface', () {
      final byName = {
        for (final d in ToolRegistry.defaultDefinitions()) d.name: d.category,
      };
      expect(
        byName,
        containsPair('list_project_clips', ToolCategory.read),
      );
      expect(byName, containsPair('probe_video', ToolCategory.read));
      expect(byName, containsPair('get_edit_history', ToolCategory.read));
      expect(byName, containsPair('detect_scenes', ToolCategory.read));
      expect(byName, containsPair('get_storyboard', ToolCategory.read));
      expect(byName, containsPair('get_transcript', ToolCategory.read));
      for (final name in [
        'trim_clip',
        'cut_segment',
        'merge_clips',
        'change_speed',
        'mute_clip',
        'overlay_text',
        'resize_clip',
        'rotate_clip',
        'adjust_brightness',
        'change_volume',
        'extract_audio',
        'burn_captions',
        'add_transition',
        'apply_effect',
      ]) {
        expect(byName, containsPair(name, ToolCategory.edit));
      }
    });

    test('deferred tools are absent', () {
      final names = ToolRegistry.defaultDefinitions()
          .map((d) => d.name)
          .toSet();
      for (final deferred in [
        'change_format',
        'generate_thumbnail',
        'overlay_watermark',
      ]) {
        expect(names, isNot(contains(deferred)));
      }
    });

    test('every schema is strict-compatible', () {
      for (final def in ToolRegistry.defaultDefinitions()) {
        final schema = def.inputSchema;
        expect(schema['type'], equals('object'), reason: def.name);
        expect(
          schema['additionalProperties'],
          isFalse,
          reason: def.name,
        );
        final properties = schema['properties'] as Map;
        final required = (schema['required'] as List).toSet();
        for (final key in properties.keys) {
          expect(required, contains(key), reason: '${def.name}.$key');
        }
      }
    });

    test('executor lookup resolves every tool name', () {
      final registry = ToolRegistry(
        executors: {
          for (final d in ToolRegistry.defaultDefinitions())
            d.name: _StubExecutor(),
        },
      );
      expect(registry.hasAllExecutors, isTrue);
      for (final d in ToolRegistry.defaultDefinitions()) {
        expect(registry.executorFor(d.name), isNotNull, reason: d.name);
        expect(registry.definitionFor(d.name)?.name, equals(d.name));
      }
      expect(registry.executorFor('nope'), isNull);
    });

    test('run bounds are 4 rounds and 20 jobs', () {
      expect(ToolRegistry.maxToolRounds, equals(4));
      expect(ToolRegistry.maxEditJobsPerRun, equals(20));
    });
  });

  group('Provider capability gate', () {
    test('all five providers support tool calling', () {
      expect(
        OpenAiProvider(config: const OpenAiConfig(apiKey: 'x'))
            .supportsToolCalling,
        isTrue,
      );
      expect(
        AnthropicProvider(config: const AnthropicConfig(apiKey: 'x'))
            .supportsToolCalling,
        isTrue,
      );
      expect(OllamaProvider().supportsToolCalling, isTrue);
      expect(NvidiaNimProvider().supportsToolCalling, isTrue);
      expect(GeminiProvider().supportsToolCalling, isTrue);
    });
  });
}
