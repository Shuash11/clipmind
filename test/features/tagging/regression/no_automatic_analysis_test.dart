import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/agent_chat_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'tag and marker AI tools stay manual and avoid automatic analysis claims',
    () {
      final registry = EditorToolRegistry.standard();
      const tagAndMarkerTools = <String>{
        'create_tag',
        'update_tag',
        'delete_tag',
        'assign_tag',
        'unassign_tag',
        'create_marker',
        'update_marker',
        'delete_marker',
      };
      final available = registry.tools
          .where((tool) => tagAndMarkerTools.contains(tool.name))
          .map((tool) => tool.name)
          .toSet();

      expect(available, tagAndMarkerTools);

      final exposedText = [
        ...registry.tools.map((tool) => '${tool.name} ${tool.description}'),
        ...AgentChatPanel.suggestedPrompts,
      ].join('\n').toLowerCase();
      const forbiddenCapabilities = <String>[
        'automatic analysis',
        'automatic visual analysis',
        'automatic audio analysis',
        'automatic transcript analysis',
        'automatic scene analysis',
        'automatic object analysis',
        'visual analysis',
        'audio analysis',
        'transcript analysis',
        'scene analysis',
        'object analysis',
        'visual detection',
        'audio detection',
        'transcript detection',
        'scene detection',
        'object detection',
        'speech detection',
        'transcript',
        'transcription',
        'auto-tagging',
        'auto tagging',
      ];

      for (final capability in forbiddenCapabilities) {
        expect(exposedText, isNot(contains(capability)), reason: capability);
      }
    },
  );
}
