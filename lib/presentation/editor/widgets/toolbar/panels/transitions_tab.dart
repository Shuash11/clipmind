import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/constants/transition_presets.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/presentation/editor/providers/selected_clip_provider.dart';
import 'package:clipmind/state/manual_edit_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'panel_notice.dart';

/// The Transitions tab: the 8 one-click xfade preset cards from
/// `transitionPresets`. A click merges the SELECTED timeline clip with
/// the NEXT clip on its track through
/// `manualEditControllerProvider.submitTransition` — the pair is
/// replaced (the first clip is repointed, the second removed) and undo
/// does not restore the removed clip, surfaced below as the
/// null-inverse hint. Without a selection (or without a following clip)
/// the tab shows its notice states instead.
class TransitionsTab extends ConsumerStatefulWidget {
  const TransitionsTab({super.key});

  @override
  ConsumerState<TransitionsTab> createState() => _TransitionsTabState();
}

class _TransitionsTabState extends ConsumerState<TransitionsTab> {
  /// Short xfade descriptions for the cards.
  static const _descriptions = <String, String>{
    'fade': 'Smooth opacity cross-fade',
    'dissolve': 'Soft grain-blend dissolve',
    'wipeleft': 'Next clip wipes in from left',
    'wiperight': 'Next clip wipes in from right',
    'slideup': 'Next clip slides up',
    'slidedown': 'Next clip slides down',
    'circleopen': 'Circular reveal into next clip',
    'fadeblack': 'Dips to black between clips',
  };

  /// Material icon name → IconData (the `TransitionPreset.icon` mapping).
  static const _icons = <String, IconData>{
    'opacity': Icons.opacity,
    'auto_awesome': Icons.auto_awesome,
    'arrow_back': Icons.arrow_back,
    'arrow_forward': Icons.arrow_forward,
    'arrow_upward': Icons.arrow_upward,
    'arrow_downward': Icons.arrow_downward,
    'circle': Icons.circle,
    'dark_mode': Icons.dark_mode,
  };

  /// The in-flight submit's preset id; null = idle. Blocks a second
  /// submit until the first finishes (the busy-guard pattern).
  String? _busyPresetId;

  /// Does the selected clip have a following clip on its track (the
  /// `ManualEditController.submitTransition` semantics: same `trackId`,
  /// `positionMs` strictly after the selected clip's)?
  bool _hasFollowingClip(Project? project, Clip selectedClip) {
    if (project == null) return false;
    for (final track in project.tracks) {
      if (track.id != selectedClip.trackId) continue;
      for (final clip in track.clips) {
        if (clip.positionMs > selectedClip.positionMs) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider).value;
    final selectedClip =
        resolveSelectedClip(project, ref.watch(selectedClipIdProvider));
    final needsFollowingClip =
        selectedClip != null && !_hasFollowingClip(project, selectedClip);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selectedClip == null)
                PanelNotice(
                  message: project == null
                      ? 'Open a project first.'
                      : 'Select a clip first.',
                )
              else ...[
                Text(
                  'Selected clip: ${clipDisplayLabel(selectedClip)}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (needsFollowingClip) ...[
                  const SizedBox(height: 8),
                  const PanelNotice(
                    message:
                        'This is the last clip on its track — a transition '
                        'needs a following clip.',
                  ),
                ],
              ],
              const SizedBox(height: 8),
              Text(
                'Transitions merge the selected clip with the next clip on '
                'its track into one output (undo removes the merge).',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ClipMindColors.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              for (final preset in transitionPresets)
                _TransitionCard(
                  preset: preset,
                  description: _descriptions[preset.id] ?? '',
                  icon: _icons[preset.icon] ?? Icons.swap_horiz_rounded,
                  busy: _busyPresetId == preset.id,
                  enabled: _busyPresetId == null,
                  onApply: () => _apply(preset),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _apply(TransitionPreset preset) async {
    if (_busyPresetId != null) return;
    final clipId = ref.read(selectedClipIdProvider);
    if (clipId == null) {
      _showMessage('Select a clip first.');
      return;
    }
    setState(() => _busyPresetId = preset.id);
    try {
      final result = await ref
          .read(manualEditControllerProvider)
          .submitTransition(preset.id, clipId: clipId);
      if (!mounted) return;
      _showMessage(result.message);
    } finally {
      if (mounted) setState(() => _busyPresetId = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }
}

class _TransitionCard extends StatelessWidget {
  final TransitionPreset preset;
  final String description;
  final IconData icon;
  final bool busy;
  final bool enabled;
  final VoidCallback onApply;

  const _TransitionCard({
    required this.preset,
    required this.description,
    required this.icon,
    required this.busy,
    required this.enabled,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled || busy ? 1.0 : 0.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onApply : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ClipMindColors.bgElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ClipMindColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        icon,
                        size: 20,
                        color: ClipMindColors.accentPrimary,
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                preset.label,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
