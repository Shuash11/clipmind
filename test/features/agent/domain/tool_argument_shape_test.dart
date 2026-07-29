import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/tool_call.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/features/projects/domain/commands/clip_commands.dart';
import 'package:clipmind/features/projects/domain/commands/marker_commands.dart';
import 'package:clipmind/features/projects/domain/commands/overlay_commands.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/commands/tag_commands.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  test(
    'all registry names convert through the factory with local allocation',
    () {
      final factory = ProjectCommandFactory(
        SequenceIdGenerator(<String>[
          'right',
          'text',
          'image',
          'tag',
          'marker',
        ]),
      );
      final arguments = _arguments();
      final types = <String>{};
      for (final definition in EditorToolRegistry.standard().definitions) {
        final result = factory.fromCanonicalArguments(
          definition.name,
          arguments[definition.name]!,
        );
        types.add((result as Success<ProjectCommand>).value.type);
      }

      expect(types, arguments.keys.toSet());
      for (final invalid in <(String, Map<String, Object?>)>[
        (
          'remove_clip_range',
          _with(arguments['remove_clip_range']!, 'rightClipId', 'model-id'),
        ),
        (
          'add_text_overlay',
          _with(arguments['add_text_overlay']!, 'overlayId', 'model-id'),
        ),
        (
          'add_image_overlay',
          _with(arguments['add_image_overlay']!, 'overlayId', 'model-id'),
        ),
        ('create_tag', _with(arguments['create_tag']!, 'tagId', 'model-id')),
        (
          'create_marker',
          _with(arguments['create_marker']!, 'markerId', 'model-id'),
        ),
        (
          'trim_clip',
          _with(arguments['trim_clip']!, 'url', 'https://bad.example'),
        ),
        (
          'set_clip_muted',
          _with(arguments['set_clip_muted']!, 'path', r'C:\bad'),
        ),
      ]) {
        expect(
          factory.fromCanonicalArguments(invalid.$1, invalid.$2),
          isA<Failure<ProjectCommand>>(),
          reason: invalid.$1,
        );
      }

      final allocatingFactory = ProjectCommandFactory(
        SequenceIdGenerator(<String>[
          'right-id',
          'text-id',
          'image-id',
          'tag-id',
          'marker-id',
        ]),
      );
      final allocatedIds = <String>[
        _command<RemoveClipRangeCommand>(
          allocatingFactory,
          'remove_clip_range',
          arguments['remove_clip_range']!,
        ).rightClipId,
        _command<AddTextOverlayCommand>(
          allocatingFactory,
          'add_text_overlay',
          arguments['add_text_overlay']!,
        ).overlayId,
        _command<AddImageOverlayCommand>(
          allocatingFactory,
          'add_image_overlay',
          arguments['add_image_overlay']!,
        ).overlayId,
        _command<CreateTagCommand>(
          allocatingFactory,
          'create_tag',
          arguments['create_tag']!,
        ).tagId,
        _command<CreateMarkerCommand>(
          allocatingFactory,
          'create_marker',
          arguments['create_marker']!,
        ).markerId,
      ];
      expect(allocatedIds, <String>[
        'right-id',
        'text-id',
        'image-id',
        'tag-id',
        'marker-id',
      ]);
      expect(allocatedIds.toSet(), hasLength(5));
      expect(
        _command<SetClipBrightnessCommand>(
          ProjectCommandFactory(SequenceIdGenerator(<String>[])),
          'set_clip_brightness',
          arguments['set_clip_brightness']!,
        ).brightness,
        0,
      );
    },
  );

  test('tool calls copy only bounded finite JSON-safe argument values', () {
    final nested = <String, Object?>{'zero': 0};
    final arguments = <String, Object?>{
      'nested': <Object?>[nested],
    };
    final call = ToolCall(
      callId: 'call-1',
      name: 'set_clip_brightness',
      arguments: arguments,
    );
    (arguments['nested'] as List<Object?>).clear();
    nested['zero'] = 9;

    expect((call.arguments['nested'] as List<Object?>), isNotEmpty);
    expect(
      ((call.arguments['nested'] as List<Object?>).single
          as Map<String, Object?>)['zero'],
      0,
    );
    expect(() {
      final nestedCopy =
          (call.arguments['nested'] as List<Object?>).single
              as Map<String, Object?>;
      nestedCopy['zero'] = 1;
    }, throwsUnsupportedError);
    expect(() => call.arguments['x'] = 1, throwsUnsupportedError);
    expect(
      () => ToolCall(callId: 'call-2', name: 'bad-name', arguments: const {}),
      throwsArgumentError,
    );
    expect(
      () => ToolCall(
        callId: 'call-3',
        name: 'tool',
        arguments: <String, Object?>{'x': double.nan},
      ),
      throwsArgumentError,
    );
    expect(
      () => ToolCall(
        callId: 'call-3',
        name: 'tool',
        arguments: <String, Object?>{'x': double.infinity},
      ),
      throwsArgumentError,
    );
    for (final invalid in <Object?>[
      <Object?, Object?>{1: 'not a string key'},
      Uri.parse('https://local.example/secret'),
      DateTime.utc(2026),
      ValidatedPlanPayload(
        commands: const <ProjectCommand>[],
        candidateState: stateWithOneClip(),
        summaries: const [],
      ),
    ]) {
      expect(
        () => ToolCall(
          callId: 'call-4',
          name: 'tool',
          arguments: <String, Object?>{'nested': invalid},
        ),
        throwsArgumentError,
      );
    }
    final cycle = <Object?>[];
    cycle.add(cycle);
    Object? deep = 0;
    for (var index = 0; index < 65; index++) {
      deep = <Object?>[deep];
    }
    for (final invalid in <Object?>[cycle, deep]) {
      expect(
        () => ToolCall(
          callId: 'call-5',
          name: 'tool',
          arguments: <String, Object?>{'nested': invalid},
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => ToolCall(callId: '', name: 'tool', arguments: const {}),
      throwsArgumentError,
    );
    expect(
      () => ToolCall(callId: 'call\n5', name: 'tool', arguments: const {}),
      throwsArgumentError,
    );
  });

  test('validation findings retain only safe stable diagnostic metadata', () {
    final finding = ValidationFinding(
      code: 'unknown_clip',
      message: 'The selected clip does not exist.',
      callId: 'call-1',
      argumentPath: 'placements[0].clipId',
    );

    expect(finding.code, 'unknown_clip');
    expect(finding.argumentPath, 'placements[0].clipId');
    for (final invalid in <ValidationFinding Function()>[
      () => ValidationFinding(code: 'Bad-Code', message: 'safe'),
      () => ValidationFinding(code: 'bad', message: 'line\nbreak'),
      () => ValidationFinding(
        code: 'bad',
        message: List<String>.filled(501, 'x').join(),
      ),
      () => ValidationFinding(code: 'bad', message: 'safe', callId: 'call\n1'),
      () => ValidationFinding(
        code: 'bad',
        message: 'safe',
        callId: List<String>.filled(201, 'x').join(),
      ),
      () => ValidationFinding(
        code: 'bad',
        message: 'safe',
        argumentPath: r'C:\secrets\token',
      ),
      () => ValidationFinding(
        code: 'bad',
        message: 'safe',
        argumentPath: 'https://provider.example/body',
      ),
    ]) {
      expect(invalid, throwsArgumentError);
    }
  });

  test('rejected provider-originating strings are absent from diagnostics', () {
    const callIdSecret = 'CALL_ID_SECRET_C:\\private\\token';
    const messageSecret = 'FINDING_MESSAGE_SECRET';
    const pathSecret = 'FINDING_PATH_SECRET';

    expect(
      _argumentErrorText(
        () => ToolCall(
          callId: '$callIdSecret\n',
          name: 'tool',
          arguments: const <String, Object?>{},
        ),
      ),
      isNot(contains(callIdSecret)),
    );
    expect(
      _argumentErrorText(
        () => ValidationFinding(code: 'invalid', message: '$messageSecret\n'),
      ),
      isNot(contains(messageSecret)),
    );
    expect(
      _argumentErrorText(
        () => ValidationFinding(
          code: 'invalid',
          message: 'safe',
          argumentPath: r'C:\FINDING_PATH_SECRET\token',
        ),
      ),
      isNot(contains(pathSecret)),
    );
  });
}

String _argumentErrorText(void Function() action) {
  try {
    action();
  } on ArgumentError catch (error) {
    return error.toString();
  }
  throw StateError('Expected an argument error');
}

T _command<T extends ProjectCommand>(
  ProjectCommandFactory factory,
  String name,
  Map<String, Object?> arguments,
) =>
    (factory.fromCanonicalArguments(name, arguments) as Success<ProjectCommand>)
            .value
        as T;

Map<String, Object?> _with(
  Map<String, Object?> value,
  String key,
  Object? extra,
) => <String, Object?>{...value, key: extra};

Map<String, Map<String, Object?>>
_arguments() => <String, Map<String, Object?>>{
  'trim_clip': <String, Object?>{'clipId': 'clip-1', 'startMs': 0, 'endMs': 10},
  'remove_clip_range': <String, Object?>{
    'clipId': 'clip-1',
    'startMs': 1,
    'endMs': 9,
  },
  'arrange_clips': <String, Object?>{
    'placements': <Object?>[
      <String, Object?>{
        'clipId': 'clip-1',
        'trackId': 'track-1',
        'positionMs': 0,
      },
    ],
  },
  'set_clip_speed': <String, Object?>{'clipId': 'clip-1', 'speed': 1.0},
  'set_clip_muted': <String, Object?>{'clipId': 'clip-1', 'muted': true},
  'set_clip_volume': <String, Object?>{'clipId': 'clip-1', 'volume': 1.0},
  'set_clip_transform': <String, Object?>{
    'clipId': 'clip-1',
    'width': 1920,
    'height': 1080,
    'fit': 'contain',
    'rotationDegrees': 0,
  },
  'set_clip_brightness': <String, Object?>{'clipId': 'clip-1', 'brightness': 0},
  'add_text_overlay': <String, Object?>{
    'trackId': 'track-1',
    'startMs': 0,
    'endMs': 10,
    'text': 'Title',
    'x': 0.0,
    'y': 0.0,
  },
  'add_image_overlay': <String, Object?>{
    'trackId': 'track-1',
    'assetId': 'asset-1',
    'startMs': 0,
    'endMs': 10,
    'x': 0.0,
    'y': 0.0,
    'width': 10,
    'height': 10,
  },
  'create_tag': <String, Object?>{'name': 'Travel', 'color': '#112233'},
  'update_tag': <String, Object?>{
    'tagId': 'tag-1',
    'name': 'Travel',
    'color': '#112233',
  },
  'delete_tag': <String, Object?>{'tagId': 'tag-1'},
  'assign_tag': <String, Object?>{
    'tagId': 'tag-1',
    'targetKind': 'asset',
    'targetId': 'asset-1',
  },
  'unassign_tag': <String, Object?>{
    'tagId': 'tag-1',
    'targetKind': 'asset',
    'targetId': 'asset-1',
  },
  'create_marker': <String, Object?>{
    'label': 'Beat',
    'color': '#112233',
    'atMs': 5,
  },
  'update_marker': <String, Object?>{
    'markerId': 'marker-1',
    'label': 'Beat',
    'color': '#112233',
    'atMs': 5,
  },
  'delete_marker': <String, Object?>{'markerId': 'marker-1'},
};
