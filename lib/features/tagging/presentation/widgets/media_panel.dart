import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/tagging/domain/tag_query.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:clipmind/features/tagging/presentation/widgets/asset_tag_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class MediaPanel extends ConsumerWidget {
  const MediaPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(taggingProvidersProvider);
    final document = providers?.document;
    if (document == null) {
      return const _MediaPanelMessage('No project available');
    }

    final query = ref.watch(tagQueryProvider);
    final selectedAssetId = ref.watch(selectedAssetIdProvider);
    final assets = query.filter(document.currentState.assets);
    final tagsById = {
      for (final tag in document.currentState.tags) tag.id: tag,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClipMindColors.bgSurface,
        border: Border.all(color: ClipMindColors.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search media',
              isDense: true,
            ),
            onChanged: (text) {
              final current = ref.read(tagQueryProvider);
              ref.read(tagQueryProvider.notifier).state = TagQuery(
                text: text,
                selectedTagIds: current.selectedTagIds,
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in document.currentState.tags)
                Semantics(
                  label: 'Filter by tag ${tag.name}',
                  button: true,
                  child: ExcludeSemantics(
                    child: FilterChip(
                      label: Text(tag.name),
                      selected: query.selectedTagIds.contains(tag.id),
                      onSelected: (selected) {
                        final current = ref.read(tagQueryProvider);
                        final next = {...current.selectedTagIds};
                        if (selected) {
                          next.add(tag.id);
                        } else {
                          next.remove(tag.id);
                        }
                        ref.read(tagQueryProvider.notifier).state = TagQuery(
                          text: current.text,
                          selectedTagIds: next,
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (assets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No media assets'),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: assets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final asset = assets[index];
                  final isSelected = selectedAssetId == asset.id;
                  return Semantics(
                    label: isSelected
                        ? 'Selected asset ${asset.id}'
                        : 'Select asset ${asset.id}',
                    button: true,
                    selected: isSelected,
                    child: ExcludeSemantics(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () =>
                            ref.read(selectedAssetIdProvider.notifier).state =
                                asset.id,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ClipMindColors.accentSoft
                                : ClipMindColors.bgElevated,
                            border: Border.all(
                              color: isSelected
                                  ? ClipMindColors.accentPrimary
                                  : ClipMindColors.borderColor,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(asset.displayName)),
                              for (final tagId in asset.tagIds)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    tagsById[tagId]?.name ?? '',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (selectedAssetId != null) ...[
            const SizedBox(height: 8),
            AssetTagChips(assetId: selectedAssetId),
          ],
        ],
      ),
    );
  }
}

final class _MediaPanelMessage extends StatelessWidget {
  const _MediaPanelMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ClipMindColors.bgSurface,
      border: Border.all(color: ClipMindColors.borderColor),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(message),
  );
}
