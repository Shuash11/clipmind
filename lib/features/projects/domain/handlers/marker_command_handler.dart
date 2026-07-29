import 'package:clipmind/core/results/result.dart';

import '../commands/marker_commands.dart';
import '../commands/project_command.dart';
import '../entities/project_state_snapshot.dart';
import '../entities/timeline_marker.dart';
import 'command_handler_result.dart';

final class MarkerCommandHandler {
  const MarkerCommandHandler();

  bool handles(ProjectCommand command) =>
      command is CreateMarkerCommand ||
      command is UpdateMarkerCommand ||
      command is DeleteMarkerCommand;

  Result<CommandHandlerResult> apply(
    ProjectStateSnapshot state,
    ProjectCommand command,
  ) {
    if (command is CreateMarkerCommand) return _create(state, command);
    if (command is UpdateMarkerCommand) return _update(state, command);
    if (command is DeleteMarkerCommand) return _delete(state, command);
    return const Failure(
      ProjectValidationFailure('Unsupported marker command'),
    );
  }

  Result<CommandHandlerResult> _create(
    ProjectStateSnapshot state,
    CreateMarkerCommand command,
  ) {
    if (state.markers.any((marker) => marker.id == command.markerId) ||
        !_valid(
          command.label,
          command.color,
          command.atMs,
          command.startMs,
          command.endMs,
        )) {
      return const Failure(ProjectValidationFailure('Invalid marker'));
    }
    return Success(
      CommandHandlerResult(
        state: state.copyWith(
          markers: [
            ...state.markers,
            TimelineMarker(
              id: command.markerId,
              label: command.label,
              color: command.color,
              atMs: command.atMs,
              startMs: command.startMs,
              endMs: command.endMs,
            ),
          ],
        ),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: [command.markerId],
        ),
      ),
    );
  }

  Result<CommandHandlerResult> _update(
    ProjectStateSnapshot state,
    UpdateMarkerCommand command,
  ) {
    if (!state.markers.any((marker) => marker.id == command.markerId) ||
        !_valid(
          command.label,
          command.color,
          command.atMs,
          command.startMs,
          command.endMs,
        )) {
      return const Failure(ProjectValidationFailure('Invalid marker'));
    }
    return Success(
      CommandHandlerResult(
        state: state.copyWith(
          markers: state.markers.map((marker) {
            if (marker.id != command.markerId) return marker;
            return TimelineMarker(
              id: marker.id,
              label: command.label,
              color: command.color,
              atMs: command.atMs,
              startMs: command.startMs,
              endMs: command.endMs,
            );
          }).toList(),
        ),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: [command.markerId],
        ),
      ),
    );
  }

  Result<CommandHandlerResult> _delete(
    ProjectStateSnapshot state,
    DeleteMarkerCommand command,
  ) {
    if (!state.markers.any((marker) => marker.id == command.markerId)) {
      return const Failure(ProjectValidationFailure('Unknown marker'));
    }
    return Success(
      CommandHandlerResult(
        state: state.copyWith(
          markers: state.markers
              .where((marker) => marker.id != command.markerId)
              .toList(),
        ),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: [command.markerId],
        ),
      ),
    );
  }

  bool _valid(
    String label,
    String color,
    int? atMs,
    int? startMs,
    int? endMs,
  ) =>
      label.trim().isNotEmpty &&
      label.length <= 120 &&
      RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color) &&
      ((atMs != null && startMs == null && endMs == null && atMs >= 0) ||
          (atMs == null &&
              startMs != null &&
              endMs != null &&
              startMs >= 0 &&
              startMs < endMs));
}
