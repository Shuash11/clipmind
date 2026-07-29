import 'dart:convert';

import 'package:clipmind/features/agent/domain/entities/normalized_planning_output.dart';
import 'package:clipmind/features/agent/domain/entities/tool_call.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';

/// The deliberately tiny JSON protocol used only where a provider has no
/// native tool transport.  It is not a serialization format for plans.
final class StrictJsonSchemaEncoder {
  StrictJsonSchemaEncoder({EditorToolRegistry? registry})
    : _registry = registry ?? EditorToolRegistry.standard();

  final EditorToolRegistry _registry;
  static const int _maxBodyLength = 100000;
  static const int _maxSummaryLength = 1000;

  String encode({required String summary, required Iterable<ToolCall> calls}) {
    final list = List<ToolCall>.from(calls);
    if (!_safeSummary(summary) ||
        list.isEmpty ||
        list.length > EditorToolRegistry.maxToolCalls) {
      throw ArgumentError('Invalid strict planning output');
    }
    for (final call in list) {
      if (_registry.byName(call.name) == null) {
        throw ArgumentError('Invalid strict planning output');
      }
    }
    final encoded = jsonEncode(<String, Object?>{
      'summary': summary,
      'operations': list
          .map(
            (call) => <String, Object?>{
              'name': call.name,
              'arguments': call.arguments,
            },
          )
          .toList(growable: false),
    });
    if (encoded.length > _maxBodyLength) {
      throw ArgumentError('Strict planning output exceeds the maximum length');
    }
    return encoded;
  }

  NormalizedPlanningOutput decode(String body) {
    if (body.length > _maxBodyLength) return _invalid('response_too_large');
    Object? value;
    try {
      _DuplicateKeyDetector(body).check();
      value = jsonDecode(body);
    } catch (_) {
      return _invalid('invalid_json');
    }
    if (value is! Map || value.keys.any((key) => key is! String)) {
      return _invalid('invalid_response_shape');
    }
    final root = Map<String, Object?>.from(value);
    if (!_exactKeys(root, const {'summary', 'operations'}) ||
        root['summary'] is! String ||
        !_safeSummary(root['summary'] as String) ||
        root['operations'] is! List) {
      return _invalid('invalid_response_shape');
    }
    final operations = root['operations'] as List<Object?>;
    if (operations.isEmpty ||
        operations.length > EditorToolRegistry.maxToolCalls) {
      return _invalid('invalid_operations');
    }
    final calls = <ToolCall>[];
    for (var index = 0; index < operations.length; index++) {
      final raw = operations[index];
      if (raw is! Map || raw.keys.any((key) => key is! String)) {
        return _invalid('invalid_operation');
      }
      final operation = Map<String, Object?>.from(raw);
      if (!_exactKeys(operation, const {'name', 'arguments'}) ||
          operation['name'] is! String ||
          operation['arguments'] is! Map) {
        return _invalid('invalid_operation');
      }
      final arguments = operation['arguments'] as Map;
      if (arguments.keys.any((key) => key is! String) ||
          _registry.byName(operation['name'] as String) == null) {
        return _invalid('invalid_operation');
      }
      try {
        calls.add(
          ToolCall(
            callId: 'fallback-${index + 1}',
            name: operation['name'] as String,
            arguments: Map<String, Object?>.from(arguments),
          ),
        );
      } catch (_) {
        return _invalid('invalid_operation');
      }
    }
    return NormalizedPlanningOutput(
      summary: root['summary'] as String,
      calls: calls,
    );
  }

  bool _safeSummary(String value) =>
      value.trim().isNotEmpty &&
      value.length <= _maxSummaryLength &&
      !value.codeUnits.any((unit) => unit < 32 || unit == 127);

  bool _exactKeys(Map<String, Object?> value, Set<String> expected) =>
      value.length == expected.length && value.keys.every(expected.contains);

  NormalizedPlanningOutput _invalid(String code) =>
      NormalizedPlanningOutput.invalid(
        ValidationFinding(
          code: code,
          message:
              'The model response did not match the required planning format.',
        ),
      );
}

/// jsonDecode intentionally permits repeated object keys.  Reject them before
/// decoding so repeated fields cannot change the meaning of a strict payload.
final class _DuplicateKeyDetector {
  _DuplicateKeyDetector(this.source);
  final String source;
  int _offset = 0;
  static const int _maximumJsonDepth = 64;

  void check() {
    _value(0);
    _space();
    if (_offset != source.length) throw const FormatException();
  }

  void _value(int depth) {
    _space();
    if (_offset >= source.length) throw const FormatException();
    switch (source.codeUnitAt(_offset)) {
      case 123:
        _object(depth);
        return;
      case 91:
        _array(depth);
        return;
      case 34:
        _string();
        return;
      case 116:
        _literal('true');
        return;
      case 102:
        _literal('false');
        return;
      case 110:
        _literal('null');
        return;
      default:
        _number();
        return;
    }
  }

  void _object(int depth) {
    _checkDepth(depth);
    _offset++;
    _space();
    final keys = <String>{};
    if (_take(125)) return;
    while (true) {
      _space();
      final key = _string();
      if (!keys.add(key)) throw const FormatException();
      _space();
      if (!_take(58)) throw const FormatException();
      _value(depth + 1);
      _space();
      if (_take(125)) return;
      if (!_take(44)) throw const FormatException();
    }
  }

  void _array(int depth) {
    _checkDepth(depth);
    _offset++;
    _space();
    if (_take(93)) return;
    while (true) {
      _value(depth + 1);
      _space();
      if (_take(93)) return;
      if (!_take(44)) throw const FormatException();
    }
  }

  String _string() {
    if (!_take(34)) throw const FormatException();
    final buffer = StringBuffer();
    while (_offset < source.length) {
      final unit = source.codeUnitAt(_offset++);
      if (unit == 34) return buffer.toString();
      if (unit < 32) throw const FormatException();
      if (unit != 92) {
        buffer.writeCharCode(unit);
        continue;
      }
      if (_offset >= source.length) throw const FormatException();
      final escaped = source.codeUnitAt(_offset++);
      const simple = <int>{34, 92, 47, 98, 102, 110, 114, 116};
      if (simple.contains(escaped)) {
        buffer.writeCharCode(escaped);
      } else if (escaped == 117) {
        if (_offset + 4 > source.length) throw const FormatException();
        final hex = source.substring(_offset, _offset + 4);
        final value = int.tryParse(hex, radix: 16);
        if (value == null) throw const FormatException();
        buffer.writeCharCode(value);
        _offset += 4;
      } else {
        throw const FormatException();
      }
    }
    throw const FormatException();
  }

  void _literal(String value) {
    if (!source.startsWith(value, _offset)) throw const FormatException();
    _offset += value.length;
  }

  void _number() {
    final match = RegExp(
      r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',
    ).matchAsPrefix(source, _offset);
    if (match == null) throw const FormatException();
    _offset = match.end;
  }

  void _checkDepth(int depth) {
    if (depth >= _maximumJsonDepth) throw const FormatException();
  }

  void _space() {
    while (_offset < source.length) {
      final unit = source.codeUnitAt(_offset);
      if (unit != 32 && unit != 9 && unit != 10 && unit != 13) return;
      _offset++;
    }
  }

  bool _take(int unit) {
    if (_offset < source.length && source.codeUnitAt(_offset) == unit) {
      _offset++;
      return true;
    }
    return false;
  }
}
