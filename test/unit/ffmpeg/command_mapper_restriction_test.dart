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

  // Phase 1 (Cycle 10): composed filter-graph audio integrity — the
  // audio side is ONE chained `[0:a]f1,f2,…[aout]` segment (never
  // per-op `[a{i}]` pads, never last-filter-only), audio-only ops carry
  // a video `null` passthrough so the `v{i}` chain never breaks, and
  // the map is `[aout]` / `-an` / `0:a` (never `a{ops.length - 1}`).
  group('composed audio integrity', () {
    String graphOf(List<String> args) =>
        args[args.indexOf('-filter_complex') + 1];

    /// Every label consumed as a filter input or via `-map` must be
    /// produced as a filter output; the legacy per-op `[a{i}]` pads
    /// must be gone entirely.
    void expectGraphIntact(List<String> args, int opCount) {
      final graph = graphOf(args);
      final defined = RegExp(r'\[([A-Za-z0-9_:]+)\](?=;|$)')
          .allMatches(graph)
          .map((m) => m.group(1)!)
          .toSet();
      final consumed = RegExp(r'(?:^|;)\[([A-Za-z0-9_:]+)\]')
          .allMatches(graph)
          .map((m) => m.group(1)!)
          .toSet();
      for (final label in consumed) {
        // Input-stream pads (`0:v`, `0:a`) are FFmpeg sources, not
        // filter outputs — everything else must be produced in-graph.
        if (label.contains(':')) continue;
        expect(defined, contains(label), reason: 'input [$label] undefined');
      }
      // The whole v-chain links every op: v0 in, v{opCount} out.
      expect(defined, contains('v$opCount'));
      for (var i = 0; i < args.length - 1; i++) {
        if (args[i] == '-map') {
          final mapped = args[i + 1];
          final bare = mapped.startsWith('[')
              ? mapped.substring(1, mapped.length - 1)
              : mapped;
          if (bare == '0:a') continue;
          expect(defined, contains(bare),
              reason: 'mapped [$bare] undefined');
        }
      }
      expect(graph, isNot(matches(RegExp(r'\[a\d+\]'))),
          reason: 'legacy per-op audio pads must be gone');
    }

    test('volume+speed chains volume before atempo, labels intact', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_vol',
              type: 'change_volume',
              targetClipId: 'clip_1',
              params: {'factor': 0.5},
            ),
            EditOperationRequest(
              id: 'op_speed',
              type: 'change_speed',
              targetClipId: 'clip_1',
              params: {'factor': 2.0},
            ),
          ],
          summary: 'volume+speed',
        ),
      );
      final graph = graphOf(args);
      // Chained op order: volume fragment precedes the atempo chain.
      expect(graph, contains('[0:a]volume=0.5,atempo=2.0[aout]'));
      expect(graph, contains('[v0]null[v1]'));
      expect(graph, contains('[v1]setpts=PTS/2.0[v2]'));
      expect(args, containsAll(['-map', '[v2]', '-map', '[aout]']));
      expectGraphIntact(args, 2);
    });

    test('brightness+volume+speed keeps all three fragments', () {
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
              id: 'op_vol',
              type: 'change_volume',
              targetClipId: 'clip_1',
              params: {'factor': 0.5},
            ),
            EditOperationRequest(
              id: 'op_speed',
              type: 'change_speed',
              targetClipId: 'clip_1',
              params: {'factor': 2.0},
            ),
          ],
          summary: 'brightness+volume+speed',
        ),
      );
      final graph = graphOf(args);
      expect(graph, contains('eq=brightness=0.2'));
      expect(graph, contains('setpts=PTS/2.0'));
      expect(graph, contains('[0:a]volume=0.5,atempo=2.0[aout]'));
      expectGraphIntact(args, 3);
    });

    test('trim+change_speed keeps atrim (no A/V desync)', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_trim',
              type: 'trim',
              targetClipId: 'clip_1',
              params: {'start': '1.0', 'end': '5.0'},
            ),
            EditOperationRequest(
              id: 'op_speed',
              type: 'change_speed',
              targetClipId: 'clip_1',
              params: {'factor': 2.0},
            ),
          ],
          summary: 'trim+speed',
        ),
      );
      final graph = graphOf(args);
      expect(
        graph,
        contains(
          '[0:a]atrim=1.0:5.0,asetpts=PTS-STARTPTS,atempo=2.0[aout]',
        ),
      );
      expectGraphIntact(args, 2);
    });

    test('trim+resize (video-only last op) maps [aout]', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_trim',
              type: 'trim',
              targetClipId: 'clip_1',
              params: {'start': '1.0', 'end': '5.0'},
            ),
            EditOperationRequest(
              id: 'op_resize',
              type: 'resize',
              targetClipId: 'clip_1',
              params: {'width': 1280, 'height': 720},
            ),
          ],
          summary: 'trim+resize',
        ),
      );
      final graph = graphOf(args);
      expect(
        graph,
        contains('[0:a]atrim=1.0:5.0,asetpts=PTS-STARTPTS[aout]'),
      );
      expect(args, containsAll(['-map', '[aout]']));
      expectGraphIntact(args, 2);
    });

    test('change_volume+resize (video-only last op) maps [aout]', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_vol',
              type: 'change_volume',
              targetClipId: 'clip_1',
              params: {'factor': 0.5},
            ),
            EditOperationRequest(
              id: 'op_resize',
              type: 'resize',
              targetClipId: 'clip_1',
              params: {'width': 1280, 'height': 720},
            ),
          ],
          summary: 'volume+resize',
        ),
      );
      final graph = graphOf(args);
      expect(graph, contains('[0:a]volume=0.5[aout]'));
      expect(args, containsAll(['-map', '[aout]']));
      expectGraphIntact(args, 2);
    });

    test('mute+brightness keeps the video chain and maps -an', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_mute',
              type: 'mute',
              targetClipId: 'clip_1',
              params: {},
            ),
            EditOperationRequest(
              id: 'op_bright',
              type: 'adjust_brightness',
              targetClipId: 'clip_1',
              params: {'value': 0.2},
            ),
          ],
          summary: 'mute+brightness',
        ),
      );
      final graph = graphOf(args);
      expect(graph, contains('[v0]null[v1]'));
      expect(graph, contains('eq=brightness=0.2'));
      expect(graph, isNot(contains('[0:a]')));
      expect(args, contains('-an'));
      expect(args.join(' '), isNot(contains('[aout]')));
      expectGraphIntact(args, 2);
    });

    test('mute-only maps -an without a filter graph', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_mute',
              type: 'mute',
              targetClipId: 'clip_1',
              params: {},
            ),
          ],
          summary: 'mute',
        ),
      );
      expect(args, contains('-an'));
      expect(args.contains('-filter_complex'), isFalse);
    });

    test('mute+volume maps -an and drops the audio segment', () {
      final args = mapSingleArgs(
        const EditOperationSet(
          operations: [
            EditOperationRequest(
              id: 'op_mute',
              type: 'mute',
              targetClipId: 'clip_1',
              params: {},
            ),
            EditOperationRequest(
              id: 'op_vol',
              type: 'change_volume',
              targetClipId: 'clip_1',
              params: {'factor': 0.5},
            ),
          ],
          summary: 'mute+volume',
        ),
      );
      final graph = graphOf(args);
      // Both ops are audio-only: the video chain is pure passthrough.
      expect(graph, equals('[0:v]null[v0];[v0]null[v1];[v1]null[v2]'));
      expect(args, contains('-an'));
      expect(args.join(' '), isNot(contains('[aout]')));
      expectGraphIntact(args, 2);
    });
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
