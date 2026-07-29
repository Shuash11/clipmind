// The public dependency names intentionally map to private stored fields.
// ignore_for_file: prefer_initializing_formals

import 'package:clipmind/core/results/result.dart';

import '../entities/project_state_snapshot.dart';
import '../handlers/clip_command_handler.dart';
import '../handlers/command_handler_result.dart';
import '../handlers/marker_command_handler.dart';
import '../handlers/overlay_command_handler.dart';
import '../handlers/tag_command_handler.dart';
import 'project_command.dart';

final class ProjectCommandExecutor {
  const ProjectCommandExecutor({
    required ClipCommandHandler clipHandler,
    required OverlayCommandHandler overlayHandler,
    required TagCommandHandler tagHandler,
    required MarkerCommandHandler markerHandler,
  }) : _clipHandler = clipHandler,
       _overlayHandler = overlayHandler,
       _tagHandler = tagHandler,
       _markerHandler = markerHandler;

  factory ProjectCommandExecutor.standard() => const ProjectCommandExecutor(
    clipHandler: ClipCommandHandler(),
    overlayHandler: OverlayCommandHandler(),
    tagHandler: TagCommandHandler(),
    markerHandler: MarkerCommandHandler(),
  );

  final ClipCommandHandler _clipHandler;
  final OverlayCommandHandler _overlayHandler;
  final TagCommandHandler _tagHandler;
  final MarkerCommandHandler _markerHandler;

  static const Set<String> _supportedTypes = {
    'trim_clip',
    'remove_clip_range',
    'arrange_clips',
    'set_clip_speed',
    'set_clip_muted',
    'set_clip_volume',
    'set_clip_transform',
    'set_clip_brightness',
    'add_text_overlay',
    'add_image_overlay',
    'create_tag',
    'update_tag',
    'delete_tag',
    'assign_tag',
    'unassign_tag',
    'create_marker',
    'update_marker',
    'delete_marker',
  };

  Set<String> get supportedTypes => _supportedTypes;

  Result<CommandExecution> applyAll(
    ProjectStateSnapshot before,
    List<ProjectCommand> commands,
  ) {
    var candidate = before;
    final summaries = <CanonicalCommandSummary>[];
    for (final command in commands) {
      final result = _dispatch(candidate, command);
      if (result case Success<CommandHandlerResult>(:final value)) {
        candidate = value.state;
        summaries.add(value.summary);
      } else {
        final error = (result as Failure<CommandHandlerResult>).error;
        return Failure(error);
      }
    }
    return Success(
      CommandExecution(candidateState: candidate, summaries: summaries),
    );
  }

  Result<CommandHandlerResult> _dispatch(
    ProjectStateSnapshot state,
    ProjectCommand command,
  ) {
    if (_clipHandler.handles(command)) {
      return _clipHandler.apply(state, command);
    }
    if (_overlayHandler.handles(command)) {
      return _overlayHandler.apply(state, command);
    }
    if (_tagHandler.handles(command)) {
      return _tagHandler.apply(state, command);
    }
    if (_markerHandler.handles(command)) {
      return _markerHandler.apply(state, command);
    }
    return Failure(
      ProjectValidationFailure('Unsupported command: ${command.type}'),
    );
  }
}
