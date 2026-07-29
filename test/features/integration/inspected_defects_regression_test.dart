import 'dart:convert';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/features/agent/domain/services/legacy_operation_normalizer.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/providers/data/provider_registry_impl.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../projects/support/project_fakes.dart';
import '../projects/support/project_test_data.dart';

void main() {
  test('bundled provider service identifiers remain stable service IDs', () {
    final ids = ProviderRegistryImpl(
      adapters: const <String, ModelProviderAdapter>{},
    ).definitions.map((definition) => definition.id);

    expect(ids, contains('ollama'));
    expect(ids, everyElement(isNot(contains(':'))));
  });

  test('standard editor tools remain the closed canonical editing surface', () {
    final registry = EditorToolRegistry.standard();

    expect(registry.definitions.map((tool) => tool.name), _canonicalToolNames);
    for (final name in _deferredOutputToolNames) {
      expect(registry.byName(name), isNull, reason: name);
    }
  });

  test('canonical public schemas encode camelCase property names only', () {
    final definitions = EditorToolRegistry.standard()
        .toProviderToolDefinitions();

    for (final definition in definitions) {
      _expectCamelCasePropertyNames(definition.inputSchema);
      final schema = jsonEncode(definition.inputSchema);
      expect(schema, isNot(contains('target_clip_id')));
      expect(schema, isNot(contains('targetClip_id')));
    }
  });

  test(
    'canonical brightness commands accept zero and negative in-range values',
    () {
      final factory = ProjectCommandFactory(SequenceIdGenerator(const []));
      final executor = ProjectCommandExecutor.standard();

      for (final brightness in <num>[0, -0.4]) {
        final command = factory.fromCanonicalArguments('set_clip_brightness', {
          'clipId': 'clip-1',
          'brightness': brightness,
        });

        expect(command, isA<Success<ProjectCommand>>(), reason: '$brightness');
        final applied = executor.applyAll(stateWithOneClip(), [
          (command as Success<ProjectCommand>).value,
        ]);
        expect(
          applied,
          isA<Success<CommandExecution>>(),
          reason: '$brightness',
        );
        final candidate = (applied as Success<CommandExecution>).value;
        expect(
          candidate.candidateState.tracks.single.clips.single.brightness,
          brightness,
        );
      }
    },
  );

  test(
    'ambiguous cuts and deferred legacy output operations stop at findings',
    () {
      final output = LegacyOperationNormalizer().normalize(<Object?>[
        <String, Object?>{
          'type': 'cut',
          'targetClipId': 'clip-1',
          'params': <String, Object?>{'startMs': 0},
        },
        for (final name in _deferredOutputToolNames)
          <String, Object?>{'type': name, 'params': <String, Object?>{}},
      ]);

      expect(output.calls, isEmpty);
      expect(
        output.findings.map((finding) => finding.code),
        contains('ambiguous_legacy_operation'),
      );
      expect(
        output.findings.where(
          (finding) => finding.code == 'unsupported_legacy_operation',
        ),
        hasLength(_deferredOutputToolNames.length),
      );
    },
  );
}

const List<String> _canonicalToolNames = <String>[
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

const List<String> _deferredOutputToolNames = <String>[
  'extract_audio',
  'generate_thumbnail',
  'change_format',
];

void _expectCamelCasePropertyNames(Object? value) {
  if (value is List) {
    for (final child in value) {
      _expectCamelCasePropertyNames(child);
    }
    return;
  }
  if (value is! Map) return;

  final properties = value['properties'];
  if (properties is Map) {
    for (final entry in properties.entries) {
      expect(entry.key, isA<String>());
      expect(
        RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(entry.key as String),
        isTrue,
        reason: entry.key,
      );
    }
  }
  for (final child in value.values) {
    _expectCamelCasePropertyNames(child);
  }
}
