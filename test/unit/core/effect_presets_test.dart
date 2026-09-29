import 'package:clipmind/core/constants/effect_presets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The executors' `apply_effect` vocabulary (mirrors
/// `EditToolExecutor.supportedEffects` without pulling the whole tool
/// surface into a constants test).
const _supportedEffects = {
  'vignette',
  'blur',
  'grayscale',
  'contrast',
  'saturation',
};

void main() {
  group('effectPresets', () {
    test('defines the 8 one-click presets', () {
      expect(
        effectPresets.map((p) => p.id),
        equals([
          'noir',
          'vintage',
          'cinematic',
          'warm',
          'cool',
          'brighten',
          'soften',
          'dramatic',
        ]),
      );
      for (final preset in effectPresets) {
        expect(preset.label, isNotEmpty);
        expect(preset.icon, isNotEmpty);
        expect(preset.recipe, isNotEmpty);
      }
    });

    test('every recipe step targets an existing op with valid params', () {
      for (final preset in effectPresets) {
        for (final step in preset.recipe) {
          expect(
            step.opType,
            isIn(['apply_effect', 'adjust_brightness']),
            reason: '${preset.id} uses a non-existing op ${step.opType}',
          );
          if (step.opType == 'apply_effect') {
            final effect = step.params['effect'];
            expect(
              _supportedEffects,
              contains(effect),
              reason: '${preset.id} uses unknown effect $effect',
            );
            final strength = step.params['strength'];
            if (strength != null) {
              expect(strength, inInclusiveRange(0.0, 1.0));
            }
            final contrast = step.params['contrast'];
            if (contrast != null) {
              expect(contrast, inInclusiveRange(0.0, 3.0));
            }
            final saturation = step.params['saturation'];
            if (saturation != null) {
              expect(saturation, inInclusiveRange(0.0, 3.0));
            }
          } else {
            final value = step.params['value'];
            expect(
              value,
              isNotNull,
              reason: '${preset.id} adjust_brightness needs "value"',
            );
            expect(value, inInclusiveRange(-1.0, 1.0));
          }
        }
      }
    });

    test('spot-checks the documented recipes', () {
      EffectPreset byId(String id) =>
          effectPresets.singleWhere((p) => p.id == id);

      final noir = byId('noir').recipe;
      expect(noir, hasLength(2));
      expect(noir[0].params['effect'], equals('grayscale'));
      expect(noir[1].params, equals({'effect': 'contrast', 'contrast': 1.3}));

      final vintage = byId('vintage').recipe;
      expect(vintage[1].params['strength'], equals(0.35));

      final warm = byId('warm').recipe;
      expect(warm[1].params['value'], equals(0.08));

      final brighten = byId('brighten').recipe;
      expect(brighten.single.params['value'], equals(0.25));

      final dramatic = byId('dramatic').recipe;
      expect(dramatic[1].params['strength'], equals(0.45));
    });
  });
}
