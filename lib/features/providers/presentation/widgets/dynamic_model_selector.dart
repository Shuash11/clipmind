import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';
import 'package:clipmind/features/providers/presentation/providers/provider_profile_notifier.dart';
import 'package:clipmind/features/providers/presentation/widgets/model_discovery_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A profile-backed selector. It intentionally has no catalog of models: model
/// options exist only after discovery or explicit, persisted manual entry.
class DynamicModelSelector extends ConsumerWidget {
  const DynamicModelSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(providerProfileNotifierProvider);
    final profile = state.activeProfile;
    final usable = state.hasUsableActiveProfile;
    // Precise hint: presets have class defaults so they run without a
    // selection; the custom profile has none — it runs nothing until a
    // model is chosen.
    final needsModel = usable &&
        profile!.providerId == customOpenAiCompatibleProviderId &&
        profile.selectedModelId == null;
    final modelHint = needsModel ? ' · select a model' : '';
    final label = usable
        ? '${profile!.displayName}${profile.selectedModelId == null ? '' : ' · ${profile.selectedModelId}'}$modelHint'
        : 'Configure AI Providers';
    return Semantics(
      button: true,
      enabled: true,
      label: usable
          ? 'Select model for ${profile!.displayName}$modelHint'
          : 'Configure AI Providers',
      child: Tooltip(
        message: usable ? 'Select model' : 'No enabled provider profile',
        child: Material(
          color: ClipMindColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: const ValueKey('dynamic-model-selector'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => usable
                ? _showPicker(context, ref)
                : context.go(aiProvidersPath),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    usable ? Icons.memory : Icons.settings_outlined,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    final state = ref.read(providerProfileNotifierProvider);
    final profile = state.activeProfile;
    if (profile == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ClipMindColors.bgSurface,
      // The picker hosts a search field above a 520-capped list; letting the
      // sheet size to that cap (instead of 9/16 of the window) keeps the
      // list usable on short windows, where the fixed chrome alone would
      // otherwise starve it of height.
      isScrollControlled: true,
      builder: (sheetContext) => _ModelPicker(profileId: profile.id),
    );
  }
}

class _ModelPicker extends ConsumerStatefulWidget {
  const _ModelPicker({required this.profileId});
  final String profileId;
  @override
  ConsumerState<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends ConsumerState<_ModelPicker> {
  final _manual = TextEditingController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-discover on open when nothing has been discovered yet (paste a
    // key, open the picker, and the available NIM models appear). The
    // in-memory discovered state IS the debounce: it only fires when the
    // list is empty, so reopening never refetches while results exist.
    WidgetsBinding.instance.addPostFrameCallback((_) => _discoverOnOpen());
  }

  void _discoverOnOpen() {
    if (!mounted) return;
    final state = ref.read(providerProfileNotifierProvider);
    // Only usable profiles can run discovery; skipping avoids the notifier
    // surfacing a validation notice inside a freshly opened picker.
    if (!state.hasUsableActiveProfile) return;
    final profile = state.activeProfile!;
    if (profile.id != widget.profileId) return;
    // Do not interrupt an in-flight request; its result will populate the
    // list when it settles.
    if (state.action != ProviderProfileAction.idle) return;
    if ((state.discoveredModels[profile.id] ?? const []).isNotEmpty) return;
    if (!modelDiscoverySupported(ref.read(providerPlatformRegistryProvider), profile)) {
      return;
    }
    ref
        .read(providerProfileNotifierProvider.notifier)
        .discoverModels(profile.id);
  }

  @override
  void dispose() {
    _manual.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(providerProfileNotifierProvider);
    final profile = state.activeProfile;
    if (profile == null || profile.id != widget.profileId) {
      return const SizedBox.shrink();
    }
    final query = _search.text.trim().toLowerCase();
    final manualIds = profile.manualModelIds.toSet();
    final discovered = (state.discoveredModels[profile.id] ?? const [])
        .where((model) => !manualIds.contains(model.id))
        .toList(growable: false);
    final canDiscover = modelDiscoverySupported(
      ref.watch(providerPlatformRegistryProvider),
      profile,
    );
    final groups = _filteredGroups(discovered, query);
    final manualMatches = _filteredManualModels(profile.manualModelIds, query);
    final rows = _buildRows(
      state: state,
      query: query,
      groups: groups,
      manualMatches: manualMatches,
      canDiscover: canDiscover,
      hasDiscovered: discovered.isNotEmpty,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 24,
                child: Stack(
                  children: [
                    const Center(
                      child: SizedBox(
                        width: 36,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: ClipMindColors.borderColor,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        key: const ValueKey('close-model-picker'),
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () => Navigator.of(context).pop(),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SELECT MODEL',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Text(
                profile.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  key: const ValueKey('model-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search models',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey('clear-model-search'),
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _search.clear()),
                          ),
                  ),
                ),
              ),
              if (canDiscover)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    key: const ValueKey('discover-models-picker'),
                    onPressed: state.action == ProviderProfileAction.discovering
                        ? null
                        : () => ref
                              .read(providerProfileNotifierProvider.notifier)
                              .discoverModels(profile.id),
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Discover models'),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Manual model IDs are supported for this provider.',
                  ),
                ),
              if (state.failureMessage ==
                  'Discovery unavailable; enter a model ID.')
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Discovery unavailable; enter a model ID.',
                    style: TextStyle(color: ClipMindColors.statusWarning),
                  ),
                ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) =>
                      _pickerRow(context, rows[index], profile.selectedModelId),
                ),
              ),
              const Divider(),
              TextField(
                key: const ValueKey('manual-model-id'),
                controller: _manual,
                decoration: const InputDecoration(labelText: 'Manual model ID'),
                onSubmitted: _add,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => _add(_manual.text),
                  child: const Text('Use model'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders one flattened row of the picker list.
  Widget _pickerRow(
    BuildContext context,
    _PickerItem row,
    String? selectedModelId,
  ) {
    switch (row) {
      case _DiscoveringItem():
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Discovering models…'),
            ],
          ),
        );
      case _MessageItem(:final message):
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        );
      case _SectionHeaderItem(:final label, :final muted, :final topPadding):
        final baseStyle = Theme.of(context).textTheme.labelSmall;
        return Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: Text(
            label,
            style: muted
                ? baseStyle?.copyWith(color: ClipMindColors.textMuted)
                : baseStyle,
          ),
        );
      case _ModelItem(:final id, :final title, :final subtitle):
        return ListTile(
          key: ValueKey('model-$id'),
          dense: true,
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: id == selectedModelId
              ? const Icon(Icons.check, color: ClipMindColors.accentPrimary)
              : null,
          onTap: () => _selectModel(id),
        );
    }
  }

  /// Flattens status rows, section headers, and model tiles into one item list
  /// so the picker renders through a single lazy list — discovering catalogs
  /// can hold hundreds of models.
  List<_PickerItem> _buildRows({
    required ProviderProfileState state,
    required String query,
    required Map<String, List<ModelDescriptor>> groups,
    required List<String> manualMatches,
    required bool canDiscover,
    required bool hasDiscovered,
  }) {
    final rows = <_PickerItem>[];
    if (state.action == ProviderProfileAction.discovering) {
      rows.add(const _DiscoveringItem());
    } else if (query.isNotEmpty) {
      if (groups.isEmpty && manualMatches.isEmpty) {
        rows.add(const _MessageItem('No models match'));
      }
    } else if (canDiscover && !hasDiscovered && state.failureMessage == null) {
      rows.add(
        const _MessageItem(
          'No models discovered yet. Use Discover or enter a model ID below.',
        ),
      );
    }
    if (groups.isNotEmpty) {
      rows.add(const _SectionHeaderItem('DISCOVERED', topPadding: 0));
      for (final group in groups.entries) {
        rows.add(_SectionHeaderItem(group.key.toUpperCase(), muted: true));
        rows.addAll(
          group.value.map(
            (model) => _ModelItem(
              id: model.id,
              title: model.displayName,
              subtitle: model.id,
            ),
          ),
        );
      }
    }
    if (manualMatches.isNotEmpty) {
      rows.add(const _SectionHeaderItem('MANUAL'));
      rows.addAll(manualMatches.map((id) => _ModelItem(id: id, title: id)));
    }
    return rows;
  }

  /// Groups discovered models by org, dropping groups with no match. A query
  /// matching the org key surfaces the whole group; otherwise a model matches
  /// on its ID or display name. An empty [query] keeps every group.
  Map<String, List<ModelDescriptor>> _filteredGroups(
    List<ModelDescriptor> models,
    String query,
  ) {
    final grouped = groupDiscoveredByOrg(models);
    if (query.isEmpty) return grouped;
    final filtered = <String, List<ModelDescriptor>>{};
    for (final group in grouped.entries) {
      final matches = group.key.contains(query)
          ? group.value
          : group.value
                .where(
                  (model) =>
                      model.id.toLowerCase().contains(query) ||
                      model.displayName.toLowerCase().contains(query),
                )
                .toList(growable: false);
      if (matches.isNotEmpty) {
        filtered[group.key] = matches;
      }
    }
    return filtered;
  }

  List<String> _filteredManualModels(List<String> models, String query) {
    if (query.isEmpty) return models;
    return models
        .where((id) => id.toLowerCase().contains(query))
        .toList(growable: false);
  }

  Future<void> _add(String value) async {
    if (value.trim().isEmpty) return;
    await ref
        .read(providerProfileNotifierProvider.notifier)
        .addManualModel(widget.profileId, value);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _selectModel(String modelId) async {
    await ref
        .read(providerProfileNotifierProvider.notifier)
        .selectModel(widget.profileId, modelId);
    if (mounted) Navigator.pop(context);
  }
}

/// One flattened row in the model picker: a status line, a section header, or
/// a selectable model. Rows are data-only so the list builder can render them
/// lazily and the row switch stays exhaustive.
sealed class _PickerItem {
  const _PickerItem();
}

final class _DiscoveringItem extends _PickerItem {
  const _DiscoveringItem();
}

final class _MessageItem extends _PickerItem {
  const _MessageItem(this.message);
  final String message;
}

final class _SectionHeaderItem extends _PickerItem {
  const _SectionHeaderItem(
    this.label, {
    this.muted = false,
    this.topPadding = 8,
  });
  final String label;
  final bool muted;
  final double topPadding;
}

final class _ModelItem extends _PickerItem {
  const _ModelItem({required this.id, required this.title, this.subtitle});
  final String id;
  final String title;
  final String? subtitle;
}

const String otherOrgGroupKey = 'other';

/// Groups discovered models by the organisation prefix of their ID
/// (`meta/llama-3` -> META). Keys are normalized to lowercase so orgs group
/// case-insensitively; models without a prefix fall into a trailing OTHER
/// group. Keys are sorted alphabetically for a stable order; models keep
/// their discovery order inside each group.
Map<String, List<ModelDescriptor>> groupDiscoveredByOrg(
  List<ModelDescriptor> models,
) {
  final named = <String, List<ModelDescriptor>>{};
  final other = <ModelDescriptor>[];
  for (final model in models) {
    final split = model.id.indexOf('/');
    if (split > 0) {
      named
          .putIfAbsent(
            model.id.substring(0, split).toLowerCase(),
            () => <ModelDescriptor>[],
          )
          .add(model);
    } else {
      other.add(model);
    }
  }
  final keys = named.keys.toList()..sort();
  return <String, List<ModelDescriptor>>{
    for (final key in keys)
      key: List<ModelDescriptor>.unmodifiable(named[key]!),
    if (other.isNotEmpty)
      otherOrgGroupKey: List<ModelDescriptor>.unmodifiable(other),
  };
}
