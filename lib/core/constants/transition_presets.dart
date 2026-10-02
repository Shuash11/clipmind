/// One-click transition presets for the CapCut-style transitions panel.
///
/// Each preset is a single style-only step over the EXISTING
/// `add_transition` op — no new model tools. The step carries only the
/// xfade style (`transition` name + `duration`); the clip-pair params
/// (`second_clip_id`, `offset`, `audio_mode`, `clip_ids`) are computed by
/// `ManualEditController.submitTransition` from probed clip metadata, so
/// they cannot live in a static preset. Param names mirror the tool
/// executor: `add_transition` takes `transition` + `duration` (seconds,
/// 0–60) alongside the computed pair params.
class TransitionPresetStep {
  /// Existing op type: always `add_transition` for these presets.
  final String opType;

  /// Style params (e.g. `{'transition': 'fade', 'duration': 0.5}).
  final Map<String, dynamic> params;

  const TransitionPresetStep({required this.opType, required this.params});
}

class TransitionPreset {
  final String id;
  final String label;

  /// Material icon name for the panel tile (frontend maps to IconData).
  final String icon;

  final List<TransitionPresetStep> recipe;

  const TransitionPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.recipe,
  });
}

/// The 8 one-click presets (CapCut-classic feel). Every `transition` name
/// is a member of the executor's `supportedTransitions` vocabulary.
const List<TransitionPreset> transitionPresets = [
  TransitionPreset(
    id: 'fade',
    label: 'Fade',
    icon: 'opacity',
    recipe: [
      TransitionPresetStep(
        opType: 'add_transition',
        params: {'transition': 'fade', 'duration': 0.5},
      ),
    ],
  ),
  TransitionPreset(
    id: 'dissolve',
    label: 'Dissolve',
    icon: 'auto_awesome',
    recipe: [
      TransitionPresetStep(
        opType: 'add_transition',
        params: {'transition': 'dissolve', 'duration': 0.5},
      ),
    ],
  ),
  TransitionPreset(
    id: 'wipeleft',
    label: 'Wipe Left',
    icon: 'arrow_back',
    recipe: [
      TransitionPresetStep(
        opType: 'add_transition',
        params: {'transition': 'wipeleft', 'duration': 0.5},
      ),
    ],
  ),
  TransitionPreset(
    id: 'wiperight',
    label: 'Wipe Right',
    icon: 'arrow_forward',
    recipe: [
      TransitionPresetStep(
        opType: 'add_transition',
        params: {'transition': 'wiperight', 'duration': 0.5},
      ),
    ],
  ),
  TransitionPreset(
    id: 'slideup',
    label: 'Slide Up',
    icon: 'arrow_upward',
    recipe: [
      TransitionPresetStep(
        opType: 'add_transition',
        params: {'transition': 'slideup', 'duration': 0.5},
      ),
    ],
  ),
  TransitionPreset(
    id: 'slidedown',
    label: 'Slide Down',
    icon: 'arrow_downward',
    recipe: [
      TransitionPresetStep(
        opType: 'add_transition',
        params: {'transition': 'slidedown', 'duration': 0.5},
      ),
    ],
  ),
  TransitionPreset(
    id: 'circleopen',
    label: 'Circle Open',
    icon: 'circle',
    recipe: [
      TransitionPresetStep(
        opType: 'add_transition',
        params: {'transition': 'circleopen', 'duration': 0.5},
      ),
    ],
  ),
  TransitionPreset(
    id: 'fadeblack',
    label: 'Fade to Black',
    icon: 'dark_mode',
    recipe: [
      TransitionPresetStep(
        opType: 'add_transition',
        params: {'transition': 'fadeblack', 'duration': 0.5},
      ),
    ],
  ),
];
