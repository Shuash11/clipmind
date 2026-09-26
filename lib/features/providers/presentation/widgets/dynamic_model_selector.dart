import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';
import 'package:clipmind/features/providers/presentation/providers/provider_profile_notifier.dart';
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
    final label = usable
        ? '${profile!.displayName}${profile.selectedModelId == null ? '' : ' · ${profile.selectedModelId}'}'
        : 'Configure AI Providers';
    return Semantics(
      button: true,
      enabled: true,
      label: usable
          ? 'Select model for ${profile!.displayName}'
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
    final definition = ref
        .watch(providerRegistryProvider)
        .definitionFor(profile.providerId);
    final canDiscover =
        profile.providerId == customOpenAiCompatibleProviderId ||
        (definition?.modelDiscoveryIsAvailable ?? false);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    if (discovered.isNotEmpty) ...[
                      Text(
                        'DISCOVERED',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      ...discovered.map(
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
                                .read(providerProfileNotifierProvider.notifier)
                                .selectModel(profile.id, model.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
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
