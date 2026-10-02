import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';

// Phase 1 (Cycle 9): the ranged-input restriction (`clip_start_s` /
// `clip_len_s` → `-ss`/`-t`) is first-op-wins over the walk order for ANY
// composable op type — cut keeps its `between()` shift, non-cut ops ride
// the restricted input with no shift (setpts/atempo apply after it).
void main() {
  const input = '/media/clip.mp4';
  const outDir = '/media/out';
  const clipPathMap = {'clip_1': input, '_default': input};

  List<String> mapSingleArgs(EditOperationSet set) {
    final jobs = CommandMapper.mapOperations(set, clipPathMap, outDir);
    expect(jobs, hasLength(1));
    return jobs.single.args;
  }

  group('CommandMapper ranged-input restriction', () {
    test('cut with the params still restricts (no behavior change)', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_cut',
              type: 'cut',
              targetClipId: 'clip_1',
              params: {
                'remove_start': '00:00:10.000',
                'remove_end': '00:00:20.000',
                'clip_start_s': 5.0,
                'clip_len_s': 55.0,
              },
            ),
          ],
          summary: 'cut',
        ),
      );
      expect(args, containsAll(['-ss', '5.0', '-i', input, '-t', '55.0']));
      expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
      expect(args.indexOf('-i'), lessThan(args.indexOf('-t')));
      // File times [10, 20] shift to clip-relative [5.0, 15.0].
      expect(args.join(' '), contains('between(t,5.0,15.0)'));
    });

    test('change_speed-only op set carries the restriction', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_speed',
              type: 'change_speed',
              targetClipId: 'clip_1',
              params: {'factor': 2.0, 'clip_start_s': 5.0, 'clip_len_s': 55.0},
            ),
          ],
          summary: 'speed',
        ),
      );
      expect(
        args,
        equals([
          '-ss',
          '5.0',
          '-i',
          input,
          '-t',
          '55.0',
          '-filter_complex',
          '[0:v]setpts=PTS/2.0[vout];[0:a]atempo=2.0[aout]',
          '-map',
          '[vout]',
          '-map',
          '[aout]',
        ]),
      );
    });

    test('multi-op set composes one filter-graph job with restriction', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_bright',
              type: 'adjust_brightness',
              targetClipId: 'clip_1',
              params: {'value': 0.2},
            ),
            EditOperationRequest(
              id: 'op_speed',
              type: 'change_speed',
              targetClipId: 'clip_1',
              params: {'factor': 2.0, 'clip_start_s': 5.0, 'clip_len_s': 55.0},
            ),
          ],
          summary: 'brightness+speed',
        ),
      );
      // ONE composed job (not two singles) with the restricted input.
      expect(args, containsAll(['-ss', '5.0', '-i', input, '-t', '55.0']));
      expect(args.indexOf('-t'), lessThan(args.indexOf('-filter_complex')));
      final graph = args[args.indexOf('-filter_complex') + 1];
      expect(graph, contains('eq=brightness=0.2'));
      expect(graph, contains('setpts=PTS/2.0'));
      expect(graph, contains('atempo=2.0'));
    });

    test('ops without the params run the legacy whole-file path', () {
      final single = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_speed',
              type: 'change_speed',
              targetClipId: 'clip_1',
              params: {'factor': 1.5},
            ),
          ],
          summary: 'speed',
        ),
      );
      expect(single.sublist(0, 2), equals(['-i', input]));
      expect(single.contains('-ss'), isFalse);
      expect(single.contains('-t'), isFalse);

      final composed = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_bright',
              type: 'adjust_brightness',
              targetClipId: 'clip_1',
              params: {'value': 0.2},
            ),
            EditOperationRequest(
              id: 'op_speed2',
              type: 'change_speed',
              targetClipId: 'clip_1',
              params: {'factor': 1.5},
            ),
          ],
          summary: 'brightness+speed',
        ),
      );
      expect(composed.sublist(0, 2), equals(['-i', input]));
      expect(composed.contains('-ss'), isFalse);
      expect(composed.contains('-t'), isFalse);
    });

    test('first-op-wins when two ops carry the params', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_bright',
              type: 'adjust_brightness',
              targetClipId: 'clip_1',
              params: {
                'value': 0.2,
                'clip_start_s': 5.0,
                'clip_len_s': 55.0,
              },
            ),
            EditOperationRequest(
              id: 'op_speed',
              type: 'change_speed',
              targetClipId: 'clip_1',
              params: {
                'factor': 2.0,
                'clip_start_s': 10.0,
                'clip_len_s': 40.0,
              },
            ),
          ],
          summary: 'brightness+speed',
        ),
      );
      expect(args, containsAll(['-ss', '5.0', '-i', input, '-t', '55.0']));
      expect(args.contains('10.0'), isFalse);
      expect(args.contains('40.0'), isFalse);
    });
  });
}
