import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';
import 'package:clipmind/domain/agent/tools/tool_selection.dart';

class _StubExecutor implements ToolExecutor {
  @override
  Future<ToolResult> execute(ToolCall call) async =>
      ToolResult.ok(summary: call.name);
}

ToolSelection _selection() => ToolSelection(
  ToolRegistry(
    executors: {
      for (final d in ToolRegistry.defaultDefinitions())
        d.name: _StubExecutor(),
    },
  ),
);

const _coreNames = [
  'list_project_clips',
  'probe_video',
  'get_edit_history',
  'detect_scenes',
  'get_storyboard',
  'get_transcript',
  'list_tags_and_markers',
  'trim_clip',
  'cut_segment',
  'merge_clips',
  'change_speed',
  'mute_clip',
  'overlay_text',
  'adjust_brightness',
  'change_volume',
];

const _deferredNames = [
  'resize_clip',
  'rotate_clip',
  'extract_audio',
  'burn_captions',
  'add_transition',
  'apply_effect',
  'create_tag',
  'update_tag',
  'delete_tag',
  'assign_tag',
  'unassign_tag',
  'create_marker',
  'update_marker',
  'delete_marker',
];

void main() {
  group('ToolSelection exposure', () {
    test('initial active set is exactly the core tools in catalog order', () {
      final selection = _selection();
      expect(
        selection.activeDefinitions().map((d) => d.name),
        equals(_coreNames),
      );
      expect(selection.loadsUsed, isZero);
    });

    test('deferredNames lists the fourteen deferred tools in catalog order', () {
      expect(_selection().deferredNames(), equals(_deferredNames));
    });

    test('roundDefinitions appends load_tools while loads remain', () {
      final selection = _selection();
      final names = selection.roundDefinitions().map((d) => d.name).toList();
      expect(names, equals([..._coreNames, ToolSelection.loadToolsName]));
      expect(names.length, lessThanOrEqualTo(16));
    });

    test('loading activates the tool at its catalog position', () {
      final selection = _selection();
      expect(selection.load(['resize_clip']).success, isTrue);

      final names = selection.activeDefinitions().map((d) => d.name).toList();
      expect(names.length, equals(_coreNames.length + 1));
      // Stable catalog order: resize_clip rides between its catalog
      // neighbours (overlay_text, adjust_brightness), not appended last.
      expect(
        names.indexOf('resize_clip'),
        equals(names.indexOf('overlay_text') + 1),
      );
      expect(
        names.indexOf('resize_clip') + 1,
        equals(names.indexOf('adjust_brightness')),
      );
    });

    test('tag/marker commands are loadable; the reader is core', () {
      final selection = _selection();
      expect(selection.isActive('list_tags_and_markers'), isTrue);
      expect(selection.isActive('create_tag'), isFalse);

      final result = selection.load(
        ['create_tag', 'assign_tag', 'create_marker'],
      );

      expect(result.success, isTrue);
      expect(selection.isActive('create_tag'), isTrue);
      expect(selection.isActive('assign_tag'), isTrue);
      expect(selection.isActive('create_marker'), isTrue);
      expect(selection.isActive('delete_marker'), isFalse);
    });

    test('loader disappears once every deferred tool is loaded', () {
      final selection = _selection();
      // Two loads can activate all fourteen deferred tools.
      expect(selection.load(_deferredNames.sublist(0, 7)).success, isTrue);
      expect(selection.load(_deferredNames.sublist(7)).success, isTrue);

      expect(selection.loaderAvailable, isFalse);
      final names = selection.roundDefinitions().map((d) => d.name).toList();
      expect(names, containsAll(_deferredNames));
      expect(names, isNot(contains(ToolSelection.loadToolsName)));
    });

    test('loader disappears once the load budget is spent', () {
      final selection = _selection();
      expect(selection.load(['resize_clip']).success, isTrue);
      expect(selection.load(['rotate_clip']).success, isTrue);

      expect(selection.loaderAvailable, isFalse);
      expect(
        selection.roundDefinitions().map((d) => d.name),
        isNot(contains(ToolSelection.loadToolsName)),
      );
    });

    test('isActive tracks core + loaded names only', () {
      final selection = _selection();
      expect(selection.isActive('trim_clip'), isTrue);
      expect(selection.isActive('apply_effect'), isFalse);
      expect(selection.isActive('teleport_clip'), isFalse);

      selection.load(['apply_effect']);
      expect(selection.isActive('apply_effect'), isTrue);
    });

    test('loadsRemaining reports the remaining budget', () {
      final selection = _selection();
      expect(selection.loadsRemaining, equals(ToolSelection.maxToolLoads));

      selection.load(['resize_clip']);
      expect(selection.loadsRemaining, equals(1));
      selection.load(['rotate_clip']);
      expect(selection.loadsRemaining, isZero);
    });
  });

  group('ToolSelection.load', () {
    test('activates valid deferred names and reports them', () {
      final selection = _selection();
      final result = selection.load(['apply_effect', 'extract_audio']);

      expect(result.success, isTrue);
      expect(result.loaded, equals(['apply_effect', 'extract_audio']));
      expect(result.message, contains('Loaded apply_effect, extract_audio'));
      expect(result.message, contains('next round'));
      expect(selection.loadsUsed, equals(1));
      final names = selection.activeDefinitions().map((d) => d.name).toList();
      expect(names, contains('apply_effect'));
      expect(names, contains('extract_audio'));
    });

    test('unknown names fail and list the valid deferred names', () {
      final selection = _selection();
      final result = selection.load(['teleport_clip']);

      expect(result.success, isFalse);
      expect(result.unknown, equals(['teleport_clip']));
      expect(result.loaded, isEmpty);
      expect(result.limitReached, isFalse);
      expect(result.message, contains('unknown names: teleport_clip'));
      expect(result.message, contains('resize_clip'));
      expect(selection.loadsUsed, isZero);
      expect(
        selection.activeDefinitions().map((d) => d.name),
        equals(_coreNames),
      );
    });

    test('core names fail as already available', () {
      final selection = _selection();
      final result = selection.load(['trim_clip']);

      expect(result.success, isFalse);
      expect(result.alreadyAvailable, equals(['trim_clip']));
      expect(result.message, contains('already available: trim_clip'));
      expect(selection.loadsUsed, isZero);
    });

    test('already-loaded names fail as already available', () {
      final selection = _selection();
      expect(selection.load(['apply_effect']).success, isTrue);

      final result = selection.load(['apply_effect']);
      expect(result.success, isFalse);
      expect(result.alreadyAvailable, equals(['apply_effect']));
      expect(selection.loadsUsed, equals(1));
    });

    test('a mixed request loads nothing (all-or-nothing)', () {
      final selection = _selection();
      final result = selection.load(['resize_clip', 'nope']);

      expect(result.success, isFalse);
      expect(result.loaded, isEmpty);
      expect(result.unknown, equals(['nope']));
      expect(
        selection.activeDefinitions().map((d) => d.name),
        isNot(contains('resize_clip')),
      );
      expect(selection.loadsUsed, isZero);
    });

    test('an empty request fails actionably', () {
      final selection = _selection();
      final result = selection.load(const []);

      expect(result.success, isFalse);
      expect(result.message, contains('no tool names provided'));
      expect(result.message, contains('resize_clip'));
    });

    test('failed requests do not consume the load budget', () {
      final selection = _selection();
      expect(selection.load(['nope']).success, isFalse);
      expect(selection.load(['trim_clip']).success, isFalse);
      expect(selection.load(['resize_clip']).success, isTrue);

      expect(selection.loadsUsed, equals(1));
      expect(selection.loaderAvailable, isTrue);
    });

    test('a third successful load is rejected by the budget', () {
      final selection = _selection();
      expect(selection.load(['resize_clip']).success, isTrue);
      expect(selection.load(['rotate_clip']).success, isTrue);

      final third = selection.load(['apply_effect']);
      expect(third.success, isFalse);
      expect(third.limitReached, isTrue);
      expect(third.message, contains('load limit reached'));
      expect(selection.loadsUsed, equals(2));
      expect(
        selection.activeDefinitions().map((d) => d.name),
        isNot(contains('apply_effect')),
      );
    });

    test('a budget-rejected load reports the limit even with bad names', () {
      final selection = _selection();
      selection.load(['resize_clip']);
      selection.load(['rotate_clip']);

      final result = selection.load(['teleport_clip']);
      expect(result.success, isFalse);
      expect(result.limitReached, isTrue);
      expect(result.unknown, equals(['teleport_clip']));
    });
  });

  group('load_tools definition', () {
    test('is not a catalog tool and has no executor', () {
      final registry = ToolRegistry(
        executors: {
          for (final d in ToolRegistry.defaultDefinitions())
            d.name: _StubExecutor(),
        },
      );
      expect(registry.definitionFor(ToolSelection.loadToolsName), isNull);
      expect(registry.executorFor(ToolSelection.loadToolsName), isNull);
      expect(registry.hasAllExecutors, isTrue);
    });

    test('schema is strict-compatible', () {
      final schema = ToolSelection.loadToolsDefinition.inputSchema;
      expect(schema['type'], equals('object'));
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], equals(['tools']));
      final properties = schema['properties'] as Map;
      expect(properties.keys, contains('tools'));
      final tools = properties['tools'] as Map;
      expect(tools['type'], equals('array'));
      expect(tools['items'], equals({'type': 'string'}));
    });

    test('description points the model at deferred names + next round', () {
      final description = ToolSelection.loadToolsDefinition.description;
      expect(description, contains('DEFERRED TOOLS'));
      expect(description, contains('next round'));
    });
  });
}
