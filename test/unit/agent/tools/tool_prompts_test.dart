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
