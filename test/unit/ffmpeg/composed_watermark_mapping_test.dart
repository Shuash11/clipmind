import 'package:clipmind/data/services/ffmpeg/command_builder.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/filter_escaping.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

// Phase 1 (Cycle 11): `overlay_watermark` composes inside
// `CommandMapper._composeFilterGraph` instead of falling through to the
// no-op default. Every multi-op group containing a watermark (except the
// guarded text/mute combos, which stay on the parallel single-job path)
// maps to exactly ONE filter-graph job whose `-map [vN]` label resolves.
// Arg-level only — no FFmpeg binary required.
void main() {
  const input = '/v/clip.mp4';
  const outDir = '/v/out';
  const projectDir = '/v/project';
  const clipPathMap = {'clip_1': input, '_default': input};
  const wm1 = '/v/project/wm1.png';
  const wm2 = '/v/project/wm2.png';

  EditOperationRequest req(
    String id,
    String type, [
    Map<String, dynamic> params = const <String, dynamic>{},
  ]) {
    return EditOperationRequest(
      id: id,
      type: type,
      targetClipId: 'clip_1',
      params: params,
    );
  }

  EditOperationSet setOf(List<EditOperationRequest> ops) {
    return EditOperationSet(operations: ops, summary: 'watermark');
  }

  List<FfmpegJob> mapJobs(EditOperationSet set) {
    return CommandMapper.mapOperations(
      set,
      clipPathMap,
      outDir,
      defaultPath: input,
      projectDir: projectDir,
    );
  }

  String filterOf(List<String> args) {
    return args[args.indexOf('-filter_complex') + 1];
  }

  /// Every consumed `vN` chain pad must be produced by an earlier segment,
  /// and the `-map` video label must be produced (image-leg `[N:v]`
  /// inputs are `-i` inputs, not chain pads).
  void expectVideoPadsConnected(List<String> args) {
    final mapLabel = args[args.indexOf('-map') + 1];
    final fc = filterOf(args);
    final produced = <String>{};
    final consumed = <String>{};
    for (final segment in fc.split(';')) {
      final refs = RegExp(r'\[([^\]]+)\]')
          .allMatches(segment)
          .map((m) => m.group(1)!)
          .toList();
      if (refs.isEmpty) continue;
      produced.add(refs.last);
      consumed.addAll(refs.take(refs.length - 1).where((r) =>
          r.startsWith('v') && !r.contains(':')));
    }
    expect(consumed.difference(produced), isEmpty,
        reason: 'dangling video pad in: $fc');
    expect(produced, contains(mapLabel.substring(1, mapLabel.length - 1)));
  }

  group('CommandBuilder.overlayPosition', () {
    test('maps every named position to its exact expression', () {
      expect(CommandBuilder.overlayPosition('top-left'), equals('10:10'));
      expect(
        CommandBuilder.overlayPosition('top-right'),
        equals('W-w-10:10'),
      );
      expect(
        CommandBuilder.overlayPosition('bottom-left'),
        equals('10:H-h-10'),
      );
      expect(
        CommandBuilder.overlayPosition('center'),
        equals('(W-w)/2:(H-h)/2'),
      );
      expect(
        CommandBuilder.overlayPosition('bottom-right'),
        equals('W-w-10:H-h-10'),
      );
    });

    test('unknown names fall back to bottom-right', () {
      expect(CommandBuilder.overlayPosition(''), equals('W-w-10:H-h-10'));
      expect(
        CommandBuilder.overlayPosition('sideways'),
        equals('W-w-10:H-h-10'),
      );
    });
  });

  group('CommandMapper composed watermark', () {
    test('resize + watermark composes one job with connected pads', () {
      final jobs = mapJobs(setOf([
        req('op_r', 'resize', {'width': 1280, 'height': 720}),
        req('op_w', 'overlay_watermark', {'image_path': wm1}),
      ]));
      expect(jobs, hasLength(1));
      final args = jobs.single.args;
      expect(args.sublist(0, 4), equals(['-i', input, '-i', wm1]));
      final fc = filterOf(args);
      expect(
        fc,
        contains('[1:v]format=rgba,colorchannelmixer=aa=0.7[wm1]'),
      );
      expect(fc, contains('[v1][wm1]overlay=W-w-10:H-h-10[v2]'));
      expect(args, containsAll(['-map', '[v2]']));
      expect(args, containsAll(['-map', '0:a']));
      expectVideoPadsConnected(args);
    });

    test('trim + watermark chains the overlay on the trim output', () {
      final jobs = mapJobs(setOf([
        req('op_t', 'trim', {'start': '1.0', 'end': '4.0'}),
        req('op_w', 'overlay_watermark', {'image_path': wm1}),
      ]));
      expect(jobs, hasLength(1));
      final args = jobs.single.args;
      final fc = filterOf(args);
      expect(fc, contains('trim=1.0:4.0'));
      expect(fc, contains('[v1][wm1]overlay=W-w-10:H-h-10[v2]'));
      expect(args, containsAll(['-map', '[v2]']));
      expectVideoPadsConnected(args);
    });

    test('two different watermarks chain two overlays on two inputs', () {
      final jobs = mapJobs(setOf([
        req('op_w1', 'overlay_watermark', {'image_path': wm1}),
        req('op_w2', 'overlay_watermark', {'image_path': wm2}),
      ]));
      expect(jobs, hasLength(1));
      final args = jobs.single.args;
      expect(
        args.sublist(0, 6),
        equals(['-i', input, '-i', wm1, '-i', wm2]),
      );
      final fc = filterOf(args);
      expect(
        fc,
        contains('[1:v]format=rgba,colorchannelmixer=aa=0.7[wm1]'),
      );
      expect(
        fc,
        contains('[2:v]format=rgba,colorchannelmixer=aa=0.7[wm2]'),
      );
      expect(fc, contains('[v0][wm1]overlay=W-w-10:H-h-10[v1]'));
      expect(fc, contains('[v1][wm2]overlay=W-w-10:H-h-10[v2]'));
      expect(args, containsAll(['-map', '[v2]']));
      expect(args, containsAll(['-map', '0:a']));
      expectVideoPadsConnected(args);
    });

    test('the same image twice reuses one input', () {
      final jobs = mapJobs(setOf([
        req('op_w1', 'overlay_watermark', {'image_path': wm1}),
        req('op_w2', 'overlay_watermark', {'image_path': wm1}),
      ]));
      expect(jobs, hasLength(1));
      final args = jobs.single.args;
      expect(args.where((a) => a == '-i'), hasLength(2));
      final fc = filterOf(args);
      expect('[1:v]format'.allMatches(fc), hasLength(1));
      expect(fc, contains('[v0][wm1]overlay=W-w-10:H-h-10[v1]'));
      expect(fc, contains('[v1][wm1]overlay=W-w-10:H-h-10[v2]'));
      expect(fc, isNot(contains('[2:v]')));
      expect(args, containsAll(['-map', '[v2]']));
      expectVideoPadsConnected(args);
    });

    test('all named positions and the default map exactly', () {
      const cases = {
        'top-left': '10:10',
        'top-right': 'W-w-10:10',
        'bottom-left': '10:H-h-10',
        'center': '(W-w)/2:(H-h)/2',
        'bottom-right': 'W-w-10:H-h-10',
      };
      for (final entry in cases.entries) {
        final jobs = mapJobs(setOf([
          req('op_r', 'resize', {'width': 1280, 'height': 720}),
          req('op_w', 'overlay_watermark', {
            'image_path': wm1,
            'position': entry.key,
          }),
        ]));
        expect(jobs, hasLength(1));
        expect(
          filterOf(jobs.single.args),
          contains('[v1][wm1]overlay=${entry.value}[v2]'),
          reason: 'position ${entry.key}',
        );
      }
      final defaultJobs = mapJobs(setOf([
        req('op_r', 'resize', {'width': 1280, 'height': 720}),
        req('op_w', 'overlay_watermark', {'image_path': wm1}),
      ]));
      expect(
        filterOf(defaultJobs.single.args),
        contains('[v1][wm1]overlay=W-w-10:H-h-10[v2]'),
      );
    });

    test('opacity clamps to [0, 1]', () {
      final high = mapJobs(setOf([
        req('op_r', 'resize', {'width': 1280, 'height': 720}),
        req('op_w', 'overlay_watermark', {
          'image_path': wm1,
          'opacity': 1.5,
        }),
      ]));
      expect(filterOf(high.single.args), contains('aa=1.0'));
      final low = mapJobs(setOf([
        req('op_r', 'resize', {'width': 1280, 'height': 720}),
        req('op_w', 'overlay_watermark', {
          'image_path': wm1,
          'opacity': -0.5,
        }),
      ]));
      expect(filterOf(low.single.args), contains('aa=0.0'));
    });

    test('empty image_path throws with an actionable message', () {
      expect(
        () => mapJobs(setOf([
          req('op_r', 'resize', {'width': 1280, 'height': 720}),
          req('op_w', 'overlay_watermark', {'image_path': ''}),
        ])),
        throwsA(isA<FilterValidationException>().having(
          (e) => e.message,
          'message',
          contains('image_path'),
        )),
      );
    });

    test('traversal image_path throws with an actionable message', () {
      expect(
        () => mapJobs(setOf([
          req('op_r', 'resize', {'width': 1280, 'height': 720}),
          req('op_w', 'overlay_watermark', {'image_path': '../evil.png'}),
        ])),
        throwsA(isA<FilterValidationException>().having(
          (e) => e.message,
          'message',
          contains('image_path'),
        )),
      );
    });

    test('out-of-project absolute image_path throws', () {
      expect(
        () => mapJobs(setOf([
          req('op_r', 'resize', {'width': 1280, 'height': 720}),
          req('op_w', 'overlay_watermark',
              {'image_path': '/other/evil.png'}),
        ])),
        throwsA(isA<FilterValidationException>().having(
          (e) => e.message,
          'message',
          contains('image_path'),
        )),
      );
    });

    test('ranged restriction keeps -ss/-t with the extra -i after', () {
      final jobs = mapJobs(setOf([
        req('op_r', 'resize', {
          'width': 1280,
          'height': 720,
          'clip_start_s': 5.0,
          'clip_len_s': 55.0,
        }),
        req('op_w', 'overlay_watermark', {'image_path': wm1}),
      ]));
      expect(jobs, hasLength(1));
      final args = jobs.single.args;
      expect(
        args.sublist(0, 8),
        equals(['-ss', '5.0', '-i', input, '-i', wm1, '-t', '55.0']),
      );
      expect(
        filterOf(args),
        contains('[v1][wm1]overlay=W-w-10:H-h-10[v2]'),
      );
      expect(args, containsAll(['-map', '[v2]']));
      expectVideoPadsConnected(args);
    });

    test('a watermark carrying the range still restricts the group', () {
      final jobs = mapJobs(setOf([
        req('op_w', 'overlay_watermark', {
          'image_path': wm1,
          'clip_start_s': 5.0,
          'clip_len_s': 55.0,
        }),
        req('op_b', 'adjust_brightness', {'value': 0.2}),
      ]));
      expect(jobs, hasLength(1));
      final args = jobs.single.args;
      expect(
        args.sublist(0, 8),
        equals(['-ss', '5.0', '-i', input, '-i', wm1, '-t', '55.0']),
      );
      expect(args, containsAll(['-map', '[v2]']));
      expectVideoPadsConnected(args);
    });

    test('guard unchanged: watermark + mute stays two single jobs', () {
      final jobs = mapJobs(setOf([
        req('op_w', 'overlay_watermark', {'image_path': wm1}),
        req('op_m', 'mute'),
      ]));
      expect(jobs, hasLength(2));
      final joined = jobs.map((j) => j.args.join(' ')).toList();
      expect(joined.any((a) => a.contains('overlay=')), isTrue);
      expect(joined.any((a) => a.contains('-an')), isTrue);
      expect(joined.any((a) => a.contains('[wm1]')), isFalse);
    });

    test('guard unchanged: watermark + text stays two single jobs', () {
      final jobs = mapJobs(setOf([
        req('op_w', 'overlay_watermark', {'image_path': wm1}),
        req('op_t', 'overlay_text', {'text': 'hi'}),
      ]));
      expect(jobs, hasLength(2));
      final joined = jobs.map((j) => j.args.join(' ')).toList();
      expect(joined.any((a) => a.contains('drawtext')), isTrue);
      expect(joined.any((a) => a.contains('overlay=')), isTrue);
      expect(joined.any((a) => a.contains('[wm1]')), isFalse);
    });
  });
}
