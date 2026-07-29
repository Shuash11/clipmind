import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'canonical provider schemas expose only closed camelCase editor tools',
    () {
      final registry = EditorToolRegistry.standard();
      final names = registry
          .toModelToolDefinitions()
          .map((tool) => tool.name)
          .toList();

      expect(EditorToolRegistry.maxToolCalls, 20);
      expect(names, _canonicalNames);
      expect(names, hasLength(18));

      for (final tool in registry.toModelToolDefinitions()) {
        _expectClosedCamelCaseObjects(tool.inputSchema);
      }

      for (final forbidden in _forbiddenToolNames) {
        expect(registry.byName(forbidden), isNull, reason: forbidden);
      }
    },
  );
}

const _canonicalNames = <String>[
  'trim_clip',
  'remove_clip_range',
  'arrange_clips',
  'set_clip_speed',
  'set_clip_muted',
  'set_clip_volume',
  'set_clip_transform',
  'set_clip_brightness',
  'add_text_overlay',
  'add_image_overlay',
  'create_tag',
  'update_tag',
  'delete_tag',
  'assign_tag',
  'unassign_tag',
  'create_marker',
  'update_marker',
  'delete_marker',
];

const _forbiddenToolNames = <String>[
  'merge',
  'extract_audio',
  'generate_thumbnail',
  'change_format',
  'path',
  'output',
  'ffmpeg',
  'shell',
  'executable',
];

void _expectClosedCamelCaseObjects(Object? value) {
  if (value is Map) {
    if (value['type'] == 'object') {
      expect(value['additionalProperties'], isFalse);
    }
    final properties = value['properties'];
    if (properties is Map) {
      for (final name in properties.keys) {
        expect(RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(name as String), isTrue);
      }
    }
    for (final child in value.values) {
      _expectClosedCamelCaseObjects(child);
    }
  } else if (value is Iterable) {
    for (final child in value) {
      _expectClosedCamelCaseObjects(child);
    }
  }
}
