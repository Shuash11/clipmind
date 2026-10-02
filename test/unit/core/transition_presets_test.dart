import 'package:clipmind/core/constants/transition_presets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The executors' `add_transition` vocabulary (mirrors
/// `EditToolExecutor.supportedTransitions` without pulling the whole tool
/// surface into a constants test).
const _supportedTransitions = {
  'fade',
  'dissolve',
  'wipeleft',
  'wiperight',
  'slideleft',
  'slideright',
  'fadeblack',
  'fadewhite',
  'circleopen',
  'circleclose',
  'smoothleft',
  'smoothright',
  'wipeup',
  'wipedown',
  'slideup',
  'slidedown',
};

void main() {
  group('transitionPresets', () {
    test('defines the 8 one-click presets', () {
      expect(
        transitionPresets.map((p) => p.id),
        equals([
          'fade',
          'dissolve',
          'wipeleft',
          'wiperight',
          'slideup',
          'slidedown',
          'circleopen',
          'fadeblack',
        ]),
      );
      for (final preset in transitionPresets) {
        expect(preset.label, isNotEmpty);
        expect(preset.icon, isNotEmpty);
        expect(preset.recipe, isNotEmpty);
      }
    });

    test('ids, labels, and icons are unique', () {
      final ids = transitionPresets.map((p) => p.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      final labels = transitionPresets.map((p) => p.label).toList();
      expect(labels.toSet(), hasLength(labels.length));
      final icons = transitionPresets.map((p) => p.icon).toList();
      expect(icons.toSet(), hasLength(icons.length));
    });

    test('every recipe is one add_transition step with valid style params',
        () {
      for (final preset in transitionPresets) {
        expect(
          preset.recipe,
          hasLength(1),
          reason: '${preset.id} must carry exactly one step',
        );
        final step = preset.recipe.single;
        expect(
          step.opType,
          equals('add_transition'),
          reason: '${preset.id} uses a non-existing op ${step.opType}',
        );
        final transition = step.params['transition'];
        expect(
          _supportedTransitions,
          contains(transition),
          reason: '${preset.id} uses unknown transition $transition',
        );
        final duration = step.params['duration'];
        expect(
          duration,
          isNotNull,
          reason: '${preset.id} add_transition needs "duration"',
        );
        expect(duration, isA<num>());
        final durationSecs =
            duration is num ? duration.toDouble() : double.nan;
        expect(
          durationSecs,
          inInclusiveRange(0.0, 60.0),
          reason: '${preset.id} duration must lie in 0–60',
        );
        expect(
          durationSecs,
          greaterThan(0),
          reason: '${preset.id} duration must be positive',
        );
      }
    });

    test('spot-checks the documented recipes', () {
      TransitionPreset byId(String id) =>
          transitionPresets.singleWhere((p) => p.id == id);

      expect(
        byId('fade').recipe.single.params,
        equals({'transition': 'fade', 'duration': 0.5}),
      );
      expect(
        byId('dissolve').recipe.single.params['transition'],
        equals('dissolve'),
      );
      expect(
        byId('wipeleft').recipe.single.params['transition'],
        equals('wipeleft'),
      );
      expect(
        byId('circleopen').recipe.single.params['transition'],
        equals('circleopen'),
      );
      expect(
        byId('fadeblack').recipe.single.params['transition'],
        equals('fadeblack'),
      );
    });
  });
}
