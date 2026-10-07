import 'tool_definition.dart';
import 'tool_registry.dart';

/// Outcome of one `load_tools` request (typed; never throws).
///
/// Requests are all-or-nothing: either every requested name is a deferred
/// tool that is not active yet, or nothing changes. Failed requests do not
/// consume the per-run load budget.
class ToolLoadResult {
  /// Deferred names newly activated by this request.
  final List<String> loaded;

  /// Requested names that are not deferred catalog tools.
  final List<String> unknown;

  /// Requested names already active (core or previously loaded).
  final List<String> alreadyAvailable;

  /// Every deferred catalog name, for actionability on failure.
  final List<String> validDeferred;

  /// True when the per-run load budget was already spent.
  final bool limitReached;

  const ToolLoadResult({
    this.loaded = const [],
    this.unknown = const [],
    this.alreadyAvailable = const [],
    this.validDeferred = const [],
    this.limitReached = false,
  });

  bool get success =>
      !limitReached &&
      loaded.isNotEmpty &&
      unknown.isEmpty &&
      alreadyAvailable.isEmpty;

  /// Trace summary (success) or typed error (failure) for the model.
  String get message {
    if (success) {
      return 'Loaded ${loaded.join(', ')}. Available from the next round.';
    }
    final problems = <String>[
      if (limitReached)
        'load limit reached (max ${ToolSelection.maxToolLoads} per run)',
      if (unknown.isNotEmpty) 'unknown names: ${unknown.join(', ')}',
      if (alreadyAvailable.isNotEmpty)
        'already available: ${alreadyAvailable.join(', ')}',
    ];
    final reason = problems.isEmpty
        ? 'no tool names provided'
        : problems.join('; ');
    return 'No tools loaded ($reason). '
        'Valid deferred names: ${validDeferred.join(', ')}.';
  }
}

/// Per-run tool exposure: core tools ride every round's payload; deferred
/// tools stay hidden until the model loads them through the reserved
/// [loadToolsName] meta-tool.
///
/// Single responsibility: decide which definitions each round offers and
/// validate load requests. The agent loop owns the `load_tools` call
/// handling (activity, records, history); this class owns the state.
/// Create one per run — the loaded set resets between runs.
class ToolSelection {
  /// Reserved meta-tool name. Never a catalog tool, never in the executor
  /// map — the agent loop handles it directly.
  static const String loadToolsName = 'load_tools';

  /// Max successful `load_tools` calls per run.
  static const int maxToolLoads = 2;

  /// The reserved `load_tools` definition offered while [loaderAvailable].
  static const ToolDefinition loadToolsDefinition = ToolDefinition(
    name: loadToolsName,
    description:
        'Load specialized tools that are not listed yet. Pass only names '
        'from the DEFERRED TOOLS list in the system prompt. Loaded tools '
        'become callable on your next round.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'tools': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Deferred tool names to load.',
        },
      },
      'required': ['tools'],
      'additionalProperties': false,
    },
    category: ToolCategory.read,
  );

  final ToolRegistry registry;
  final Set<String> _loaded = <String>{};
  int _loadsUsed = 0;

  ToolSelection(this.registry);

  /// Successful loads so far this run.
  int get loadsUsed => _loadsUsed;

  /// Remaining successful-load budget this run.
  int get loadsRemaining =>
      _loadsUsed >= maxToolLoads ? 0 : maxToolLoads - _loadsUsed;

  /// True when [name] is currently offered: a core tool or a loaded one.
  /// Unknown and not-yet-loaded deferred names are inactive.
  bool isActive(String name) =>
      registry.definitionFor(name)?.exposure == ToolExposure.core ||
      _loaded.contains(name);

  /// Catalog-order definitions currently active: core + loaded deferred.
  List<ToolDefinition> activeDefinitions() => [
    for (final def in registry.definitions())
      if (def.exposure == ToolExposure.core || _loaded.contains(def.name)) def,
  ];

  /// Deferred catalog names in catalog order.
  List<String> deferredNames() => [
    for (final def in registry.definitions())
      if (def.exposure == ToolExposure.deferred) def.name,
  ];

  /// True while a deferred tool is still hidden and budget remains.
  bool get loaderAvailable =>
      _loadsUsed < maxToolLoads &&
      deferredNames().any((name) => !_loaded.contains(name));

  /// Definitions to offer this round: [activeDefinitions] plus the loader
  /// while [loaderAvailable]. Catalog order stays stable; the loader is
  /// appended last.
  List<ToolDefinition> roundDefinitions() {
    final definitions = activeDefinitions();
    if (!loaderAvailable) return definitions;
    return [...definitions, loadToolsDefinition];
  }

  /// Validate and activate [names] (all-or-nothing).
  ///
  /// A request succeeds only when every name is a deferred tool that is
  /// not active yet and the load budget remains; then all names activate
  /// and the budget drops by one. Any unknown or already-available name,
  /// an empty request, or a spent budget changes nothing.
  ToolLoadResult load(List<String> names) {
    final limitReached = _loadsUsed >= maxToolLoads;
    final deferred = deferredNames().toSet();
    final unknown = <String>[];
    final alreadyAvailable = <String>[];
    final candidates = <String>{};
    for (final name in names) {
      if (_loaded.contains(name) ||
          registry.definitionFor(name)?.exposure == ToolExposure.core) {
        alreadyAvailable.add(name);
      } else if (deferred.contains(name)) {
        candidates.add(name);
      } else {
        unknown.add(name);
      }
    }
    final valid =
        unknown.isEmpty && alreadyAvailable.isEmpty && candidates.isNotEmpty;
    if (limitReached || !valid) {
      return ToolLoadResult(
        unknown: unknown,
        alreadyAvailable: alreadyAvailable,
        validDeferred: deferredNames(),
        limitReached: limitReached,
      );
    }
    final loaded = candidates.toList();
    _loaded.addAll(loaded);
    _loadsUsed++;
    return ToolLoadResult(loaded: loaded, validDeferred: deferredNames());
  }
}
