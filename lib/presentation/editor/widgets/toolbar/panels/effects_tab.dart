import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/constants/effect_presets.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/presentation/editor/providers/selected_clip_provider.dart';
import 'package:clipmind/state/manual_edit_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'panel_notice.dart';

/// The Effects tab: the 8 one-click preset cards from `effectPresets`.
/// A click applies the recipe to the SELECTED timeline clip through
/// `manualEditControllerProvider` — undoable, journaled and persisted
/// exactly like an agent edit. Without a selection the tab shows its
/// select-a-clip state instead.
class EffectsTab extends ConsumerStatefulWidget {
  const EffectsTab({super.key});

  @override
  ConsumerState<EffectsTab> createState() => _EffectsTabState();
}

class _EffectsTabState extends ConsumerState<EffectsTab> {
  /// Short recipe descriptions for the cards (derived from the recipes'
  /// op params).
  static const _descriptions = <String, String>{
    'noir': 'Black & white, high contrast',
    'vintage': 'Faded colors, soft vignette',
    'cinematic': 'Lifted contrast, dark edges',
    'warm': 'Warmer, brighter tones',
    'cool': 'Cool, muted tones',
    'brighten': 'Brighter exposure',
    'soften': 'Gentle blur',
    'dramatic': 'Punchy contrast, deep vignette',
  };

  /// Material icon name → IconData (the `EffectPreset.icon` mapping).
  static const _icons = <String, IconData>{
    'contrast': Icons.contrast,
    'auto_awesome': Icons.auto_awesome,
    'movie': Icons.movie,
    'wb_sunny': Icons.wb_sunny,
    'ac_unit': Icons.ac_unit,
    'brightness_6': Icons.brightness_6,
    'blur_on': Icons.blur_on,
    'theater_comedy': Icons.theater_comedy,
  };

  /// The in-flight submit's preset id; null = idle. Blocks a second
  /// submit until the first finishes (the busy-guard pattern).
  String? _busyPresetId;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider).valueOrNull;
    final selectedClip =
        resolveSelectedClip(project, ref.watch(selectedClipIdProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: selectedClip == null
              ? PanelNotice(
                  message: project == null
                      ? 'Open a project first.'
                      : 'Select a clip first.',
                )
              : Text(
                  'Selected clip: ${clipDisplayLabel(selectedClip)}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              for (final preset in effectPresets)
                _EffectCard(
                  preset: preset,
                  description: _descriptions[preset.id] ?? '',
                  icon: _icons[preset.icon] ?? Icons.auto_fix_high_outlined,
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

  Future<void> _apply(EffectPreset preset) async {
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
          .submitRecipe(preset.id, clipId: clipId);
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

class _EffectCard extends StatelessWidget {
  final EffectPreset preset;
  final String description;
  final IconData icon;
  final bool busy;
  final bool enabled;
  final VoidCallback onApply;

  const _EffectCard({
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
