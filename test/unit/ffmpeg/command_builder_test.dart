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
      expect(args, containsAll(['-filter_complex', '-map', '[vout]', '-map', '[aout]']));
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
      final args = CommandBuilder.changeFormat('input.mp4', 'custom', 'libx265');
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
        'input.mp4', 'wm.png', 'bottom-right', 0.8,
      );
      final joined = args.join(' ');
      expect(joined, contains('colorchannelmixer=aa=0.8'));
      expect(joined, contains('overlay=W-w-10:H-h-10'));
    });

    test('center position', () {
      final args = CommandBuilder.overlayWatermark(
        'input.mp4', 'wm.png', 'center', 1.0,
      );
      final joined = args.join(' ');
      expect(joined, contains('overlay=(W-w)/2:(H-h)/2'));
    });

    test('clamps opacity between 0 and 1', () {
      final argsLow = CommandBuilder.overlayWatermark('input.mp4', 'wm.png', 'bottom-right', -0.5);
      final argsHigh = CommandBuilder.overlayWatermark('input.mp4', 'wm.png', 'bottom-right', 2.0);
      expect(argsLow.join(' '), contains('aa=0.0'));
      expect(argsHigh.join(' '), contains('aa=1.0'));
    });

    test('maps video and audio streams', () {
      final args = CommandBuilder.overlayWatermark('input.mp4', 'wm.png', 'bottom-right', 0.5);
      expect(args, containsAll(['-map', '[outv]', '-map', '0:a']));
    });
  });
}
