import 'package:clipmind/features/agent/domain/entities/tool_call.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/features/agent/domain/services/tool_call_validator.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  test(
    'rejects a path masquerading as an asset ID before factory conversion',
    () {
      final factory = ProjectCommandFactory(SequenceIdGenerator(['first-id']));
      final validator = ToolCallValidator(
        registry: EditorToolRegistry.standard(),
        commandFactory: factory,
        commandExecutor: ProjectCommandExecutor.standard(),
      );
      final result = validator.validate([
        ToolCall(
          callId: 'call-1',
          name: 'add_image_overlay',
          arguments: {
            'trackId': 'track-1',
            'assetId': r'C:\secret.mp4',
            'startMs': 0,
            'endMs': 100,
            'x': 0.0,
            'y': 0.0,
            'width': 10,
            'height': 10,
          },
        ),
      ], documentWithOneClip());
      expect(result.commands, isEmpty);
      expect(result.findings.single.code, 'unknown_asset_id');
      expect(
        factory.createTag(name: 'Safe', color: '#112233').tagId,
        'first-id',
      );
    },
  );

  test('UNC, URL, and shell-like IDs are rejected with safe target codes', () {
    final cases = <(String, String)>[
      (r'\\server\secret.mp4', 'unknown_asset_id'),
      ('https://host/asset', 'unknown_asset_id'),
      ('asset-1;rm', 'unknown_asset_id'),
    ];
    for (final item in cases) {
      final result =
          ToolCallValidator(
            registry: EditorToolRegistry.standard(),
            commandFactory: ProjectCommandFactory(
              SequenceIdGenerator(['not-used']),
            ),
            commandExecutor: ProjectCommandExecutor.standard(),
          ).validate([
            ToolCall(
              callId: 'call',
              name: 'add_image_overlay',
              arguments: {
                'trackId': 'track-1',
                'assetId': item.$1,
                'startMs': 0,
                'endMs': 1,
                'x': 0,
                'y': 0,
                'width': 1,
                'height': 1,
              },
            ),
          ], documentWithOneClip());
      expect(result.findings.single.code, item.$2);
      expect(result.findings.single.message, isNot(contains(item.$1)));
    }
  });
}
