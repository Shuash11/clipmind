import 'package:clipmind/core/results/result.dart';

import '../entities/project_document.dart';

abstract interface class ProjectRenderGateway {
  void render(List<String> paths);
}

final class ProjectRenderInputResolver {
  const ProjectRenderInputResolver(this._gateway);

  final ProjectRenderGateway _gateway;

  Result<void> resolveAndRender(ProjectDocument document) {
    final paths = <String>[];
    for (final track in document.currentState.tracks) {
      for (final clip in track.clips) {
        final asset = document.currentState.assetById(clip.assetId);
        if (asset == null) {
          return const Failure(
            ProjectValidationFailure('Clip references missing media asset'),
          );
        }
        if (!paths.contains(asset.sourcePath)) paths.add(asset.sourcePath);
      }
    }
    _gateway.render(paths);
    return const Success(null);
  }
}
