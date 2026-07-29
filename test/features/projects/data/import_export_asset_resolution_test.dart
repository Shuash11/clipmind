import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/services/project_import_service.dart';
import 'package:clipmind/features/projects/domain/services/project_render_input_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_fakes.dart';
import '../support/project_test_data.dart';

void main() {
  test(
    'import creates media asset and asset-ID clip without embedding source in clip',
    () {
      final result =
          ProjectImportService(
            SequenceIdGenerator(['asset-2', 'clip-2']),
          ).addLocalMedia(
            documentWithOneClip(),
            sourcePath: r'C:\media\new.mp4',
            trackId: 'track-1',
            durationMs: 200,
          );
      final document = (result as Success<ProjectDocument>).value;
      final clip = document.currentState.tracks.single.clips.last;
      expect(document.currentState.assets.last.sourcePath, r'C:\media\new.mp4');
      expect(clip.assetId, 'asset-2');
      expect(clip.id, 'clip-2');
    },
  );

  test(
    'render input resolution uses local asset mapping and rejects missing asset before FFmpeg',
    () {
      final gateway = RecordingRenderGateway();
      final resolver = ProjectRenderInputResolver(gateway);
      final resolved = resolver.resolveAndRender(documentWithOneClip());
      expect(resolved, isA<Success<void>>());
      expect(gateway.inputPaths, [r'C:\media\source.mp4']);

      final missing = resolver.resolveAndRender(
        documentWithOneClip(state: stateWithOneClip(assetId: 'missing')),
      );
      expect(missing, isA<Failure<void>>());
      expect(gateway.renderCalls, 1);
    },
  );
}
