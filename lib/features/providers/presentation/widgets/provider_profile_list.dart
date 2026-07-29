import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:flutter/material.dart';

class ProviderProfileList extends StatelessWidget {
  const ProviderProfileList({
    required this.profiles,
    required this.activeProfileId,
    required this.selectedProfileId,
    required this.onSelected,
    super.key,
  });

  final List<ProviderProfile> profiles;
  final String? activeProfileId;
  final String? selectedProfileId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const ValueKey('provider-profile-list'),
    padding: const EdgeInsets.all(8),
    itemCount: profiles.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final profile = profiles[index];
      final selected = profile.id == selectedProfileId;
      final color = profile.deletionPending
          ? ClipMindColors.statusWarning
          : profile.enabled
          ? ClipMindColors.statusReady
          : ClipMindColors.textMuted;
      return Semantics(
        button: true,
        selected: selected,
        label: '${profile.displayName} provider profile',
        child: Material(
          color: selected ? ClipMindColors.accentSoft : Colors.transparent,
          child: InkWell(
            key: ValueKey('provider-profile-${profile.id}'),
            onTap: () => onSelected(profile.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.deletionPending
                              ? 'DELETION PENDING'
                              : profile.id == activeProfileId
                              ? 'ACTIVE'
                              : profile.enabled
                              ? 'READY'
                              : 'DISABLED',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
