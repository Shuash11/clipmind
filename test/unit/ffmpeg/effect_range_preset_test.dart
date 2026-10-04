import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';

// Cycle 13 Phase 3a (effects stall fix): effect jobs must be
// range-restricted to the clip extent (`-ss`/`-t`, the cut-path shape)
// instead of re-encoding the whole source file, and carry
// `-preset veryfast` (intermediate outputs re-encoded again on final
// export — encode speed beats compression). Arg-level only.
void main() {
  const input = '/media/clip.mp4';
  const outDir = '/media/out';
  const clipPathMap = {'clip_1': input, '_default': input};

  List<String> mapSingleArgs(EditOperationSet set) {
    final jobs = CommandMapper.mapOperations(set, clipPathMap, outDir);
    expect(jobs, hasLength(1));
    return jobs.single.args;
  }

  group('CommandBuilder effect preset', () {
    test('effect() carries -preset veryfast', () {
      final args = CommandBuilder.effect(
        'in.mp4',
        effect: 'vignette',
        strength: 0.4,
      );
      expect(args.sublist(0, 2), equals(['-i', 'in.mp4']));
      expect(args[2], equals('-vf'));
      expect(args[3], startsWith('vignette=angle='));
      expect(args, containsAll(['-preset', 'veryfast']));
    });

    test('adjustBrightness() carries -preset veryfast', () {
      final args = CommandBuilder.adjustBrightness('in.mp4', 0.2);
      expect(args.join(' '), contains('eq=brightness=0.2'));
      expect(args, containsAll(['-preset', 'veryfast']));
    });

    test('merge and transition builders stay preset-free', () {
      final merged = CommandBuilder.merge(['a.mp4', 'b.mp4']);
      expect(merged.contains('-preset'), isFalse);
      final xfade = CommandBuilder.transition('a.mp4', 'b.mp4');
      expect(xfade.contains('-preset'), isFalse);
    });
  });

  group('CommandMapper single-op effect restriction', () {
    test('apply_effect with the range params restricts + preset', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_fx',
              type: 'apply_effect',
              targetClipId: 'clip_1',
              params: {
                'effect': 'grayscale',
                'clip_start_s': 10.0,
                'clip_len_s': 30.0,
              },
            ),
          ],
          summary: 'effect',
        ),
      );
      expect(args, containsAll(['-ss', '10.0', '-i', input, '-t', '30.0']));
      expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
      expect(args.indexOf('-i'), lessThan(args.indexOf('-t')));
      expect(args.join(' '), contains('eq=saturation=0'));
      expect(args, containsAll(['-preset', 'veryfast']));
    });

    test('adjust_brightness with the range params restricts + preset', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_b',
              type: 'adjust_brightness',
              targetClipId: 'clip_1',
              params: {
                'value': 0.2,
                'clip_start_s': 10.0,
                'clip_len_s': 30.0,
              },
            ),
          ],
          summary: 'brightness',
        ),
      );
      expect(args, containsAll(['-ss', '10.0', '-i', input, '-t', '30.0']));
      expect(args.join(' '), contains('eq=brightness=0.2'));
      expect(args, containsAll(['-preset', 'veryfast']));
    });

    test('effect without the range keeps the legacy input + preset', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_fx',
              type: 'apply_effect',
              targetClipId: 'clip_1',
              params: {'effect': 'grayscale'},
            ),
          ],
          summary: 'effect',
        ),
      );
      expect(args.sublist(0, 2), equals(['-i', input]));
      expect(args.contains('-ss'), isFalse);
      expect(args, containsAll(['-preset', 'veryfast']));
    });

    test('half-set range falls back to the legacy path', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_fx',
              type: 'apply_effect',
              targetClipId: 'clip_1',
              params: {'effect': 'grayscale', 'clip_start_s': 10.0},
            ),
          ],
          summary: 'effect',
        ),
      );
      expect(args.sublist(0, 2), equals(['-i', input]));
      expect(args.contains('-ss'), isFalse);
    });
  });

  group('CommandMapper composed effect restriction', () {
    test('composed job carries -ss/-t + preset when ranged', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_g',
              type: 'apply_effect',
              targetClipId: 'clip_1',
              params: {
                'effect': 'grayscale',
                'clip_start_s': 10.0,
                'clip_len_s': 30.0,
              },
            ),
            EditOperationRequest(
              id: 'op_c',
              type: 'apply_effect',
              targetClipId: 'clip_1',
              params: {'effect': 'contrast', 'contrast': 1.3},
            ),
          ],
          summary: 'noir',
        ),
      );
      expect(args, containsAll(['-ss', '10.0', '-i', input, '-t', '30.0']));
      expect(args.indexOf('-t'), lessThan(args.indexOf('-filter_complex')));
      final graph = args[args.indexOf('-filter_complex') + 1];
      expect(graph, contains('eq=saturation=0'));
      expect(graph, contains('eq=contrast=1.3'));
      expect(args, containsAll(['-preset', 'veryfast']));
    });

    test('composed job without the range keeps legacy input + preset', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_g',
              type: 'apply_effect',
              targetClipId: 'clip_1',
              params: {'effect': 'grayscale'},
            ),
            EditOperationRequest(
              id: 'op_c',
              type: 'apply_effect',
              targetClipId: 'clip_1',
              params: {'effect': 'contrast', 'contrast': 1.3},
            ),
          ],
          summary: 'noir',
        ),
      );
      expect(args.sublist(0, 2), equals(['-i', input]));
      expect(args.contains('-ss'), isFalse);
      expect(args.contains('-t'), isFalse);
      expect(args, containsAll(['-preset', 'veryfast']));
    });
  });
}
