import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/presentation/editor/providers/selected_clip_provider.dart';
import 'package:clipmind/state/manual_edit_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'panel_notice.dart';

/// The Adjustments tab: the 5 CapCut-parity sliders (brightness,
/// contrast, saturation, speed, volume) for the SELECTED timeline clip.
/// The sliders update their value displays live while dragging; the
/// Apply button submits all non-neutral values as ONE composed render
/// through `manualEditControllerProvider.submitAdjustments` — undoable,
/// journaled and persisted exactly like an agent edit. Without a
/// selection the tab shows its select-a-clip state instead.
class AdjustmentsTab extends ConsumerStatefulWidget {
  const AdjustmentsTab({super.key});

  @override
  ConsumerState<AdjustmentsTab> createState() => _AdjustmentsTabState();
}

class _AdjustmentsTabState extends ConsumerState<AdjustmentsTab> {
  /// The slider neutral values (the `submitAdjustments` semantics: only
  /// non-neutral values become ops). The sliders represent deltas from
  /// the clip's current state — the clip model carries ranges and
  /// transformations, not brightness/speed state, so they start neutral.
  static const double _neutralBrightness = 0.0;
  static const double _neutralContrast = 1.0;
  static const double _neutralSaturation = 1.0;
  static const double _neutralSpeed = 1.0;
  static const double _neutralVolume = 1.0;

  double _brightness = _neutralBrightness;
  double _contrast = _neutralContrast;
  double _saturation = _neutralSaturation;
  double _speed = _neutralSpeed;
  double _volume = _neutralVolume;

  /// Whether a submit is in flight. Blocks a second submit (and a mid-
  /// flight Reset) until the first finishes (the busy-guard pattern).
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider).value;
    final selectedClip =
        resolveSelectedClip(project, ref.watch(selectedClipIdProvider));
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
              else
                Text(
                  'Selected clip: ${clipDisplayLabel(selectedClip)}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Text(
                'Adjustments apply to the selected clip as one render '
                '(undo restores the previous state).',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ClipMindColors.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              _AdjustmentSlider(
                label: 'Brightness',
                value: _brightness,
                valueText: _formatValue(_brightness, signed: true),
                min: -1.0,
                max: 1.0,
                onChanged: (value) => setState(() => _brightness = value),
              ),
              const SizedBox(height: 4),
              _AdjustmentSlider(
                label: 'Contrast',
                value: _contrast,
                valueText: _formatValue(_contrast),
                min: 0.0,
                max: 3.0,
                onChanged: (value) => setState(() => _contrast = value),
              ),
              const SizedBox(height: 4),
              _AdjustmentSlider(
                label: 'Saturation',
                value: _saturation,
                valueText: _formatValue(_saturation),
                min: 0.0,
                max: 3.0,
                onChanged: (value) => setState(() => _saturation = value),
              ),
              const SizedBox(height: 4),
              _AdjustmentSlider(
                label: 'Speed',
                value: _speed,
                valueText: _formatValue(_speed, suffix: '×'),
                min: 0.25,
                max: 4.0,
                onChanged: (value) => setState(() => _speed = value),
              ),
              const SizedBox(height: 4),
              _AdjustmentSlider(
                label: 'Volume',
                value: _volume,
                valueText: _formatValue(_volume),
                min: 0.0,
                max: 2.0,
                onChanged: (value) => setState(() => _volume = value),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _apply,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply adjustments'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : _reset,
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Apply-button design (over per-slider auto-apply): a full FFmpeg
  /// render per slider release would fire up to 5 renders per adjustment
  /// pass (one per `onChangeEnd`), so the sliders only update their
  /// value DISPLAYS live via `onChanged` (CapCut-like feedback without
  /// triggering renders) and one Apply submits ALL non-neutral slider
  /// values in ONE `submitAdjustments` call — the controller composes
  /// them into a single FFmpeg job. Only non-neutral values are passed
  /// (nulls otherwise); the controller also skips neutrals defensively,
  /// and an all-neutral Apply returns success with 'Nothing to adjust.'
  /// and zero FFmpeg runs.
  Future<void> _apply() async {
    if (_busy) return;
    final clipId = ref.read(selectedClipIdProvider);
    if (clipId == null) {
      _showMessage('Select a clip first.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(manualEditControllerProvider)
          .submitAdjustments(
            clipId: clipId,
            brightness: _brightness == _neutralBrightness
                ? null
                : _brightness,
            contrast:
                _contrast == _neutralContrast ? null : _contrast,
            saturation: _saturation == _neutralSaturation
                ? null
                : _saturation,
            speed: _speed == _neutralSpeed ? null : _speed,
            volume: _volume == _neutralVolume ? null : _volume,
          );
      if (!mounted) return;
      if (result.success) {
        // The sliders represent deltas from the clip's current state;
        // after a successful render the state is the new baseline, so
        // the sliders reset to neutral.
        _resetSliders();
      }
      _showMessage(result.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Clear all sliders to neutral WITHOUT applying (display-only).
  void _reset() => _resetSliders();

  void _resetSliders() {
    setState(() {
      _brightness = _neutralBrightness;
      _contrast = _neutralContrast;
      _saturation = _neutralSaturation;
      _speed = _neutralSpeed;
      _volume = _neutralVolume;
    });
  }

  /// The slider readout: a signed 2-decimal value for brightness (the
  /// −1..1 lift/darken), a plain 2-decimal value otherwise, with a ×
  /// suffix on speed (the multiplier).
  static String _formatValue(
    double value, {
    bool signed = false,
    String suffix = '',
  }) {
    final text = value.toStringAsFixed(2);
    return '${signed && value > 0 ? '+' : ''}$text$suffix';
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

/// One slider row: the label (left), the live value readout (right) and
/// the slider itself. The plain Slider inherits the theme's accent via
/// the color scheme — no sliderTheme exists in [ClipMindTheme], so the
/// default Material 3 styling is kept (minimal, token-driven).
class _AdjustmentSlider extends StatelessWidget {
  final String label;
  final double value;
  final String valueText;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _AdjustmentSlider({
    required this.label,
    required this.value,
    required this.valueText,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              valueText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ClipMindColors.textPrimary,
                  ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
