import 'dart:collection';

const int _maximumJsonDepth = 64;

/// Copies the deliberately small JSON value language accepted at the agent
/// boundary. Keeping this separate from provider serialization prevents local
/// domain objects from accidentally becoming provider request data.
Object? copySafeJsonValue(Object? value) =>
    _copyJsonValue(value, HashSet<Object>.identity(), 0);

Map<String, Object?> immutableSafeJsonMap(Map<String, Object?> value) =>
    copySafeJsonValue(value) as Map<String, Object?>;

Object? _copyJsonValue(Object? value, Set<Object> active, int depth) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) throw ArgumentError('JSON doubles must be finite');
    return value;
  }
  if (depth >= _maximumJsonDepth) {
    throw ArgumentError('JSON nesting exceeds the maximum depth');
  }
  if (value is List<Object?>) {
    return _copyList(value, active, depth);
  }
  if (value is Map<Object?, Object?>) {
    return _copyMap(value, active, depth);
  }
  throw ArgumentError('Unsupported JSON value');
}

List<Object?> _copyList(List<Object?> value, Set<Object> active, int depth) {
  _enter(value, active);
  try {
    return List<Object?>.unmodifiable(
      value.map((item) => _copyJsonValue(item, active, depth + 1)),
    );
  } finally {
    active.remove(value);
  }
}

Map<String, Object?> _copyMap(
  Map<Object?, Object?> value,
  Set<Object> active,
  int depth,
) {
  _enter(value, active);
  try {
    final copy = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError('JSON object keys must be strings');
      }
      copy[entry.key as String] = _copyJsonValue(
        entry.value,
        active,
        depth + 1,
      );
    }
    return Map<String, Object?>.unmodifiable(copy);
  } finally {
    active.remove(value);
  }
}

void _enter(Object value, Set<Object> active) {
  if (!active.add(value)) {
    throw ArgumentError('Cyclic JSON values are not supported');
  }
}
