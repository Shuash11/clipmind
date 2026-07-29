import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/features/agent/domain/entities/normalized_planning_output.dart';
import 'package:clipmind/features/agent/domain/entities/tool_call.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';

/// Read-only bridge for the old typed operation representation.  Unlike the
/// strict provider JSON decoder, this recognizes a deliberately small list of
/// complete legacy aliases and never produces project commands.
final class LegacyOperationNormalizer {
  LegacyOperationNormalizer({EditorToolRegistry? registry})
    : _registry = registry ?? EditorToolRegistry.standard();

  final EditorToolRegistry _registry;

  NormalizedPlanningOutput normalize(Iterable<Object?> values) {
    final source = List<Object?>.from(values);
    if (source.isEmpty) return _invalid('invalid_operation');
    if (source.length > EditorToolRegistry.maxToolCalls) {
      return _invalid('too_many_calls');
    }
    final calls = <ToolCall>[];
    final findings = <ValidationFinding>[];
    final ids = <String>{};
    for (var index = 0; index < source.length; index++) {
      final raw = source[index];
      final map = _asMap(raw);
      if (map == null) {
        findings.add(_finding('invalid_operation'));
        continue;
      }
      final id = _id(map, index);
      if (id == null) {
        findings.add(_finding('ambiguous_legacy_operation'));
        continue;
      }
      if (!ids.add(id)) {
        findings.add(_finding('duplicate_call_id'));
        continue;
      }
      final converted = _convert(map, id);
      if (converted == null) {
        findings.add(_finding(_legacyFailureCode(map)));
      } else {
        calls.add(converted);
      }
    }
    return NormalizedPlanningOutput(
      summary: 'Legacy editor operations were normalized.',
      calls: calls,
      findings: findings,
    );
  }

  Map<String, Object?>? _asMap(Object? raw) {
    if (raw is Map && raw.keys.every((key) => key is String)) {
      return Map<String, Object?>.from(raw);
    }
    if (raw is EditOperationRequest) {
      return <String, Object?>{
        'id': raw.id,
        'type': raw.type,
        'targetClipId': raw.targetClipId,
        'params': Map<String, Object?>.from(raw.params),
      };
    }
    return null;
  }

  String _legacyFailureCode(Map<String, Object?> map) {
    final name = _oneString(map, const ['name', 'type', 'operation']);
    const supported = {
      'trim',
      'cut',
      'change_speed',
      'mute',
      'change_volume',
      'adjust_brightness',
      'overlay_text',
      'transform',
      'resize_rotate',
    };
    const deferred = {
      'merge',
      'extract_audio',
      'generate_thumbnail',
      'change_format',
      'path',
      'output',
    };
    if (name == null) return 'ambiguous_legacy_operation';
    if (deferred.contains(name) ||
        (!supported.contains(name) && _registry.byName(name) == null)) {
      return 'unsupported_legacy_operation';
    }
    return 'ambiguous_legacy_operation';
  }

  String? _id(Map<String, Object?> map, int index) {
    final callId = map['callId'];
    final id = map['id'];
    if (callId != null && id != null && callId != id) return null;
    final value = callId ?? id;
    if (value != null && (value is! String || value.trim().isEmpty)) {
      return null;
    }
    return value as String? ?? 'legacy-${index + 1}';
  }

  ToolCall? _convert(Map<String, Object?> map, String id) {
    final name = _oneString(map, const ['name', 'type', 'operation']);
    if (name == null) return null;
    final rawArguments = _oneMap(map, const ['arguments', 'params']);
    if (_registry.byName(name) != null) {
      if (rawArguments == null || !_canonicalEnvelope(map, name)) return null;
      return _call(id, name, rawArguments);
    }
    final args = rawArguments ?? _directArguments(map);
    if (args == null) return null;
    final clipId = _oneValue(
      rawArguments == null ? const <String, Object?>{} : map,
      args,
      const ['clipId', 'targetClipId', 'clip_id'],
    );
    final payload = _withoutIds(args);
    switch (name) {
      case 'trim':
        return _call(id, 'trim_clip', _clipRange(clipId, payload));
      case 'cut':
        return _call(
          id,
          'remove_clip_range',
          _removeClipRange(clipId, payload),
        );
      case 'change_speed':
        return _call(
          id,
          'set_clip_speed',
          _with(clipId, payload, 'clipId', const ['speed']),
        );
      case 'mute':
        return _call(
          id,
          'set_clip_muted',
          _with(clipId, payload, 'clipId', const ['muted']),
        );
      case 'change_volume':
        return _call(
          id,
          'set_clip_volume',
          _with(clipId, payload, 'clipId', const ['volume']),
        );
      case 'adjust_brightness':
        return _call(id, 'set_clip_brightness', _brightness(clipId, payload));
      case 'overlay_text':
        return _call(
          id,
          'add_text_overlay',
          _only(args, const ['trackId', 'startMs', 'endMs', 'text', 'x', 'y']),
        );
      case 'transform':
      case 'resize_rotate':
        return _call(id, 'set_clip_transform', _transform(clipId, payload));
      default:
        return null;
    }
  }

  bool _canonicalEnvelope(Map<String, Object?> map, String name) {
    const allowed = {
      'id',
      'callId',
      'name',
      'type',
      'operation',
      'arguments',
      'params',
    };
    return map.keys.every(allowed.contains) &&
        _oneString(map, const ['name', 'type', 'operation']) == name &&
        _oneMap(map, const ['arguments', 'params']) != null;
  }

  Map<String, Object?>? _clipRange(Object? clipId, Map<String, Object?> args) {
    if (clipId is! String) return null;
    final start = _oneValue(const {}, args, const [
      'startMs',
      'start_ms',
      'removeStartMs',
    ]);
    final end = _oneValue(const {}, args, const [
      'endMs',
      'end_ms',
      'removeEndMs',
    ]);
    if (start is! int || end is! int) return null;
    return <String, Object?>{'clipId': clipId, 'startMs': start, 'endMs': end};
  }

  Map<String, Object?>? _removeClipRange(
    Object? clipId,
    Map<String, Object?> args,
  ) {
    if (clipId is! String) return null;
    final start = _oneValue(const <String, Object?>{}, args, const [
      'removeStartMs',
      'remove_start_ms',
    ]);
    final end = _oneValue(const <String, Object?>{}, args, const [
      'removeEndMs',
      'remove_end_ms',
    ]);
    if (start is! int || end is! int || args.length != 2) return null;
    return <String, Object?>{'clipId': clipId, 'startMs': start, 'endMs': end};
  }

  Map<String, Object?>? _brightness(Object? clipId, Map<String, Object?> args) {
    if (clipId is! String || args.length != 1) return null;
    final value = _oneValue(const <String, Object?>{}, args, const [
      'brightness',
      'value',
    ]);
    return value == null
        ? null
        : <String, Object?>{'clipId': clipId, 'brightness': value};
  }

  Map<String, Object?>? _transform(Object? clipId, Map<String, Object?> args) {
    if (clipId is! String) return null;
    final result = _only(args, const [
      'width',
      'height',
      'fit',
      'rotationDegrees',
    ]);
    return result == null
        ? null
        : <String, Object?>{'clipId': clipId, ...result};
  }

  Map<String, Object?>? _with(
    Object? id,
    Map<String, Object?> args,
    String key,
    List<String> fields,
  ) {
    if (id is! String) return null;
    final result = _only(args, fields);
    return result == null ? null : <String, Object?>{key: id, ...result};
  }

  Map<String, Object?>? _only(Map<String, Object?> args, List<String> fields) {
    if (args.length != fields.length || !fields.every(args.containsKey)) {
      return null;
    }
    return Map<String, Object?>.from(args);
  }

  Map<String, Object?>? _directArguments(Map<String, Object?> map) {
    const skipped = {'id', 'callId', 'name', 'type', 'operation'};
    final result = <String, Object?>{
      for (final entry in map.entries)
        if (!skipped.contains(entry.key)) entry.key: entry.value,
    };
    return result.isEmpty ? null : result;
  }

  Map<String, Object?> _withoutIds(Map<String, Object?> args) =>
      <String, Object?>{
        for (final entry in args.entries)
          if (!const {'clipId', 'targetClipId', 'clip_id'}.contains(entry.key))
            entry.key: entry.value,
      };

  Object? _oneValue(
    Map<String, Object?> outer,
    Map<String, Object?> args,
    List<String> keys,
  ) {
    final values = <Object?>[
      for (final key in keys)
        if (outer.containsKey(key)) outer[key],
      for (final key in keys)
        if (args.containsKey(key)) args[key],
    ];
    if (values.length != 1) return null;
    return values.single;
  }

  String? _oneString(Map<String, Object?> map, List<String> keys) {
    final values = <Object?>[
      for (final key in keys)
        if (map.containsKey(key)) map[key],
    ];
    return values.length == 1 && values.single is String
        ? values.single as String
        : null;
  }

  Map<String, Object?>? _oneMap(Map<String, Object?> map, List<String> keys) {
    final values = <Object?>[
      for (final key in keys)
        if (map.containsKey(key)) map[key],
    ];
    if (values.length != 1 || values.single is! Map) return null;
    final value = values.single as Map;
    if (value.keys.any((key) => key is! String)) return null;
    return Map<String, Object?>.from(value);
  }

  ToolCall? _call(String id, String name, Map<String, Object?>? args) {
    if (args == null || !_argumentsMatch(name, args)) return null;
    try {
      return ToolCall(callId: id, name: name, arguments: args);
    } catch (_) {
      return null;
    }
  }

  bool _argumentsMatch(String name, Map<String, Object?> value) {
    final schema = _registry.byName(name)?.inputSchema;
    return schema != null && _matches(value, schema);
  }

  bool _matches(Object? value, Map<String, Object?> schema) {
    switch (schema['type']) {
      case 'object':
        if (value is! Map || value.keys.any((key) => key is! String)) {
          return false;
        }
        final map = Map<String, Object?>.from(value);
        final properties =
            schema['properties'] as Map<String, Object?>? ?? const {};
        final required = schema['required'] as List<Object?>? ?? const [];
        if (schema['additionalProperties'] == false &&
            map.keys.any((key) => !properties.containsKey(key))) {
          return false;
        }
        if (required.any((key) => key is! String || !map.containsKey(key))) {
          return false;
        }
        for (final entry in map.entries) {
          final child = properties[entry.key];
          if (child is Map<String, Object?> && !_matches(entry.value, child)) {
            return false;
          }
        }
        final at = map['atMs'];
        final start = map['startMs'];
        final end = map['endMs'];
        if (schema.containsKey('oneOf') &&
            !((at is int && start == null && end == null) ||
                (at == null && start is int && end is int && start < end))) {
          return false;
        }
        return true;
      case 'array':
        if (value is! List) return false;
        final min = schema['minItems'] as int?;
        final max = schema['maxItems'] as int?;
        if ((min != null && value.length < min) ||
            (max != null && value.length > max)) {
          return false;
        }
        final item = schema['items'];
        return item is! Map<String, Object?> ||
            value.every((entry) => _matches(entry, item));
      case 'string':
        if (value is! String ||
            value.codeUnits.any((unit) => unit < 32 || unit == 127)) {
          return false;
        }
        final min = schema['minLength'] as int?;
        final max = schema['maxLength'] as int?;
        final pattern = schema['pattern'] as String?;
        final allowed = schema['enum'] as List<Object?>?;
        return (min == null || value.length >= min) &&
            (max == null || value.length <= max) &&
            (pattern == null || RegExp(pattern).hasMatch(value)) &&
            (allowed == null || allowed.contains(value));
      case 'integer':
        if (value is! int) return false;
        return _inRange(value, schema);
      case 'number':
        if (value is! num || !value.isFinite) return false;
        return _inRange(value, schema);
      case 'boolean':
        return value is bool;
      default:
        return false;
    }
  }

  bool _inRange(num value, Map<String, Object?> schema) {
    final minimum = schema['minimum'] as num?;
    final maximum = schema['maximum'] as num?;
    return (minimum == null || value >= minimum) &&
        (maximum == null || value <= maximum);
  }

  ValidationFinding _finding(String code) => ValidationFinding(
    code: code,
    message: 'A legacy operation could not be normalized safely.',
  );
  NormalizedPlanningOutput _invalid(String code) => NormalizedPlanningOutput(
    summary: 'Legacy editor operations were rejected.',
    findings: [_finding(code)],
  );
}
