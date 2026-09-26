import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_fakes.dart';

void main() {
  test(
    'factory allocates tag, marker, text, image, and split IDs deterministically',
    () {
      final factory = ProjectCommandFactory(
        SequenceIdGenerator([
          'tag-1',
          'marker-1',
          'text-1',
          'image-1',
          'right-clip-1',
        ]),
      );
      expect(
        factory.createTag(name: 'Travel', color: '#112233').tagId,
        'tag-1',
      );
      expect(
        factory
            .createMarker(label: 'Beat', color: '#334455', atMs: 10)
            .markerId,
        'marker-1',
      );
      expect(
        factory
            .addTextOverlay(
              trackId: 'track-1',
              startMs: 0,
              endMs: 10,
              text: 'Hi',
              x: 0,
              y: 0,
            )
            .overlayId,
        'text-1',
      );
      expect(
        factory
            .addImageOverlay(
              trackId: 'track-1',
              assetId: 'asset-1',
              startMs: 0,
              endMs: 10,
              x: 0,
              y: 0,
              width: 10,
              height: 10,
            )
            .overlayId,
        'image-1',
      );
      expect(
        factory
            .removeClipRange(clipId: 'clip-1', startMs: 10, endMs: 20)
            .rightClipId,
        'right-clip-1',
      );
    },
  );
}
