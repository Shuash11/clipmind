import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/presentation/providers/provider_profile_notifier.dart';
import 'package:clipmind/features/providers/presentation/widgets/provider_profile_form.dart';
import 'package:clipmind/features/providers/presentation/widgets/provider_profile_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiProvidersScreen extends ConsumerWidget {
  const AiProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(providerProfileNotifierProvider);
    return Scaffold(
      key: const ValueKey('ai-providers-screen'),
      appBar: AppBar(title: const Text('AI Providers')),
      body: state.isLoading && state.profiles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final rail = _ProfileRail(state: state);
                final surface = _ConfigurationSurface(state: state);
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [
                      SizedBox(height: 230, child: rail),
                      const Divider(height: 1),
                      Expanded(child: surface),
                    ],
                  );
                }
                return Row(
                  children: [
                    SizedBox(width: 280, child: rail),
                    const VerticalDivider(width: 1),
                    Expanded(child: surface),
                  ],
                );
              },
            ),
    );
  }
}

class _ProfileRail extends ConsumerWidget {
  const _ProfileRail({required this.state});
  final ProviderProfileState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    color: ClipMindColors.bgSurface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROFILES',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${state.profiles.length} local profile${state.profiles.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                key: const ValueKey('add-provider-profile'),
                onPressed: () => ref
                    .read(providerProfileNotifierProvider.notifier)
                    .beginCreate(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add profile'),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.profiles.isEmpty
              ? const _EmptyProfiles()
              : ProviderProfileList(
                  profiles: state.profiles,
                  activeProfileId: state.activeProfileId,
                  selectedProfileId: state.selectedProfileId,
                  onSelected: (id) => ref
                      .read(providerProfileNotifierProvider.notifier)
                      .selectProfile(id),
                ),
        ),
      ],
    ),
  );
}

class _ConfigurationSurface extends ConsumerWidget {
  const _ConfigurationSurface({required this.state});
  final ProviderProfileState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.failureMessage != null &&
        state.profiles.isEmpty &&
        !state.creating) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.failureMessage!,
            style: const TextStyle(color: ClipMindColors.statusError),
          ),
        ),
      );
    }
    if (state.creating || state.selectedProfile != null) {
      return ProviderProfileForm(
        key: ValueKey(state.selectedProfile?.id ?? 'new'),
        profile: state.selectedProfile,
      );
    }
    return const _EmptyProfiles();
  }
}

class _EmptyProfiles extends StatelessWidget {
  const _EmptyProfiles();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hub_outlined,
            size: 34,
            color: ClipMindColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No provider profiles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Profiles are local to ClipMind. Credentials use secure storage.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
