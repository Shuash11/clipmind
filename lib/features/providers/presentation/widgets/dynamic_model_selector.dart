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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(providerProfileNotifierProvider);
    final profile = state.activeProfile;
    if (profile == null || profile.id != widget.profileId) {
      return const SizedBox.shrink();
    }
    final manualIds = profile.manualModelIds.toSet();
    final discovered = (state.discoveredModels[profile.id] ?? const [])
        .where((model) => !manualIds.contains(model.id))
        .toList(growable: false);
    final canDiscover = modelDiscoverySupported(
      ref.watch(providerPlatformRegistryProvider),
      profile,
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
                child: ListView(
                  children: [
                    if (state.action == ProviderProfileAction.discovering)
                      const Padding(
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
                      )
                    else if (canDiscover &&
                        discovered.isEmpty &&
                        state.failureMessage == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'No models discovered yet. Use Discover or enter a model ID below.',
                        ),
                      ),
                    if (discovered.isNotEmpty) ...[
                      Text(
                        'DISCOVERED',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      ...groupDiscoveredByOrg(discovered).entries.expand(
                        (group) => <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              group.key.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: ClipMindColors.textMuted,
                                  ),
                            ),
                          ),
                          ...group.value.map(
                            (model) => ListTile(
                              dense: true,
                              title: Text(model.displayName),
                              subtitle: Text(model.id),
                              trailing: model.id == profile.selectedModelId
                                  ? const Icon(
                                      Icons.check,
                                      color: ClipMindColors.accentPrimary,
                                    )
                                  : null,
                              onTap: () async {
                                await ref
                                    .read(
                                      providerProfileNotifierProvider.notifier,
                                    )
                                    .selectModel(profile.id, model.id);
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (profile.manualModelIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'MANUAL',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      ...profile.manualModelIds.map(
                        (model) => ListTile(
                          dense: true,
                          title: Text(model),
                          trailing: model == profile.selectedModelId
                              ? const Icon(
                                  Icons.check,
                                  color: ClipMindColors.accentPrimary,
                                )
                              : null,
                          onTap: () async {
                            await ref
                                .read(providerProfileNotifierProvider.notifier)
                                .selectModel(profile.id, model);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ],
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

  Future<void> _add(String value) async {
    if (value.trim().isEmpty) return;
    await ref
        .read(providerProfileNotifierProvider.notifier)
        .addManualModel(widget.profileId, value);
    if (mounted) Navigator.pop(context);
  }
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
