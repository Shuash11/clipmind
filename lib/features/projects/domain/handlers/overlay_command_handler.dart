import 'package:clipmind/core/results/result.dart';

import '../commands/overlay_commands.dart';
import '../commands/project_command.dart';
import '../entities/project_overlay.dart';
import '../entities/project_state_snapshot.dart';
import 'command_handler_result.dart';

final class OverlayCommandHandler {
  const OverlayCommandHandler();

  bool handles(ProjectCommand command) =>
      command is AddTextOverlayCommand || command is AddImageOverlayCommand;

  Result<CommandHandlerResult> apply(
    ProjectStateSnapshot state,
    ProjectCommand command,
  ) {
    if (command is AddTextOverlayCommand) return _text(state, command);
    if (command is AddImageOverlayCommand) return _image(state, command);
    return const Failure(
      ProjectValidationFailure('Unsupported overlay command'),
    );
  }

  Result<CommandHandlerResult> _text(
    ProjectStateSnapshot state,
    AddTextOverlayCommand command,
  ) {
    if (_overlayIdExists(state, command.overlayId) ||
        !_trackExists(state, command.trackId) ||
        !_validTiming(command.startMs, command.endMs) ||
        command.text.isEmpty ||
        command.text.length > 500 ||
        !_unit(command.x) ||
        !_unit(command.y)) {
      return const Failure(ProjectValidationFailure('Invalid text overlay'));
    }
    final overlay = ProjectOverlay.text(
      id: command.overlayId,
      trackId: command.trackId,
      startMs: command.startMs,
      endMs: command.endMs,
      text: command.text,
      x: command.x,
      y: command.y,
    );
    return Success(
      CommandHandlerResult(
        state: state.copyWith(overlays: [...state.overlays, overlay]),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: [overlay.id],
        ),
      ),
    );
  }

  Result<CommandHandlerResult> _image(
    ProjectStateSnapshot state,
    AddImageOverlayCommand command,
  ) {
    if (_overlayIdExists(state, command.overlayId) ||
        !_trackExists(state, command.trackId) ||
        state.assetById(command.assetId) == null ||
        !_validTiming(command.startMs, command.endMs) ||
        !_unit(command.x) ||
        !_unit(command.y) ||
        command.width < 1 ||
        command.width > 7680 ||
        command.height < 1 ||
        command.height > 7680) {
      return const Failure(ProjectValidationFailure('Invalid image overlay'));
    }
    final overlay = ProjectOverlay.image(
      id: command.overlayId,
      trackId: command.trackId,
      assetId: command.assetId,
      startMs: command.startMs,
      endMs: command.endMs,
      x: command.x,
      y: command.y,
      width: command.width,
      height: command.height,
    );
    return Success(
      CommandHandlerResult(
        state: state.copyWith(overlays: [...state.overlays, overlay]),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: [overlay.id],
        ),
      ),
    );
  }

  bool _trackExists(ProjectStateSnapshot state, String trackId) =>
      state.tracks.any((track) => track.id == trackId);

  bool _overlayIdExists(ProjectStateSnapshot state, String id) =>
      state.overlays.any((overlay) => overlay.id == id);

  bool _validTiming(int startMs, int endMs) => startMs >= 0 && startMs < endMs;
  bool _unit(double value) => value.isFinite && value >= 0 && value <= 1;
}
