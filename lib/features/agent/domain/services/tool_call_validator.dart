import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/tool_call.dart';
import 'package:clipmind/features/agent/domain/entities/tool_call_validation_result.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';

/// Closes model operations over the document currently being planned.  All
/// public failures deliberately discard commands and candidate state.
final class ToolCallValidator {
  factory ToolCallValidator({
    required EditorToolRegistry registry,
    required ProjectCommandFactory commandFactory,
    required ProjectCommandExecutor commandExecutor,
  }) => ToolCallValidator._(registry, commandFactory, commandExecutor);

  ToolCallValidator._(
    this._registry,
    this._commandFactory,
    this._commandExecutor,
  );

  final EditorToolRegistry _registry;
  final ProjectCommandFactory _commandFactory;
  final ProjectCommandExecutor _commandExecutor;

  ToolCallValidationResult validate(
    Iterable<ToolCall> input,
    ProjectDocument document,
  ) {
    final calls = List<ToolCall>.from(input);
    final findings = <ValidationFinding>[];
    if (calls.isEmpty) {
      findings.add(
        _finding('invalid_arguments', 'At least one editor call is required.'),
      );
    }
    if (calls.length > EditorToolRegistry.maxToolCalls) {
      findings.add(
        _finding('too_many_calls', 'Too many editor calls were requested.'),
      );
    }
    final ids = <String>{};
    final schemaValidCalls = <ToolCall>[];
    for (final call in calls) {
      if (!ids.add(call.callId)) {
        findings.add(
          _finding(
            'duplicate_call_id',
            'Each editor call must have a unique identifier.',
            call,
          ),
        );
      }
      final definition = _registry.byName(call.name);
      if (definition == null) {
        findings.add(
          _finding(
            'unknown_tool',
            'The requested editor tool is not available.',
            call,
          ),
        );
        continue;
      }
      final beforeSchema = findings.length;
      _validateSchema(call, definition.inputSchema, findings);
      if (findings.length == beforeSchema) {
        schemaValidCalls.add(call);
        _validateTargets(call, document, findings);
      }
    }
    _validateConflicts(schemaValidCalls, document, findings);
    final stableFindings = _deduplicate(findings);
    if (stableFindings.isNotEmpty) {
      return ToolCallValidationResult.invalid(stableFindings);
    }

    final commands = <ProjectCommand>[];
    for (final call in calls) {
      final result = _commandFactory.fromCanonicalArguments(
        call.name,
        call.arguments,
      );
      switch (result) {
        case Success<ProjectCommand>(:final value):
          commands.add(value);
          break;
        case Failure<ProjectCommand>():
          return ToolCallValidationResult.invalid([
            _finding(
              'command_invalid',
              'The editor call could not be converted safely.',
              call,
            ),
          ]);
      }
    }
    final execution = _commandExecutor.applyAll(
      document.currentState,
      commands,
    );
    switch (execution) {
      case Success<CommandExecution>(:final value):
        return ToolCallValidationResult.valid(
          ValidatedPlanPayload(
            commands: commands,
            candidateState: value.candidateState,
            summaries: value.summaries,
          ),
        );
      case Failure<CommandExecution>():
        return ToolCallValidationResult.invalid([
          _finding(
            'command_invalid',
            'The proposed editor changes are not valid for this project.',
          ),
        ]);
    }
  }

  void _validateSchema(
    ToolCall call,
    Map<String, Object?> schema,
    List<ValidationFinding> findings,
  ) {
    _schemaValue(call, call.arguments, schema, '', findings);
  }

  void _schemaValue(
    ToolCall call,
    Object? value,
    Map<String, Object?> schema,
    String path,
    List<ValidationFinding> findings,
  ) {
    final type = schema['type'];
    if (type == 'object') {
      if (value is! Map || value.keys.any((key) => key is! String)) {
        _invalidArguments(call, path, findings);
        return;
      }
      final map = Map<String, Object?>.from(value);
      final properties =
          schema['properties'] as Map<String, Object?>? ?? const {};
      final required = schema['required'] as List<Object?>? ?? const [];
      if (schema['additionalProperties'] == false &&
          map.keys.any((key) => !properties.containsKey(key))) {
        _invalidArguments(call, path, findings);
      }
      for (final key in required) {
        if (key is! String || !map.containsKey(key)) {
          _invalidArguments(call, pathFor(path, key.toString()), findings);
        }
      }
      for (final entry in map.entries) {
        final child = properties[entry.key];
        if (child is Map<String, Object?>) {
          _schemaValue(
            call,
            entry.value,
            child,
            pathFor(path, entry.key),
            findings,
          );
        }
      }
      if (!_matchesOneOf(map, schema)) _invalidArguments(call, path, findings);
      return;
    }
    if (type == 'array') {
      if (value is! List) {
        _invalidArguments(call, path, findings);
        return;
      }
      final min = schema['minItems'] as int?;
      final max = schema['maxItems'] as int?;
      if ((min != null && value.length < min) ||
          (max != null && value.length > max)) {
        _invalidArguments(call, path, findings);
      }
      final item = schema['items'];
      if (item is Map<String, Object?>) {
        for (var index = 0; index < value.length; index++) {
          _schemaValue(call, value[index], item, '$path[$index]', findings);
        }
      }
      return;
    }
    final valid = switch (type) {
      'string' => value is String && _safeString(value),
      'boolean' => value is bool,
      'integer' => value is int,
      'number' => value is num && value.isFinite,
      _ => false,
    };
    if (!valid) {
      _invalidArguments(call, path, findings);
      return;
    }
    if (value is String) {
      final min = schema['minLength'] as int?;
      final max = schema['maxLength'] as int?;
      final pattern = schema['pattern'] as String?;
      final values = schema['enum'] as List<Object?>?;
      if ((min != null && value.length < min) ||
          (max != null && value.length > max) ||
          (pattern != null && !RegExp(pattern).hasMatch(value)) ||
          (values != null && !values.contains(value))) {
        _invalidArguments(call, path, findings);
      }
    }
    if (value is num) {
      final minimum = schema['minimum'] as num?;
      final maximum = schema['maximum'] as num?;
      if ((minimum != null && value < minimum) ||
          (maximum != null && value > maximum)) {
        _invalidArguments(call, path, findings);
      }
    }
  }

  void _validateTargets(
    ToolCall call,
    ProjectDocument document,
    List<ValidationFinding> findings,
  ) {
    final args = call.arguments;
    final state = document.currentState;
    void clip(String key) {
      final id = args[key];
      if (id is String &&
          (_unsafeId(id) ||
              !state.tracks.any(
                (track) => track.clips.any((item) => item.id == id),
              ))) {
        findings.add(
          _finding(
            'unknown_clip_id',
            'The selected clip does not exist.',
            call,
            key,
          ),
        );
      }
    }

    void track(String key) {
      final id = args[key];
      if (id is String &&
          (_unsafeId(id) || !state.tracks.any((item) => item.id == id))) {
        findings.add(
          _finding(
            'unknown_track_id',
            'The selected track does not exist.',
            call,
            key,
          ),
        );
      }
    }

    void asset(String key) {
      final id = args[key];
      if (id is String && (_unsafeId(id) || state.assetById(id) == null)) {
        findings.add(
          _finding(
            'unknown_asset_id',
            'The selected asset does not exist.',
            call,
            key,
          ),
        );
      }
    }

    void tag(String key) {
      final id = args[key];
      if (id is String &&
          (_unsafeId(id) || !state.tags.any((item) => item.id == id))) {
        findings.add(
          _finding(
            'unknown_tag_id',
            'The selected tag does not exist.',
            call,
            key,
          ),
        );
      }
    }

    void marker(String key) {
      final id = args[key];
      if (id is String &&
          (_unsafeId(id) || !state.markers.any((item) => item.id == id))) {
        findings.add(
          _finding(
            'unknown_marker_id',
            'The selected marker does not exist.',
            call,
            key,
          ),
        );
      }
    }

    switch (call.name) {
      case 'trim_clip':
      case 'remove_clip_range':
      case 'set_clip_speed':
      case 'set_clip_muted':
      case 'set_clip_volume':
      case 'set_clip_transform':
      case 'set_clip_brightness':
        clip('clipId');
        _validateClipRange(call, state, findings);
        break;
      case 'arrange_clips':
        final placements = args['placements'];
        if (placements is List) {
          final clips = <String>{};
          final positions = <String>{};
          for (var index = 0; index < placements.length; index++) {
            final item = placements[index];
            if (item is! Map) continue;
            final clipId = item['clipId'];
            final trackId = item['trackId'];
            final position = item['positionMs'];
            if (clipId is String && !clips.add(clipId)) {
              _invalidArguments(call, 'placements[$index].clipId', findings);
            }
            if (clipId is String &&
                (_unsafeId(clipId) ||
                    !state.tracks.any(
                      (track) => track.clips.any((clip) => clip.id == clipId),
                    ))) {
              findings.add(
                _finding(
                  'unknown_clip_id',
                  'The selected clip does not exist.',
                  call,
                  'placements[$index].clipId',
                ),
              );
            }
            if (trackId is String &&
                (_unsafeId(trackId) ||
                    !state.tracks.any((track) => track.id == trackId))) {
              findings.add(
                _finding(
                  'unknown_track_id',
                  'The selected track does not exist.',
                  call,
                  'placements[$index].trackId',
                ),
              );
            }
            if (trackId is String &&
                position is int &&
                !positions.add('$trackId:$position')) {
              _invalidArguments(
                call,
                'placements[$index].positionMs',
                findings,
              );
            }
          }
        }
        break;
      case 'add_text_overlay':
        track('trackId');
        _validateTiming(call, findings);
        break;
      case 'add_image_overlay':
        track('trackId');
        asset('assetId');
        _validateTiming(call, findings);
        break;
      case 'update_tag':
        tag('tagId');
        _validateTagName(call, document, findings);
        break;
      case 'delete_tag':
        tag('tagId');
        break;
      case 'assign_tag':
      case 'unassign_tag':
        tag('tagId');
        _validateAssignment(call, document, findings);
        break;
      case 'create_tag':
        _validateTagName(call, document, findings);
        break;
      case 'update_marker':
        marker('markerId');
        _validateMarkerTiming(call, findings);
        break;
      case 'delete_marker':
        marker('markerId');
        break;
      case 'create_marker':
        _validateMarkerTiming(call, findings);
        break;
    }
  }

  void _validateClipRange(
    ToolCall call,
    ProjectStateSnapshot state,
    List<ValidationFinding> findings,
  ) {
    if (call.name != 'trim_clip' && call.name != 'remove_clip_range') return;
    final clipId = call.arguments['clipId'];
    final start = call.arguments['startMs'];
    final end = call.arguments['endMs'];
    final clip = clipId is String
        ? state.tracks
              .expand((track) => track.clips)
              .where((item) => item.id == clipId)
              .firstOrNull
        : null;
    if (clip != null &&
        start is int &&
        end is int &&
        (start < 0 ||
            start >= end ||
            end > clip.durationMs ||
            (call.name == 'remove_clip_range' &&
                start == 0 &&
                end == clip.durationMs))) {
      findings.add(
        _finding(
          'invalid_range',
          'The selected clip range is not valid.',
          call,
          'startMs',
        ),
      );
    }
  }

  void _validateTiming(ToolCall call, List<ValidationFinding> findings) {
    final start = call.arguments['startMs'];
    final end = call.arguments['endMs'];
    if (start is int && end is int && (start < 0 || start >= end)) {
      findings.add(
        _finding(
          'invalid_range',
          'The selected timeline range is not valid.',
          call,
          'startMs',
        ),
      );
    }
  }

  void _validateTagName(
    ToolCall call,
    ProjectDocument document,
    List<ValidationFinding> findings,
  ) {
    final name = call.arguments['name'];
    final tagId = call.arguments['tagId'];
    if (name is String &&
        document.currentState.tags.any(
          (tag) =>
              tag.id != tagId &&
              tag.name.trim().toLowerCase() == name.trim().toLowerCase(),
        )) {
      _invalidArguments(call, 'name', findings);
    }
  }

  void _validateAssignment(
    ToolCall call,
    ProjectDocument document,
    List<ValidationFinding> findings,
  ) {
    final kind = call.arguments['targetKind'];
    final id = call.arguments['targetId'];
    final tag = call.arguments['tagId'];
    if (kind is! String || id is! String || tag is! String) return;
    final assigned = kind == 'asset'
        ? document.currentState.assetById(id)?.tagIds.contains(tag)
        : document.currentState.tracks
              .expand((track) => track.clips)
              .where((clip) => clip.id == id)
              .firstOrNull
              ?.tagIds
              .contains(tag);
    if (_unsafeId(id) || assigned == null) {
      findings.add(
        _finding(
          kind == 'asset' ? 'unknown_asset_id' : 'unknown_clip_id',
          'The assignment target does not exist.',
          call,
          'targetId',
        ),
      );
    } else if ((call.name == 'assign_tag') == assigned) {
      _invalidArguments(call, 'targetId', findings);
    }
  }

  void _validateMarkerTiming(ToolCall call, List<ValidationFinding> findings) {
    final args = call.arguments;
    final at = args['atMs'];
    final start = args['startMs'];
    final end = args['endMs'];
    final point = at is int && start == null && end == null && at >= 0;
    final range =
        at == null && start is int && end is int && start >= 0 && start < end;
    if (!point && !range) _invalidArguments(call, 'atMs', findings);
  }

  void _validateConflicts(
    List<ToolCall> calls,
    ProjectDocument document,
    List<ValidationFinding> findings,
  ) {
    final exclusiveClips = <String>{};
    final arranged = <String>{};
    final tagsDeleted = <String>{};
    final markersDeleted = <String>{};
    final tagNames = <String>{
      ...document.currentState.tags.map((tag) => tag.name.trim().toLowerCase()),
    };
    for (final call in calls) {
      if (call.name == 'delete_tag' && call.arguments['tagId'] is String) {
        tagsDeleted.add(call.arguments['tagId'] as String);
      }
      if (call.name == 'delete_marker' &&
          call.arguments['markerId'] is String) {
        markersDeleted.add(call.arguments['markerId'] as String);
      }
    }
    for (final call in calls) {
      final args = call.arguments;
      if (call.name == 'trim_clip' || call.name == 'remove_clip_range') {
        final id = args['clipId'];
        if (id is String && !exclusiveClips.add(id)) {
          _conflict(call, 'clipId', findings);
        }
      }
      if (call.name == 'arrange_clips' && args['placements'] is List) {
        for (final item in args['placements'] as List) {
          if (item is Map &&
              item['clipId'] is String &&
              !arranged.add(item['clipId'] as String)) {
            _conflict(call, 'placements', findings);
          }
        }
      }
      if ((call.name == 'update_tag' ||
              call.name == 'assign_tag' ||
              call.name == 'unassign_tag') &&
          args['tagId'] is String &&
          tagsDeleted.contains(args['tagId'])) {
        _conflict(call, 'tagId', findings);
      }
      if (call.name == 'update_marker' &&
          args['markerId'] is String &&
          markersDeleted.contains(args['markerId'])) {
        _conflict(call, 'markerId', findings);
      }
      if (call.name == 'create_tag' &&
          args['name'] is String &&
          !tagNames.add((args['name'] as String).trim().toLowerCase())) {
        _conflict(call, 'name', findings);
      }
    }
  }

  bool _matchesOneOf(Map<String, Object?> value, Map<String, Object?> schema) {
    if (!schema.containsKey('oneOf')) return true;
    final at = value['atMs'];
    final start = value['startMs'];
    final end = value['endMs'];
    return (at is int && start == null && end == null) ||
        (at == null && start is int && end is int && start < end);
  }

  List<ValidationFinding> _deduplicate(Iterable<ValidationFinding> findings) {
    final seen = <String>{};
    return List<ValidationFinding>.unmodifiable([
      for (final finding in findings)
        if (seen.add(
          '${finding.code}\u0000${finding.callId}\u0000${finding.argumentPath}',
        ))
          finding,
    ]);
  }

  void _invalidArguments(
    ToolCall call,
    String path,
    List<ValidationFinding> findings,
  ) => findings.add(
    _finding(
      'invalid_arguments',
      'The tool arguments do not match the required schema.',
      call,
      path.isEmpty ? null : path,
    ),
  );
  void _conflict(
    ToolCall call,
    String path,
    List<ValidationFinding> findings,
  ) => findings.add(
    _finding(
      'conflicting_calls',
      'The editor calls conflict with one another.',
      call,
      path,
    ),
  );
  ValidationFinding _finding(
    String code,
    String message, [
    ToolCall? call,
    String? path,
  ]) => ValidationFinding(
    code: code,
    message: message,
    callId: call?.callId,
    argumentPath: path,
  );
  String pathFor(String base, String key) => base.isEmpty ? key : '$base.$key';
  bool _safeString(String value) =>
      !value.codeUnits.any((unit) => unit < 32 || unit == 127);
  bool _unsafeId(String value) =>
      value.contains('\\') ||
      value.contains('/') ||
      value.contains('://') ||
      value.contains('..') ||
      value.contains(RegExp(r'[|;&`$]'));
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
