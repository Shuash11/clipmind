import 'package:clipmind/features/agent/domain/entities/editor_tool_definition.dart';
import 'package:clipmind/features/providers/domain/entities/model_tool_definition.dart';

/// Closed, provider-neutral definition of the editor actions a model may ask
/// for.  It intentionally has no commands, paths, transport, or credentials.
final class EditorToolRegistry {
  EditorToolRegistry._(Iterable<EditorToolDefinition> definitions)
    : definitions = List<EditorToolDefinition>.unmodifiable(definitions) {
    if (this.definitions.map((tool) => tool.name).toSet().length !=
        this.definitions.length) {
      throw ArgumentError('Tool names must be unique');
    }
    _byName = Map<String, EditorToolDefinition>.unmodifiable({
      for (final tool in this.definitions) tool.name: tool,
    });
  }

  static const int maxToolCalls = 20;

  final List<EditorToolDefinition> definitions;
  late final Map<String, EditorToolDefinition> _byName;

  EditorToolDefinition? byName(String name) => _byName[name];
  List<EditorToolDefinition> get tools => definitions;
  EditorToolDefinition? lookup(String name) => byName(name);

  List<ModelToolDefinition> toModelToolDefinitions() => List.unmodifiable(
    definitions.map(
      (definition) => ModelToolDefinition(
        name: definition.name,
        description: definition.description,
        inputSchema: definition.inputSchema,
      ),
    ),
  );

  List<ModelToolDefinition> toProviderToolDefinitions() =>
      toModelToolDefinitions();

  factory EditorToolRegistry.standard() => EditorToolRegistry._([
    _tool('trim_clip', 'Trim one clip to its local time range.', _clipRange()),
    _tool(
      'remove_clip_range',
      'Remove a local time range from one clip.',
      _clipRange(),
    ),
    _tool('arrange_clips', 'Place clips on timeline tracks.', _arrangeClips()),
    _tool('set_clip_speed', 'Set a clip playback speed.', _speed()),
    _tool('set_clip_muted', 'Set whether a clip is muted.', _muted()),
    _tool('set_clip_volume', 'Set a clip volume.', _volume()),
    _tool('set_clip_transform', 'Set a clip display transform.', _transform()),
    _tool('set_clip_brightness', 'Set a clip brightness.', _brightness()),
    _tool('add_text_overlay', 'Add a text overlay.', _textOverlay()),
    _tool(
      'add_image_overlay',
      'Add an image overlay from an existing asset.',
      _imageOverlay(),
    ),
    _tool('create_tag', 'Create a tag.', _tagCreate()),
    _tool('update_tag', 'Update an existing tag.', _tagUpdate()),
    _tool('delete_tag', 'Delete an existing tag.', _tagDelete()),
    _tool('assign_tag', 'Assign a tag to an asset or clip.', _tagAssignment()),
    _tool(
      'unassign_tag',
      'Unassign a tag from an asset or clip.',
      _tagAssignment(),
    ),
    _tool('create_marker', 'Create a point or range marker.', _marker(false)),
    _tool('update_marker', 'Update a point or range marker.', _marker(true)),
    _tool('delete_marker', 'Delete an existing marker.', _markerDelete()),
  ]);
}

EditorToolDefinition _tool(
  String name,
  String description,
  Map<String, Object?> schema,
) => EditorToolDefinition(
  name: name,
  description: description,
  inputSchema: schema,
);

Map<String, Object?> _object(
  Map<String, Object?> properties,
  List<String> required, {
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'type': 'object',
  'properties': properties,
  'required': required,
  'additionalProperties': false,
  ...extra,
};

Map<String, Object?> _id() => <String, Object?>{
  'type': 'string',
  'minLength': 1,
  'maxLength': 200,
};

Map<String, Object?> _integer({int? minimum, int? maximum}) =>
    <String, Object?>{
      'type': 'integer',
      'minimum': ?minimum,
      'maximum': ?maximum,
    };

Map<String, Object?> _number({num? minimum, num? maximum}) => <String, Object?>{
  'type': 'number',
  'minimum': ?minimum,
  'maximum': ?maximum,
};

Map<String, Object?> _clipRange() => _object(
  <String, Object?>{
    'clipId': _id(),
    'startMs': _integer(minimum: 0),
    'endMs': _integer(minimum: 0),
  },
  <String>['clipId', 'startMs', 'endMs'],
);

Map<String, Object?> _arrangeClips() => _object(
  <String, Object?>{
    'placements': <String, Object?>{
      'type': 'array',
      'minItems': 1,
      'maxItems': 100,
      'items': _object(
        <String, Object?>{
          'clipId': _id(),
          'trackId': _id(),
          'positionMs': _integer(minimum: 0),
        },
        <String>['clipId', 'trackId', 'positionMs'],
      ),
    },
  },
  <String>['placements'],
);

Map<String, Object?> _speed() => _object(
  <String, Object?>{
    'clipId': _id(),
    'speed': _number(minimum: .25, maximum: 8),
  },
  <String>['clipId', 'speed'],
);

Map<String, Object?> _muted() => _object(
  <String, Object?>{
    'clipId': _id(),
    'muted': <String, Object?>{'type': 'boolean'},
  },
  <String>['clipId', 'muted'],
);

Map<String, Object?> _volume() => _object(
  <String, Object?>{'clipId': _id(), 'volume': _number(minimum: 0, maximum: 2)},
  <String>['clipId', 'volume'],
);

Map<String, Object?> _transform() => _object(
  <String, Object?>{
    'clipId': _id(),
    'width': _integer(minimum: 16, maximum: 7680),
    'height': _integer(minimum: 16, maximum: 4320),
    'fit': <String, Object?>{
      'type': 'string',
      'enum': <String>['contain', 'cover', 'stretch'],
    },
    'rotationDegrees': _integer(minimum: 0, maximum: 359),
  },
  <String>['clipId', 'width', 'height', 'fit', 'rotationDegrees'],
);

Map<String, Object?> _brightness() => _object(
  <String, Object?>{
    'clipId': _id(),
    'brightness': _number(minimum: -1, maximum: 1),
  },
  <String>['clipId', 'brightness'],
);

Map<String, Object?> _textOverlay() => _object(
  <String, Object?>{
    'trackId': _id(),
    'startMs': _integer(minimum: 0),
    'endMs': _integer(minimum: 0),
    'text': <String, Object?>{
      'type': 'string',
      'minLength': 1,
      'maxLength': 500,
    },
    'x': _number(minimum: 0, maximum: 1),
    'y': _number(minimum: 0, maximum: 1),
  },
  <String>['trackId', 'startMs', 'endMs', 'text', 'x', 'y'],
);

Map<String, Object?> _imageOverlay() => _object(
  <String, Object?>{
    'trackId': _id(),
    'assetId': _id(),
    'startMs': _integer(minimum: 0),
    'endMs': _integer(minimum: 0),
    'x': _number(minimum: 0, maximum: 1),
    'y': _number(minimum: 0, maximum: 1),
    'width': _integer(minimum: 1, maximum: 7680),
    'height': _integer(minimum: 1, maximum: 7680),
  },
  <String>[
    'trackId',
    'assetId',
    'startMs',
    'endMs',
    'x',
    'y',
    'width',
    'height',
  ],
);

Map<String, Object?> _tagCreate() => _object(
  <String, Object?>{
    'name': <String, Object?>{
      'type': 'string',
      'minLength': 1,
      'maxLength': 64,
    },
    'color': _color(),
  },
  <String>['name', 'color'],
);

Map<String, Object?> _tagUpdate() => _object(
  <String, Object?>{
    'tagId': _id(),
    'name': <String, Object?>{
      'type': 'string',
      'minLength': 1,
      'maxLength': 64,
    },
    'color': _color(),
  },
  <String>['tagId', 'name', 'color'],
);

Map<String, Object?> _tagDelete() =>
    _object(<String, Object?>{'tagId': _id()}, <String>['tagId']);

Map<String, Object?> _tagAssignment() => _object(
  <String, Object?>{
    'tagId': _id(),
    'targetKind': <String, Object?>{
      'type': 'string',
      'enum': <String>['asset', 'clip'],
    },
    'targetId': _id(),
  },
  <String>['tagId', 'targetKind', 'targetId'],
);

Map<String, Object?> _color() => <String, Object?>{
  'type': 'string',
  'pattern': r'^#[0-9A-Fa-f]{6}$',
};

Map<String, Object?> _marker(bool includeId) {
  final properties = <String, Object?>{
    if (includeId) 'markerId': _id(),
    'label': <String, Object?>{
      'type': 'string',
      'minLength': 1,
      'maxLength': 120,
    },
    'color': _color(),
    'atMs': _integer(minimum: 0),
    'startMs': _integer(minimum: 0),
    'endMs': _integer(minimum: 0),
  };
  final base = <String>[if (includeId) 'markerId', 'label', 'color'];
  return _object(
    properties,
    base,
    extra: <String, Object?>{
      'oneOf': <Object?>[
        <String, Object?>{
          'required': <String>[...base, 'atMs'],
          'not': <String, Object?>{
            'anyOf': <Object?>[
              <String, Object?>{
                'required': <String>['startMs'],
              },
              <String, Object?>{
                'required': <String>['endMs'],
              },
            ],
          },
        },
        <String, Object?>{
          'required': <String>[...base, 'startMs', 'endMs'],
          'not': <String, Object?>{
            'required': <String>['atMs'],
          },
        },
      ],
    },
  );
}

Map<String, Object?> _markerDelete() =>
    _object(<String, Object?>{'markerId': _id()}, <String>['markerId']);
