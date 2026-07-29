import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'standard registry has only the canonical tools in deterministic order',
    () {
      final registry = EditorToolRegistry.standard();

      expect(EditorToolRegistry.maxToolCalls, 20);
      expect(_names(registry.definitions), _canonicalNames);
      expect(registry.byName('extract_audio'), isNull);
      expect(registry.byName('generate_thumbnail'), isNull);
      expect(registry.byName('change_format'), isNull);
    },
  );

  test('all schemas are closed, camelCase, immutable canonical shapes', () {
    final registry = EditorToolRegistry.standard();

    for (final definition in registry.definitions) {
      _assertClosedObjects(definition.inputSchema);
      _assertCamelCasePropertyNames(definition.inputSchema);
      expect(
        _propertyNames(definition.inputSchema),
        isNot(contains('sourcePath')),
      );
      expect(_propertyNames(definition.inputSchema), isNot(contains('path')));
      expect(_propertyNames(definition.inputSchema), isNot(contains('url')));
      expect(
        _propertyNames(definition.inputSchema),
        isNot(contains('mediaBytes')),
      );
      expect(_propertyNames(definition.inputSchema), isNot(contains('ffmpeg')));
      expect(
        _propertyNames(definition.inputSchema),
        isNot(contains('command')),
      );
      expect(_propertyNames(definition.inputSchema), isNot(contains('shell')));
      expect(
        _propertyNames(definition.inputSchema),
        isNot(contains('executable')),
      );
    }

    for (final name in <String>[
      'remove_clip_range',
      'add_text_overlay',
      'add_image_overlay',
      'create_tag',
      'create_marker',
    ]) {
      final properties = _properties(registry.byName(name)!.inputSchema);
      expect(properties.containsKey('rightClipId'), isFalse, reason: name);
      expect(properties.containsKey('overlayId'), isFalse, reason: name);
      expect(properties.containsKey('tagId'), isFalse, reason: name);
      expect(properties.containsKey('markerId'), isFalse, reason: name);
    }

    for (final entry in _shapeProperties.entries) {
      final schema = registry.byName(entry.key)!.inputSchema;
      expect(_properties(schema).keys.toSet(), entry.value, reason: entry.key);
      expect(_required(schema), _shapeRequired[entry.key], reason: entry.key);
    }

    _expectNumber(_property(registry, 'set_clip_speed', 'speed'), .25, 8);
    _expectNumber(_property(registry, 'set_clip_volume', 'volume'), 0, 2);
    _expectNumber(
      _property(registry, 'set_clip_brightness', 'brightness'),
      -1,
      1,
    );
    expect(
      _property(registry, 'set_clip_brightness', 'brightness')['minimum'],
      -1,
    );
    expect(
      _property(registry, 'set_clip_brightness', 'brightness')['maximum'],
      1,
    );
    expect(_property(registry, 'set_clip_transform', 'width')['minimum'], 16);
    expect(_property(registry, 'set_clip_transform', 'width')['maximum'], 7680);
    expect(_property(registry, 'set_clip_transform', 'height')['minimum'], 16);
    expect(
      _property(registry, 'set_clip_transform', 'height')['maximum'],
      4320,
    );
    expect(_property(registry, 'set_clip_transform', 'fit')['enum'], <String>[
      'contain',
      'cover',
      'stretch',
    ]);
    expect(
      _property(registry, 'set_clip_transform', 'rotationDegrees')['minimum'],
      0,
    );
    expect(
      _property(registry, 'set_clip_transform', 'rotationDegrees')['maximum'],
      359,
    );
    expect(_property(registry, 'arrange_clips', 'placements')['minItems'], 1);
    expect(_property(registry, 'arrange_clips', 'placements')['maxItems'], 100);
    expect(_property(registry, 'add_text_overlay', 'text')['maxLength'], 500);
    expect(_property(registry, 'add_image_overlay', 'width')['maximum'], 7680);
    expect(_property(registry, 'add_image_overlay', 'height')['maximum'], 7680);
    for (final schema in <Map<String, Object?>>[
      _property(registry, 'create_tag', 'color'),
      _property(registry, 'update_tag', 'color'),
      _property(registry, 'create_marker', 'color'),
      _property(registry, 'update_marker', 'color'),
    ]) {
      expect(schema['pattern'], r'^#[0-9A-Fa-f]{6}$');
    }

    final pointOrRange =
        registry.byName('create_marker')!.inputSchema['oneOf']!
            as List<Object?>;
    expect(pointOrRange, hasLength(2));
    expect((pointOrRange.first as Map<String, Object?>)['required'], <String>[
      'label',
      'color',
      'atMs',
    ]);
    expect((pointOrRange.last as Map<String, Object?>)['required'], <String>[
      'label',
      'color',
      'startMs',
      'endMs',
    ]);
  });

  test(
    'registry and provider definitions are independent deep immutable copies',
    () {
      final registry = EditorToolRegistry.standard();
      final providerDefinitions = registry.toModelToolDefinitions();
      final schema = registry.byName('arrange_clips')!.inputSchema;
      final providerSchema = providerDefinitions[2].inputSchema;
      final item =
          (_properties(schema)['placements']! as Map<String, Object?>)['items']!
              as Map<String, Object?>;

      expect(_names(providerDefinitions), _canonicalNames);
      expect(providerDefinitions, hasLength(18));
      expect(providerSchema, isNot(same(schema)));
      expect(
        () => registry.definitions.add(registry.definitions.first),
        throwsUnsupportedError,
      );
      expect(() => schema['type'] = 'array', throwsUnsupportedError);
      expect(() => item['additionalProperties'] = true, throwsUnsupportedError);
      expect(
        () => providerDefinitions.add(providerDefinitions.first),
        throwsUnsupportedError,
      );
      expect(() => providerSchema['type'] = 'array', throwsUnsupportedError);
    },
  );
}

const List<String> _canonicalNames = <String>[
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

final Map<String, Set<String>> _shapeProperties = <String, Set<String>>{
  'trim_clip': <String>{'clipId', 'startMs', 'endMs'},
  'remove_clip_range': <String>{'clipId', 'startMs', 'endMs'},
  'arrange_clips': <String>{'placements'},
  'set_clip_speed': <String>{'clipId', 'speed'},
  'set_clip_muted': <String>{'clipId', 'muted'},
  'set_clip_volume': <String>{'clipId', 'volume'},
  'set_clip_transform': <String>{
    'clipId',
    'width',
    'height',
    'fit',
    'rotationDegrees',
  },
  'set_clip_brightness': <String>{'clipId', 'brightness'},
  'add_text_overlay': <String>{'trackId', 'startMs', 'endMs', 'text', 'x', 'y'},
  'add_image_overlay': <String>{
    'trackId',
    'assetId',
    'startMs',
    'endMs',
    'x',
    'y',
    'width',
    'height',
  },
  'create_tag': <String>{'name', 'color'},
  'update_tag': <String>{'tagId', 'name', 'color'},
  'delete_tag': <String>{'tagId'},
  'assign_tag': <String>{'tagId', 'targetKind', 'targetId'},
  'unassign_tag': <String>{'tagId', 'targetKind', 'targetId'},
  'create_marker': <String>{'label', 'color', 'atMs', 'startMs', 'endMs'},
  'update_marker': <String>{
    'markerId',
    'label',
    'color',
    'atMs',
    'startMs',
    'endMs',
  },
  'delete_marker': <String>{'markerId'},
};

final Map<String, Set<String>> _shapeRequired = <String, Set<String>>{
  for (final entry in _shapeProperties.entries)
    entry.key: switch (entry.key) {
      'create_marker' => <String>{'label', 'color'},
      'update_marker' => <String>{'markerId', 'label', 'color'},
      _ => entry.value,
    },
};

List<String> _names(Iterable<dynamic> definitions) =>
    definitions.map((definition) => definition.name as String).toList();

Map<String, Object?> _properties(Map<String, Object?> schema) =>
    schema['properties']! as Map<String, Object?>;

Set<String> _required(Map<String, Object?> schema) =>
    (schema['required']! as List<Object?>).cast<String>().toSet();

Map<String, Object?> _property(
  EditorToolRegistry registry,
  String tool,
  String property,
) =>
    _properties(registry.byName(tool)!.inputSchema)[property]!
        as Map<String, Object?>;

void _expectNumber(Map<String, Object?> schema, num minimum, num maximum) {
  expect(schema['type'], 'number');
  expect(schema['minimum'], minimum);
  expect(schema['maximum'], maximum);
  expect(schema.containsKey('exclusiveMinimum'), isFalse);
}

void _assertClosedObjects(Object? value) {
  if (value is Map) {
    if (value['type'] == 'object') {
      expect(value['additionalProperties'], isFalse);
    }
    for (final nested in value.values) {
      _assertClosedObjects(nested);
    }
  } else if (value is Iterable) {
    for (final nested in value) {
      _assertClosedObjects(nested);
    }
  }
}

void _assertCamelCasePropertyNames(Object? value) {
  if (value is Map) {
    final properties = value['properties'];
    if (properties is Map) {
      for (final name in properties.keys) {
        expect(RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(name as String), isTrue);
      }
    }
    for (final nested in value.values) {
      _assertCamelCasePropertyNames(nested);
    }
  } else if (value is Iterable) {
    for (final nested in value) {
      _assertCamelCasePropertyNames(nested);
    }
  }
}

Set<String> _propertyNames(Object? value) {
  final names = <String>{};
  void collect(Object? current) {
    if (current is Map) {
      final properties = current['properties'];
      if (properties is Map) {
        names.addAll(properties.keys.cast<String>());
      }
      for (final nested in current.values) {
        collect(nested);
      }
    } else if (current is Iterable) {
      for (final nested in current) {
        collect(nested);
      }
    }
  }

  collect(value);
  return names;
}
