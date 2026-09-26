import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/agent_chat_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'suggested prompts are exactly the bounded supported editing milestones',
    () {
      final registry = EditorToolRegistry.standard();

      expect(AgentChatPanel.suggestedPrompts, isNotEmpty);
      expect(AgentChatPanel.suggestedPrompts, _supportedMilestonePrompts);
      expect(
        registry.definitions.map((definition) => definition.name),
        containsAll(<String>[
          'trim_clip',
          'remove_clip_range',
          'set_clip_muted',
          'add_text_overlay',
          'set_clip_brightness',
        ]),
      );
    },
  );

  test(
    'suggested prompts do not offer automatic analysis or deferred output',
    () {
      final prompts = AgentChatPanel.suggestedPrompts
          .map((prompt) => prompt.toLowerCase())
          .toList(growable: false);

      for (final phrase in _unsupportedSuggestedPromptVocabulary) {
        expect(
          prompts.any((prompt) => prompt.contains(phrase)),
          isFalse,
          reason: phrase,
        );
      }
    },
  );

  test(
    'tag and marker tools remain available without automatic suggestions',
    () {
      final registry = EditorToolRegistry.standard();

      expect(
        registry.definitions.map((definition) => definition.name),
        containsAll(<String>[
          'create_tag',
          'update_tag',
          'delete_tag',
          'assign_tag',
          'unassign_tag',
          'create_marker',
          'update_marker',
          'delete_marker',
        ]),
      );
      expect(
        AgentChatPanel.suggestedPrompts
            .map((prompt) => prompt.toLowerCase())
            .join(' '),
        isNot(contains('tag')),
      );
      expect(
        AgentChatPanel.suggestedPrompts
            .map((prompt) => prompt.toLowerCase())
            .join(' '),
        isNot(contains('marker')),
      );
    },
  );
}

const List<String> _supportedMilestonePrompts = <String>[
  'Cut out the first 5 seconds',
  'Trim this clip to 30 seconds',
  'Mute the selected clip',
  'Add an intro text overlay',
  'Adjust the selected clip brightness',
];

const List<String> _unsupportedSuggestedPromptVocabulary = <String>[
  'automatic',
  'auto-tag',
  'analyze',
  'analysis',
  'transcript',
  'scene',
  'object detection',
  'visual analysis',
  'audio analysis',
  'extract audio',
  'thumbnail',
  'format conversion',
  'change format',
  'render',
  'export',
];
