import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_prompts.dart';

ToolDefinition _def(String name, String description) => ToolDefinition(
  name: name,
  description: description,
  inputSchema: const {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': <String>[],
    'additionalProperties': false,
  },
  category: ToolCategory.read,
);

void main() {
  group('ToolPromptBuilder.buildSystemPrompt', () {
    test('renders available tools from data, not a hard-coded list', () {
      final prompt = ToolPromptBuilder.buildSystemPrompt(
        available: [
          _def('trim_clip', 'Cut the ends off a clip.'),
          _def('brand_new_tool', 'A capability added after this test.'),
        ],
        deferredNames: const [],
      );

      expect(prompt, contains('AVAILABLE TOOLS:'));
      expect(prompt, contains('- trim_clip: Cut the ends off a clip.'));
      expect(prompt, contains('- brand_new_tool:'));
      // No catalog drift: unlisted tools never appear.
      expect(prompt, isNot(contains('apply_effect')));
    });

    test('lists deferred names with one-line hints', () {
      final prompt = ToolPromptBuilder.buildSystemPrompt(
        available: [_def('trim_clip', 'Cut.')],
        deferredNames: const ['resize_clip', 'apply_effect', 'mystery_tool'],
      );

      expect(prompt, contains('DEFERRED TOOLS'));
      expect(prompt, contains('- resize_clip: change resolution'));
      expect(prompt, contains('- apply_effect: apply creative looks'));
      // A hintless name still renders (catalog growth never breaks it).
      expect(prompt, contains('- mystery_tool'));
    });

    test('tag/marker deferred names carry hints and the reader lists', () {
      final prompt = ToolPromptBuilder.buildSystemPrompt(
        available: [
          _def('list_tags_and_markers', 'List tags, markers and assets.'),
        ],
        deferredNames: const [
          'create_tag',
          'update_tag',
          'delete_tag',
          'assign_tag',
          'unassign_tag',
          'create_marker',
          'update_marker',
          'delete_marker',
        ],
      );

      expect(prompt, contains('- list_tags_and_markers: List tags'));
      expect(prompt, contains('- create_tag: create a tag'));
      expect(prompt, contains('- update_tag: rename or recolor a tag'));
      expect(prompt, contains('- delete_tag: delete a tag by ID'));
      expect(prompt, contains('- assign_tag: attach a tag'));
      expect(prompt, contains('- unassign_tag: detach a tag'));
      expect(
        prompt,
        contains('- create_marker: create a point or range marker'),
      );
      expect(prompt, contains('- update_marker: update a marker by ID'));
      expect(prompt, contains('- delete_marker: delete a marker by ID'));
    });

    test('collapses multiline descriptions to one prompt line', () {
      final prompt = ToolPromptBuilder.buildSystemPrompt(
        available: [_def('probe_video', 'Line one.\n    Line two.')],
        deferredNames: const [],
      );

      expect(prompt, contains('- probe_video: Line one. Line two.'));
    });

    test('carries the load_tools rule: no invented names, next round', () {
      final prompt = ToolPromptBuilder.buildSystemPrompt(
        available: [_def('trim_clip', 'Cut.')],
        deferredNames: const ['apply_effect'],
      );

      expect(prompt, contains('load_tools'));
      expect(prompt, contains('next round'));
      expect(prompt, contains('Never invent tool names'));
    });
  });
}
