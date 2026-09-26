import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/tag_commands.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class ClipTagInspector extends ConsumerStatefulWidget {
  const ClipTagInspector({required this.clipId, super.key});

  final String clipId;

  @override
  ConsumerState<ClipTagInspector> createState() => _ClipTagInspectorState();
}

final class _ClipTagInspectorState extends ConsumerState<ClipTagInspector> {
  bool _busy = false;

  Future<void> _apply({
    required String tagId,
    required bool assigned,
    required TaggingProviders providers,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final command = assigned
        ? providers.controller.unassignTag(
            tagId: tagId,
            targetKind: AssignmentTargetKind.clip,
            targetId: widget.clipId,
          )
        : providers.controller.assignTag(
            tagId: tagId,
            targetKind: AssignmentTargetKind.clip,
            targetId: widget.clipId,
          );
    await providers.applyManual(command);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(taggingProvidersProvider);
    final document = providers?.document;
    if (providers == null || document == null) {
      return const Text('Clip unavailable');
    }
    final clip = findClip(document.currentState, widget.clipId);
    if (clip == null) return const Text('Clip unavailable');

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in document.currentState.tags)
          _TagAction(
            tagName: tag.name,
            assigned: clip.tagIds.contains(tag.id),
            busy: _busy,
            clipId: widget.clipId,
            onPressed: () => _apply(
              tagId: tag.id,
              assigned: clip.tagIds.contains(tag.id),
              providers: providers,
            ),
          ),
      ],
    );
  }
}

final class _TagAction extends StatelessWidget {
  const _TagAction({
    required this.tagName,
    required this.assigned,
    required this.busy,
    required this.clipId,
    required this.onPressed,
  });

  final String tagName;
  final bool assigned;
  final bool busy;
  final String clipId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = assigned
        ? 'Remove tag $tagName from clip $clipId'
        : 'Add tag $tagName to clip $clipId';
    return Semantics(
      label: label,
      button: true,
      child: ExcludeSemantics(
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          child: Text(assigned ? 'Remove $tagName' : 'Add $tagName'),
        ),
      ),
    );
  }
}
