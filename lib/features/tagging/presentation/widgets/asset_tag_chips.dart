import 'package:clipmind/features/projects/domain/commands/tag_commands.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class AssetTagChips extends ConsumerStatefulWidget {
  const AssetTagChips({required this.assetId, super.key});

  final String assetId;

  @override
  ConsumerState<AssetTagChips> createState() => _AssetTagChipsState();
}

final class _AssetTagChipsState extends ConsumerState<AssetTagChips> {
  bool _busy = false;

  Future<void> _remove(String tagId, TaggingProviders providers) async {
    if (_busy) return;
    setState(() => _busy = true);
    await providers.applyManual(
      providers.controller.unassignTag(
        tagId: tagId,
        targetKind: AssignmentTargetKind.asset,
        targetId: widget.assetId,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(taggingProvidersProvider);
    final document = providers?.document;
    final asset = document?.currentState.assetById(widget.assetId);
    if (providers == null || asset == null) return const SizedBox.shrink();
    final tags = document!.currentState.tags.where(
      (tag) => asset.tagIds.contains(tag.id),
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Semantics(
            label: 'Remove tag ${tag.name} from asset ${widget.assetId}',
            button: true,
            child: ExcludeSemantics(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _remove(tag.id, providers),
                child: Text(tag.name),
              ),
            ),
          ),
      ],
    );
  }
}
