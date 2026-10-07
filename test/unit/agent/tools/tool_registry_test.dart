import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/llm/anthropic_provider.dart';
import 'package:clipmind/data/services/llm/gemini_provider.dart';
import 'package:clipmind/data/services/llm/nvidia_nim_provider.dart';
import 'package:clipmind/data/services/llm/ollama_provider.dart';
import 'package:clipmind/data/services/llm/openai_provider.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';
import 'package:clipmind/domain/agent/tools/tool_selection.dart';

class _StubExecutor implements ToolExecutor {
  @override
  Future<ToolResult> execute(ToolCall call) async =>
      ToolResult.ok(summary: call.name);
}

void main() {
  group('ToolRegistry surface', () {
    test('catalog: 29 curated tools, every one classified', () {
      final defs = ToolRegistry.defaultDefinitions();
      expect(defs, hasLength(29));
      expect(
        defs.every((d) =>
            d.exposure == ToolExposure.core ||
            d.exposure == ToolExposure.deferred),
        isTrue,
        reason: 'every catalog tool needs an exposure',
      );
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
      expect(byName, containsPair('list_tags_and_markers', ToolCategory.read));
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
        'create_tag',
        'update_tag',
        'delete_tag',
        'assign_tag',
        'unassign_tag',
        'create_marker',
        'update_marker',
        'delete_marker',
      ]) {
        expect(byName, containsPair(name, ToolCategory.edit));
      }
    });

    test('deferred tools are absent', () {
      final names = ToolRegistry.defaultDefinitions()
          .map((d) => d.name)
          .toSet();
      // Deliberate deferral (Cycle 7 Phase 2 ruling, future cycle): each of
      // these needs a new FFmpeg executor + schema + UX semantics (notably
      // a model-chosen watermark image path — a trust problem best solved
      // with asset-based pickers), so they stay out of the agent catalog.
      for (final deferred in [
        'change_format',
        'generate_thumbnail',
        'overlay_watermark',
      ]) {
        expect(names, isNot(contains(deferred)));
      }
    });

    test('exposure mapping: 15 core (all reads + 8 common edits)', () {
      final byName = {
        for (final d in ToolRegistry.defaultDefinitions()) d.name: d.exposure,
      };
      const core = {
        'list_project_clips',
        'probe_video',
        'get_edit_history',
        'detect_scenes',
        'get_storyboard',
        'get_transcript',
        'list_tags_and_markers',
        'trim_clip',
        'cut_segment',
        'merge_clips',
        'change_speed',
        'mute_clip',
        'overlay_text',
        'change_volume',
        'adjust_brightness',
      };
      const deferred = {
        'resize_clip',
        'rotate_clip',
        'extract_audio',
        'burn_captions',
        'add_transition',
        'apply_effect',
        'create_tag',
        'update_tag',
        'delete_tag',
        'assign_tag',
        'unassign_tag',
        'create_marker',
        'update_marker',
        'delete_marker',
      };
      expect(byName, hasLength(29));
      expect(core.length, equals(15));
      expect(deferred.length, equals(14));
      for (final name in core) {
        expect(byName[name], ToolExposure.core, reason: name);
      }
      for (final name in deferred) {
        expect(byName[name], ToolExposure.deferred, reason: name);
      }
    });

    test('exposure constraints: reads core, >=6 core edits, initial <=16',
        () {
      final defs = ToolRegistry.defaultDefinitions();
      final core = defs.where((d) => d.exposure == ToolExposure.core).toList();
      final deferred =
          defs.where((d) => d.exposure == ToolExposure.deferred).toList();

      for (final def in defs.where((d) => d.category == ToolCategory.read)) {
        expect(def.exposure, ToolExposure.core, reason: def.name);
      }
      expect(
        core.where((d) => d.category == ToolCategory.edit).length,
        greaterThanOrEqualTo(6),
      );
      expect(deferred.length, greaterThanOrEqualTo(4));
      // Initial exposure = core + the reserved load_tools meta-tool.
      expect(core.length + 1, lessThanOrEqualTo(16));
    });

    test('the reserved load_tools name is not a curated tool', () {
      final names = ToolRegistry.defaultDefinitions()
          .map((d) => d.name)
          .toSet();
      expect(ToolSelection.loadToolsName, equals('load_tools'));
      expect(names, isNot(contains(ToolSelection.loadToolsName)));
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

  group('ToolDefinition exposure metadata', () {
    test('toJson/fromJson round-trip the exposure', () {
      const def = ToolDefinition(
        name: 'x',
        description: 'x',
        inputSchema: {
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
          'additionalProperties': false,
        },
        category: ToolCategory.read,
        exposure: ToolExposure.deferred,
      );
      final decoded = ToolDefinition.fromJson(def.toJson());
      expect(decoded.exposure, ToolExposure.deferred);
    });

    test('legacy JSON without exposure falls back to core', () {
      final decoded = ToolDefinition.fromJson({
        'name': 'legacy',
        'description': 'legacy tool',
        'inputSchema': <String, dynamic>{},
        'category': 'read',
      });
      expect(decoded.exposure, ToolExposure.core);
    });

    test('unknown exposure values fall back to core', () {
      final decoded = ToolDefinition.fromJson({
        'name': 'future',
        'description': '',
        'inputSchema': <String, dynamic>{},
        'category': 'read',
        'exposure': 'turbo',
      });
      expect(decoded.exposure, ToolExposure.core);
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
