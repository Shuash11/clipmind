/// One-click effect-preset recipes for the CapCut-style effects panel.
///
/// Each recipe is a list of steps over EXISTING ops only (`apply_effect`
/// with its documented params, `adjust_brightness` with `value`) — no new
/// model tools. Multi-op recipes rely on the CommandMapper composing
/// same-clip ops into one job. Param names mirror the tool executors:
/// `apply_effect` takes `effect` + `strength`/`contrast`/`saturation`,
/// `adjust_brightness` takes `value` (-1.0 to 1.0).
class EffectPresetStep {
  /// Existing op type: `apply_effect` or `adjust_brightness`.
  final String opType;

  /// Op params (e.g. `{'effect': 'vignette', 'strength': 0.35}).
  final Map<String, dynamic> params;

  const EffectPresetStep({required this.opType, required this.params});
}

class EffectPreset {
  final String id;
  final String label;

  /// Material icon name for the panel tile (frontend maps to IconData).
  final String icon;

  final List<EffectPresetStep> recipe;

  const EffectPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.recipe,
  });
}

/// The 8 one-click presets (the verified CapCut template pattern).
const List<EffectPreset> effectPresets = [
  EffectPreset(
    id: 'noir',
    label: 'Noir',
    icon: 'contrast',
    recipe: [
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'grayscale'},
      ),
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'contrast', 'contrast': 1.3},
      ),
    ],
  ),
  EffectPreset(
    id: 'vintage',
    label: 'Vintage',
    icon: 'auto_awesome',
    recipe: [
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'saturation', 'saturation': 0.85},
      ),
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'vignette', 'strength': 0.35},
      ),
    ],
  ),
  EffectPreset(
    id: 'cinematic',
    label: 'Cinematic',
    icon: 'movie',
    recipe: [
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'contrast', 'contrast': 1.15},
      ),
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'vignette', 'strength': 0.3},
      ),
    ],
  ),
  EffectPreset(
    id: 'warm',
    label: 'Warm',
    icon: 'wb_sunny',
    recipe: [
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'saturation', 'saturation': 1.15},
      ),
      EffectPresetStep(
        opType: 'adjust_brightness',
        params: {'value': 0.08},
      ),
    ],
  ),
  EffectPreset(
    id: 'cool',
    label: 'Cool',
    icon: 'ac_unit',
    recipe: [
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'saturation', 'saturation': 0.9},
      ),
      EffectPresetStep(
        opType: 'adjust_brightness',
        params: {'value': 0.05},
      ),
    ],
  ),
  EffectPreset(
    id: 'brighten',
    label: 'Brighten',
    icon: 'brightness_6',
    recipe: [
      EffectPresetStep(
        opType: 'adjust_brightness',
        params: {'value': 0.25},
      ),
    ],
  ),
  EffectPreset(
    id: 'soften',
    label: 'Soften',
    icon: 'blur_on',
    recipe: [
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'blur', 'strength': 0.25},
      ),
    ],
  ),
  EffectPreset(
    id: 'dramatic',
    label: 'Dramatic',
    icon: 'theater_comedy',
    recipe: [
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'contrast', 'contrast': 1.4},
      ),
      EffectPresetStep(
        opType: 'apply_effect',
        params: {'effect': 'vignette', 'strength': 0.45},
      ),
    ],
  ),
];
