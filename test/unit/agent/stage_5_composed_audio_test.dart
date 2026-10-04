import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_5_command_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

// Audio-less-source integrity for the composed filter-graph path
// (Cycle 13 Phase 1): a silent source (screen recording) used to
// hard-fail on any composed multi-op command with
// "Stream map '0:a' matches no streams" because `_composeFilterGraph`
// always emitted `-map 0:a` when no audio fragments and no mute op were
// present. The caller-probed `sourceHasAudio` flag (the transition-path
// probe convention) now emits `-an` for known-silent sources.
// Arg-level only — no FFmpeg binary required.
void main() {
  const input = '/v/clip.mp4';
  const outDir = '/v/out';
  const projectDir = '/v/project';
  const clipPathMap = {'clip_1': input, '_default': input};
  const wm1 = '/v/project/wm1.png';

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
    return EditOperationSet(operations: ops, summary: 'composed audio');
  }

  List<FfmpegJob> mapJobs(EditOperationSet set, {bool? sourceHasAudio}) {
    return CommandMapper.mapOperations(
      set,
      clipPathMap,
      outDir,
      defaultPath: input,
      projectDir: projectDir,
      sourceHasAudio: sourceHasAudio,
    );
  }

  String filterOf(List<String> args) {
    return args[args.indexOf('-filter_complex') + 1];
  }

  // trim records an `atrim` audio fragment, so trim+resize is the
  // regression shape: fragments exist yet the source is silent.
  EditOperationSet trimResize() => setOf([
        req('op_t', 'trim', {'start': '1.0', 'end': '4.0'}),
        req('op_r', 'resize', {'width': 1280, 'height': 720}),
      ]);

  group('CommandMapper composed sourceHasAudio', () {
    test('silent source emits -an and never -map 0:a', () {
      final jobs = mapJobs(trimResize(), sourceHasAudio: false);
      expect(jobs, hasLength(1));
      final args = jobs.single.args;
      expect(args, contains('-an'));
      expect(args, isNot(contains('0:a')));
      expect(args, isNot(contains('[aout]')));
      // No dangling audio leg: the `[0:a]` filter input must be gone too,
      // otherwise the filtergraph itself would fail to parse.
      expect(filterOf(args), isNot(contains('[0:a]')));
    });

    test('audio-present source without fragments maps 0:a', () {
      final jobs = mapJobs(
        setOf([
          req('op_r', 'resize', {'width': 1280, 'height': 720}),
          req('op_o', 'rotate', {'degrees': 90}),
        ]),
        sourceHasAudio: true,
      );
      expect(jobs, hasLength(1));
      final args = jobs.single.args;
      expect(args, containsAll(['-map', '0:a']));
      expect(args, isNot(contains('-an')));
    });

    test('audio-present source with fragments maps [aout]', () {
      final jobs = mapJobs(trimResize(), sourceHasAudio: true);
      expect(jobs, hasLength(1));
      final args = jobs.single.args;
      expect(args, containsAll(['-map', '[aout]']));
      expect(filterOf(args), contains('[0:a]'));
      expect(filterOf(args), contains('[aout]'));
      expect(args, isNot(contains('-an')));
    });

    test('mute emits -an regardless of the flag', () {
      for (final flag in [true, false, null]) {
        final jobs = mapJobs(
          setOf([
            req('op_r', 'resize', {'width': 1280, 'height': 720}),
            req('op_m', 'mute'),
          ]),
          sourceHasAudio: flag,
        );
        expect(jobs, hasLength(1), reason: 'flag=$flag');
        final args = jobs.single.args;
        expect(args, contains('-an'), reason: 'flag=$flag');
        expect(args, isNot(contains('0:a')), reason: 'flag=$flag');
        expect(args, isNot(contains('[aout]')), reason: 'flag=$flag');
      }
    });

    test('null flag keeps byte-identical legacy args', () {
      final legacy = CommandMapper.mapOperations(
        trimResize(),
        clipPathMap,
        outDir,
        defaultPath: input,
        projectDir: projectDir,
      );
      final explicitNull = mapJobs(trimResize(), sourceHasAudio: null);
      expect(explicitNull.single.args, equals(legacy.single.args));
      // Legacy behavior preserved: audio-present is the common case, so
      // the chained fragments still map `[aout]` from `[0:a]`.
      expect(legacy.single.args, containsAll(['-map', '[aout]']));

      final legacySilent = CommandMapper.mapOperations(
        setOf([
          req('op_r', 'resize', {'width': 1280, 'height': 720}),
          req('op_o', 'rotate', {'degrees': 90}),
        ]),
        clipPathMap,
        outDir,
        defaultPath: input,
        projectDir: projectDir,
      );
      expect(legacySilent.single.args, containsAll(['-map', '0:a']));
    });

    test('watermark+text split path is unaffected by the flag', () {
      final split = setOf([
        req('op_w', 'overlay_watermark', {'image_path': wm1}),
        req('op_t', 'overlay_text', {'text': 'hi'}),
      ]);
      final withoutFlag = CommandMapper.mapOperations(
        split,
        clipPathMap,
        outDir,
        defaultPath: input,
        projectDir: projectDir,
      );
      final withFlag = mapJobs(split, sourceHasAudio: false);
      expect(withFlag, hasLength(2));
      expect(
        [for (final j in withFlag) j.args],
        equals([for (final j in withoutFlag) j.args]),
      );
    });
  });
}
