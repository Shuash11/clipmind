import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/ffmpeg/command_builder.dart';

void main() {
  group('CommandBuilder.trim', () {
    test('returns args containing -ss and -to', () {
      final args = CommandBuilder.trim('input.mp4', '00:00:10', '00:00:30');
      expect(args, containsAll(['-ss', '00:00:10', '-to', '00:00:30']));
    });

    test('returns args containing -i and -c copy', () {
      final args = CommandBuilder.trim('input.mp4', '5', '15');
      expect(args, containsAll(['-i', 'input.mp4', '-c', 'copy']));
    });

    test('handles 0 duration trim', () {
      final args = CommandBuilder.trim('input.mp4', '00:00:10', '00:00:10');
      expect(args, containsAll(['-ss', '00:00:10', '-to', '00:00:10']));
    });

    test('handles float seconds', () {
      final args = CommandBuilder.trim('input.mp4', '0.5', '10.25');
      expect(args, containsAll(['-ss', '0.5', '-to', '10.25']));
    });
  });

  group('CommandBuilder.cut', () {
    test('returns select filter expression', () {
      final args = CommandBuilder.cut('input.mp4', '5', '15');
      final joined = args.join(' ');
      expect(joined, contains("select='not(between(t,5,15))'"));
      expect(joined, contains("aselect='not(between(t,5,15))'"));
      expect(joined, contains('setpts=N/FRAME_RATE/TB'));
      expect(joined, contains('asetpts=N/SR/TB'));
    });

    test('legacy path has no input seeking when range is absent', () {
      final args = CommandBuilder.cut('input.mp4', '5', '15');
      expect(args.sublist(0, 2), equals(['-i', 'input.mp4']));
      expect(args.contains('-ss'), isFalse);
      expect(args.contains('-t'), isFalse);
    });

    test('legacy path when only one range param is present', () {
      final onlyStart = CommandBuilder.cut(
        'input.mp4',
        '5',
        '15',
        clipStartSec: 5.0,
      );
      expect(onlyStart.contains('-ss'), isFalse);
      final onlyLen = CommandBuilder.cut(
        'input.mp4',
        '5',
        '15',
        clipDurationSec: 55.0,
      );
      expect(onlyLen.contains('-ss'), isFalse);
    });
  });

  group('CommandBuilder.cut ranged (Cycle 6 Phase 2 D2)', () {
    test('composes -ss/-t with shifted between times', () {
      final args = CommandBuilder.cut(
        'input.mp4',
        '00:00:10.000',
        '00:00:20.000',
        clipStartSec: 5.0,
        clipDurationSec: 55.0,
      );
      // Input-side restriction: -ss 5.0 -i input -t 55.0.
      expect(args, containsAll(['-ss', '5.0', '-i', 'input.mp4', '-t', '55.0']));
      expect(
        args.indexOf('-ss'),
        lessThan(args.indexOf('-i')),
      );
      expect(
        args.indexOf('-i'),
        lessThan(args.indexOf('-t')),
      );
      // File times [10, 20] shift to clip-relative [5.0, 15.0].
      final joined = args.join(' ');
      expect(joined, contains('between(t,5.0,15.0)'));
      expect(joined, contains("select='not(between(t,5.0,15.0))'"));
      expect(joined, contains("aselect='not(between(t,5.0,15.0))'"));
    });

    test('shifts plain decimal seconds (manual path format)', () {
      final args = CommandBuilder.cut(
        'input.mp4',
        '15.000',
        '25.000',
        clipStartSec: 10.0,
        clipDurationSec: 50.0,
      );
      expect(args.join(' '), contains('between(t,5.0,15.0)'));
    });

    test('shiftedCutTime rounds to the millisecond', () {
      expect(CommandBuilder.shiftedCutTime('00:00:10.000', 5.0), equals('5.0'));
      expect(CommandBuilder.shiftedCutTime('15.000', 10.0), equals('5.0'));
      expect(CommandBuilder.shiftedCutTime('00:00:10.123', 5.0), equals('5.123'));
      expect(CommandBuilder.shiftedCutTime('nope', 5.0), equals('nope'));
    });

    test('clipSpan == fileLen is equivalent to the legacy path', () {
      const removeStart = '00:00:10.000';
      const removeEnd = '00:00:20.000';
      final legacy = CommandBuilder.cut('input.mp4', removeStart, removeEnd);
      final ranged = CommandBuilder.cut(
        'input.mp4',
        removeStart,
        removeEnd,
        clipStartSec: 0.0,
        clipDurationSec: 60.0,
      );
      // Shifted times equal the originals numerically (0 offset).
      expect(CommandBuilder.shiftedCutTime(removeStart, 0.0), equals('10.0'));
      expect(CommandBuilder.shiftedCutTime(removeEnd, 0.0), equals('20.0'));
      expect(legacy.join(' '), contains('between(t,00:00:10.000,00:00:20.000)'));
      expect(ranged.join(' '), contains('between(t,10.0,20.0)'));
      // Output extent matches: fileLen − removedLen == clipLen − removedLen.
      const fileLen = 60.0;
      const clipLen = 60.0;
      const removedLen = 10.0;
      expect(clipLen - removedLen, equals(fileLen - removedLen));
      expect(ranged, containsAll(['-ss', '0.0', '-t', '60.0']));
    });
  });

  group('CommandBuilder.merge', () {
    test('builds concat filter for 2 inputs', () {
      final args = CommandBuilder.merge(['a.mp4', 'b.mp4']);
      expect(args, containsAll(['-i', 'a.mp4', '-i', 'b.mp4']));
      expect(args.join(' '), contains('concat=n=2'));
    });

    test('builds concat filter for 3 inputs', () {
      final args = CommandBuilder.merge(['a.mp4', 'b.mp4', 'c.mp4']);
      final joined = args.join(' ');
      expect(joined, contains('concat=n=3'));
      expect(joined, contains('[0:v:0][0:a:0][1:v:0][1:a:0][2:v:0][2:a:0]'));
    });

    test('maps output streams', () {
      final args = CommandBuilder.merge(['a.mp4', 'b.mp4']);
      expect(args, containsAll(['-map', '[outv]', '-map', '[outa]']));
    });
  });

  group('CommandBuilder.changeSpeed', () {
    test('handles factor <= 2.0 with single atempo', () {
      final args = CommandBuilder.changeSpeed('input.mp4', 1.5);
      final joined = args.join(' ');
      expect(joined, contains('atempo=1.5'));
      expect(joined, contains('setpts=PTS/1.5'));
    });

    test('chained atempo for factor > 2.0', () {
      final args = CommandBuilder.changeSpeed('input.mp4', 4.0);
      final joined = args.join(' ');
      expect(joined, contains('atempo=2.0,atempo=2.0'));
    });

    test('chained atempo for factor > 4.0', () {
      final args = CommandBuilder.changeSpeed('input.mp4', 6.0);
      final joined = args.join(' ');
      expect(joined, contains('atempo=2.0,atempo=2.0,atempo=1.5'));
    });

    test('atempo chaining for 0.25 speed', () {
      final args = CommandBuilder.changeSpeed('input.mp4', 0.25);
      final joined = args.join(' ');
      expect(joined, contains('atempo=0.5,atempo=0.5'));
    });

    test('handles boundary factor 2.0 without chaining', () {
      final args = CommandBuilder.changeSpeed('input.mp4', 2.0);
      final joined = args.join(' ');
      expect(joined, contains('atempo=2.0'));
      expect(RegExp(r'atempo=').allMatches(joined).length, 1);
    });

    test('handles boundary factor 0.5 without chaining', () {
      final args = CommandBuilder.changeSpeed('input.mp4', 0.5);
      final joined = args.join(' ');
      expect(joined, contains('atempo=0.5'));
      expect(RegExp(r'atempo=').allMatches(joined).length, 1);
    });

    test('produces filter_complex with video and audio maps', () {
      final args = CommandBuilder.changeSpeed('input.mp4', 2.0);
      expect(
        args,
        containsAll(['-filter_complex', '-map', '[vout]', '-map', '[aout]']),
      );
    });
  });

  group('CommandBuilder.mute', () {
    test('returns -an and -c:v copy', () {
      final args = CommandBuilder.mute('input.mp4');
      expect(args, containsAll(['-an', '-c:v', 'copy']));
    });
  });

  group('CommandBuilder.overlayText', () {
    test('includes drawtext filter with escaped text', () {
      final args = CommandBuilder.overlayText(
        'input.mp4',
        text: "it's a test: line 1",
        position: 'center',
        start: '0',
        end: '0',
      );
      final joined = args.join(' ');
      expect(joined, contains("text='it\\'s a test\\: line 1'"));
      expect(joined, contains('x=(w-text_w)/2'));
      expect(joined, contains('y=(h-text_h)/2'));
    });

    test('sets enable for non-zero time range', () {
      final args = CommandBuilder.overlayText(
        'input.mp4',
        text: 'hello',
        position: 'top-right',
        start: '5',
        end: '15',
      );
      final joined = args.join(' ');
      expect(joined, contains("enable='between(t,5,15)'"));
      expect(joined, contains('x=W-w-10'));
    });

    test('default position is top-left', () {
      final args = CommandBuilder.overlayText(
        'input.mp4',
        text: 'hello',
        position: 'unknown',
        start: '0',
        end: '0',
      );
      final joined = args.join(' ');
      expect(joined, contains('x=10'));
      expect(joined, contains('y=10'));
    });
  });

  group('CommandBuilder.resize', () {
    test('fill mode uses scale+crop', () {
      final args = CommandBuilder.resize('input.mp4', 1920, 1080, 'fill');
      final joined = args.join(' ');
      expect(joined, contains('scale=1920:1080:force_original_aspect_ratio=1'));
      expect(joined, contains('crop=1920:1080'));
    });

    test('fit mode uses scale+pad', () {
      final args = CommandBuilder.resize('input.mp4', 640, 480, 'fit');
      final joined = args.join(' ');
      expect(joined, contains('scale=640:480:force_original_aspect_ratio=1'));
      expect(joined, contains('pad=640:480:(ow-iw)/2:(oh-ih)/2'));
    });

    test('stretch mode uses plain scale', () {
      final args = CommandBuilder.resize('input.mp4', 640, 480, 'stretch');
      expect(args.join(' '), contains('scale=640:480'));
    });

    test('default fit uses scale with aspect ratio', () {
      final args = CommandBuilder.resize('input.mp4', 320, 240, 'auto');
      final joined = args.join(' ');
      expect(joined, contains('scale=320:240:force_original_aspect_ratio=1'));
    });
  });

  group('CommandBuilder.rotate', () {
    test('90 degrees uses transpose=1', () {
      final args = CommandBuilder.rotate('input.mp4', 90);
      expect(args.join(' '), contains('transpose=1'));
      expect(RegExp(r'transpose=').allMatches(args.join(' ')).length, 1);
    });

    test('180 degrees uses double transpose', () {
      final args = CommandBuilder.rotate('input.mp4', 180);
      final joined = args.join(' ');
      expect(joined, contains('transpose=1,transpose=1'));
    });

    test('270 degrees uses transpose=2', () {
      final args = CommandBuilder.rotate('input.mp4', 270);
      expect(args.join(' '), contains('transpose=2'));
    });

    test('other angles use rotate filter', () {
      final args = CommandBuilder.rotate('input.mp4', 45);
      expect(args.join(' '), contains('rotate=45.0*PI/180'));
    });
  });

  group('CommandBuilder.extractAudio', () {
    test('mp3 format uses libmp3lame', () {
      final args = CommandBuilder.extractAudio('input.mp4', 'mp3');
      expect(args, containsAll(['-vn', '-c:a', 'libmp3lame']));
    });

    test('aac format uses aac codec', () {
      final args = CommandBuilder.extractAudio('input.mp4', 'aac');
      expect(args, containsAll(['-vn', '-c:a', 'aac']));
    });

    test('wav format uses pcm_s16le', () {
      final args = CommandBuilder.extractAudio('input.mp4', 'wav');
      expect(args, containsAll(['-vn', '-c:a', 'pcm_s16le']));
    });

    test('unknown format defaults to libmp3lame', () {
      final args = CommandBuilder.extractAudio('input.mp4', 'unknown');
      expect(args, containsAll(['-vn', '-c:a', 'libmp3lame']));
    });
  });

  group('CommandBuilder.generateThumbnail', () {
    test('returns args with -ss before -i', () {
      final args = CommandBuilder.generateThumbnail('input.mp4', '00:00:10');
      expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
      expect(args, containsAll(['-ss', '00:00:10', '-i', 'input.mp4']));
    });

    test('includes -vframes and -q:v', () {
      final args = CommandBuilder.generateThumbnail('input.mp4', '5');
      expect(args, containsAll(['-vframes', '1', '-q:v', '2']));
    });
  });

  group('CommandBuilder.changeFormat', () {
    test('mp4 uses libx264 and aac', () {
      final args = CommandBuilder.changeFormat('input.mov', 'mp4', null);
      expect(args, containsAll(['-c:v', 'libx264', '-c:a', 'aac']));
    });

    test('gif uses gif video codec and no audio', () {
      final args = CommandBuilder.changeFormat('input.mp4', 'gif', null);
      expect(args, containsAll(['-c:v', 'gif']));
      expect(args.any((a) => a == '-c:a'), isFalse);
    });

    test('webm uses vp9 and libopus', () {
      final args = CommandBuilder.changeFormat('input.mp4', 'webm', null);
      expect(args, containsAll(['-c:v', 'libvpx-vp9', '-c:a', 'libopus']));
    });

    test('unknown format uses codecPreset when provided', () {
      final args = CommandBuilder.changeFormat(
        'input.mp4',
        'custom',
        'libx265',
      );
      expect(args, containsAll(['-c:v', 'libx265', '-c:a', 'aac']));
    });
  });

  group('CommandBuilder.adjustBrightness', () {
    test('normal value produces eq filter', () {
      final args = CommandBuilder.adjustBrightness('input.mp4', 0.5);
      expect(args.join(' '), contains('eq=brightness=0.5'));
    });

    test('clamps value at -1.0', () {
      final args = CommandBuilder.adjustBrightness('input.mp4', -2.0);
      expect(args.join(' '), contains('eq=brightness=-1.0'));
    });

    test('clamps value at 1.0', () {
      final args = CommandBuilder.adjustBrightness('input.mp4', 5.0);
      expect(args.join(' '), contains('eq=brightness=1.0'));
    });

    test('handles exact boundary -1.0', () {
      final args = CommandBuilder.adjustBrightness('input.mp4', -1.0);
      expect(args.join(' '), contains('eq=brightness=-1.0'));
    });

    test('handles exact boundary 1.0', () {
      final args = CommandBuilder.adjustBrightness('input.mp4', 1.0);
      expect(args.join(' '), contains('eq=brightness=1.0'));
    });
  });

  group('CommandBuilder.changeVolume', () {
    test('volume filter with factor', () {
      final args = CommandBuilder.changeVolume('input.mp4', 0.5);
      expect(args.join(' '), contains('volume=0.5'));
    });

    test('volume filter with 2.0 factor', () {
      final args = CommandBuilder.changeVolume('input.mp4', 2.0);
      expect(args.join(' '), contains('volume=2.0'));
    });
  });

  group('CommandBuilder.overlayWatermark', () {
    test('uses colorchannelmixer for opacity', () {
      final args = CommandBuilder.overlayWatermark(
        'input.mp4',
        'wm.png',
        'bottom-right',
        0.8,
      );
      final joined = args.join(' ');
      expect(joined, contains('colorchannelmixer=aa=0.8'));
      expect(joined, contains('overlay=W-w-10:H-h-10'));
    });

    test('center position', () {
      final args = CommandBuilder.overlayWatermark(
        'input.mp4',
        'wm.png',
        'center',
        1.0,
      );
      final joined = args.join(' ');
      expect(joined, contains('overlay=(W-w)/2:(H-h)/2'));
    });

    test('clamps opacity between 0 and 1', () {
      final argsLow = CommandBuilder.overlayWatermark(
        'input.mp4',
        'wm.png',
        'bottom-right',
        -0.5,
      );
      final argsHigh = CommandBuilder.overlayWatermark(
        'input.mp4',
        'wm.png',
        'bottom-right',
        2.0,
      );
      expect(argsLow.join(' '), contains('aa=0.0'));
      expect(argsHigh.join(' '), contains('aa=1.0'));
    });

    test('maps video and audio streams', () {
      final args = CommandBuilder.overlayWatermark(
        'input.mp4',
        'wm.png',
        'bottom-right',
        0.5,
      );
      expect(args, containsAll(['-map', '[outv]', '-map', '0:a']));
    });
  });

  group('CommandBuilder.effectFilter', () {
    test('vignette strength 0.4 equals the FFmpeg default PI/5', () {
      expect(
        CommandBuilder.effectFilter(effect: 'vignette', strength: 0.4),
        startsWith('vignette=angle=0.6283185'),
      );
    });

    test('blur strength maps to gblur sigma with an app-chosen cap', () {
      expect(
        CommandBuilder.effectFilter(effect: 'blur', strength: 1.0),
        equals('gblur=sigma=20.0'),
      );
      expect(
        CommandBuilder.effectFilter(effect: 'blur'),
        startsWith('gblur=sigma=6.'),
      );
    });

    test('grayscale has no standalone filter (eq saturation zero)', () {
      expect(
        CommandBuilder.effectFilter(effect: 'grayscale'),
        equals('eq=saturation=0'),
      );
    });

    test('contrast and saturation clamp to 0-3', () {
      expect(
        CommandBuilder.effectFilter(effect: 'contrast', contrast: 9),
        equals('eq=contrast=3.0'),
      );
      expect(
        CommandBuilder.effectFilter(effect: 'saturation'),
        equals('eq=saturation=1.0'),
      );
    });

    test('effect() wraps the filter in a single-op job', () {
      final args = CommandBuilder.effect(
        'in.mp4',
        effect: 'vignette',
        strength: 0.4,
      );
      expect(args.sublist(0, 2), equals(['-i', 'in.mp4']));
      expect(args[2], equals('-vf'));
      expect(args[3], startsWith('vignette=angle='));
    });
  });

  group('CommandBuilder.transition audioMode', () {
    test('crossfade maps both outputs', () {
      final args = CommandBuilder.transition(
        'a.mp4',
        'b.mp4',
        audioMode: 'crossfade',
      );
      expect(args.join(' '), contains('acrossfade'));
      expect(args, containsAll(['-map', '[outv]', '-map', '[outa]']));
    });

    test('first/second map the bearing track without acrossfade', () {
      final first = CommandBuilder.transition('a.mp4', 'b.mp4',
          audioMode: 'first');
      expect(first.join(' '), contains('-map 0:a'));
      expect(first.join(' '), isNot(contains('acrossfade')));
      final second = CommandBuilder.transition('a.mp4', 'b.mp4',
          audioMode: 'second');
      expect(second.join(' '), contains('-map 1:a'));
      expect(second.join(' '), isNot(contains('acrossfade')));
    });

    test('none and unknown modes disable audio', () {
      for (final mode in ['none', 'bogus']) {
        final args = CommandBuilder.transition('a.mp4', 'b.mp4',
            audioMode: mode);
        expect(args, contains('-an'));
        expect(args.join(' '), isNot(contains('acrossfade')));
      }
    });
  });

  group('CommandBuilder.addAudio', () {
    test('mixes with amix when the clip has audio', () {
      final args = CommandBuilder.addAudio('clip.mp4', 'sound.wav');
      final joined = args.join(' ');
      expect(
        joined,
        contains(
          '[0:a][1:a]amix=inputs=2:duration=first:dropout_transition=2[aout]',
        ),
      );
      expect(args, containsAll(['-map', '0:v', '-map', '[aout]']));
    });

    test('volume scales the sound leg only', () {
      final args = CommandBuilder.addAudio(
        'clip.mp4',
        'sound.wav',
        volume: 0.8,
      );
      final joined = args.join(' ');
      expect(joined, contains('[1:a]volume=0.8[snd]'));
      expect(joined, contains('[0:a][snd]amix='));
      expect(args, containsAll(['-map', '0:v', '-map', '[aout]']));
    });

    test('one-sided: sound is the only track without amix', () {
      final args = CommandBuilder.addAudio(
        'clip.mp4',
        'sound.wav',
        hasClipAudio: false,
      );
      expect(args.join(' '), isNot(contains('amix')));
      expect(args, containsAll(['-map', '0:v', '-map', '1:a']));
    });

    test('one-sided with volume filters the sound input', () {
      final args = CommandBuilder.addAudio(
        'clip.mp4',
        'sound.wav',
        volume: 0.5,
        hasClipAudio: false,
      );
      final joined = args.join(' ');
      expect(joined, contains('[1:a]volume=0.5[aout]'));
      expect(joined, isNot(contains('amix')));
      expect(args, containsAll(['-map', '0:v', '-map', '[aout]']));
    });
  });

  group('CommandBuilder.proceduralSoundSource', () {
    test('all 6 presets map to lavfi sources', () {
      expect(
        CommandBuilder.proceduralSoundSource('beep'),
        equals('sine=frequency=880:duration=0.3'),
      );
      expect(
        CommandBuilder.proceduralSoundSource('drone-low'),
        equals('sine=frequency=80:duration=10'),
      );
      expect(
        CommandBuilder.proceduralSoundSource('drone-mid'),
        equals('sine=frequency=180:duration=10'),
      );
      expect(
        CommandBuilder.proceduralSoundSource('hum'),
        equals('sine=frequency=60:duration=10'),
      );
      expect(
        CommandBuilder.proceduralSoundSource('static-noise'),
        contains('anoisesrc'),
      );
      final chime = CommandBuilder.proceduralSoundSource('alert-chime');
      expect(chime, contains('880'));
      expect(chime, contains('1320'));
    });

    test('unknown preset yields null', () {
      expect(CommandBuilder.proceduralSoundSource('nope'), isNull);
      expect(CommandBuilder.proceduralSoundSource(''), isNull);
    });

    test('lavfiToWav wraps a source as a wav job prefix', () {
      final args = CommandBuilder.lavfiToWav('sine=frequency=880:duration=0.3');
      expect(
        args,
        equals([
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=880:duration=0.3',
          '-c:a',
          'pcm_s16le',
        ]),
      );
    });
  });

  group('CommandBuilder.overlayText fontFile', () {
    test('omitted by default (backwards compatible)', () {
      final args = CommandBuilder.overlayText(
        'input.mp4',
        text: 'hello',
        position: 'center',
        start: '0',
        end: '0',
      );
      expect(args.join(' '), isNot(contains('fontfile')));
    });

    test('emits fontfile for an app-resolved path', () {
      final args = CommandBuilder.overlayText(
        'input.mp4',
        text: 'hello',
        position: 'center',
        start: '0',
        end: '0',
        fontFile: '/fonts/inter_regular.ttf',
      );
      expect(args.join(' '), contains('fontfile=/fonts/inter_regular.ttf'));
    });

    test('windows paths are normalized for the filter', () {
      final args = CommandBuilder.overlayText(
        'input.mp4',
        text: 'hello',
        position: 'center',
        start: '0',
        end: '0',
        fontFile: r'C:\fonts\inter_regular.ttf',
      );
      final joined = args.join(' ');
      expect(joined, contains(r'fontfile=C\:/fonts/inter_regular.ttf'));
    });
  });
}
