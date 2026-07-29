import 'package:clipmind/features/agent/domain/services/legacy_operation_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes only complete unambiguous legacy aliases', () {
    final result = LegacyOperationNormalizer().normalize([
      {
        'type': 'adjust_brightness',
        'targetClipId': 'clip-1',
        'params': {'brightness': 0},
      },
      {
        'type': 'cut',
        'targetClipId': 'clip-1',
        'params': {'startMs': '00:01'},
      },
    ]);
    expect(result.calls.single.name, 'set_clip_brightness');
    expect(result.calls.single.arguments['brightness'], 0);
    expect(result.findings, isNotEmpty);
  });

  test(
    'complete alias table preserves typed zero, negative, and false values',
    () {
      final output = LegacyOperationNormalizer().normalize([
        {
          'type': 'trim',
          'targetClipId': 'clip-1',
          'params': {'startMs': 0, 'endMs': 10},
        },
        {
          'type': 'cut',
          'targetClipId': 'clip-1',
          'params': {'removeStartMs': 1, 'removeEndMs': 9},
        },
        {
          'type': 'change_speed',
          'targetClipId': 'clip-1',
          'params': {'speed': 1},
        },
        {
          'type': 'mute',
          'targetClipId': 'clip-1',
          'params': {'muted': false},
        },
        {
          'type': 'change_volume',
          'targetClipId': 'clip-1',
          'params': {'volume': 0},
        },
        {
          'type': 'adjust_brightness',
          'targetClipId': 'clip-1',
          'params': {'value': -1},
        },
        {
          'type': 'overlay_text',
          'params': {
            'trackId': 'track-1',
            'startMs': 0,
            'endMs': 1,
            'text': 'T',
            'x': 0,
            'y': 0,
          },
        },
        {
          'type': 'transform',
          'targetClipId': 'clip-1',
          'params': {
            'width': 16,
            'height': 16,
            'fit': 'contain',
            'rotationDegrees': 0,
          },
        },
      ]);
      expect(output.findings, isEmpty);
      expect(output.calls.map((call) => call.name), [
        'trim_clip',
        'remove_clip_range',
        'set_clip_speed',
        'set_clip_muted',
        'set_clip_volume',
        'set_clip_brightness',
        'add_text_overlay',
        'set_clip_transform',
      ]);
      expect(output.calls[3].arguments['muted'], isFalse);
      expect(output.calls[5].arguments['brightness'], -1);
      expect(
        () => output.calls.add(output.calls.first),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'legacy rejects empty, ambiguous, deferred, and caller-ID operations',
    () {
      final normalizer = LegacyOperationNormalizer();
      expect(normalizer.normalize(const []).calls, isEmpty);
      final invalid = normalizer.normalize([
        {
          'type': 'cut',
          'targetClipId': 'clip-1',
          'params': {'startMs': 0, 'endMs': 1},
        },
        {
          'type': 'cut',
          'targetClipId': 'clip-1',
          'params': {
            'removeStartMs': 0,
            'remove_start_ms': 0,
            'removeEndMs': 1,
          },
        },
        {
          'type': 'adjust_brightness',
          'targetClipId': 'clip-1',
          'params': {'brightness': 0, 'value': 0},
        },
        {
          'type': 'transform',
          'targetClipId': 'clip-1',
          'params': {'width': 16},
        },
        {'type': 'extract_audio', 'params': <String, Object?>{}},
        {
          'name': 'create_tag',
          'arguments': {'tagId': 'caller', 'name': 'Tag', 'color': '#112233'},
        },
      ]);
      expect(invalid.calls, isEmpty);
      expect(invalid.findings, hasLength(6));
    },
  );
}
