import 'package:clipmind/core/results/result.dart';

import '../commands/project_command.dart';
import '../commands/tag_commands.dart';
import '../entities/project_state_snapshot.dart';
import '../entities/tag_definition.dart';
import 'command_handler_result.dart';

final class TagCommandHandler {
  const TagCommandHandler();

  bool handles(ProjectCommand command) =>
      command is CreateTagCommand ||
      command is UpdateTagCommand ||
      command is DeleteTagCommand ||
      command is AssignTagCommand ||
      command is UnassignTagCommand;

  Result<CommandHandlerResult> apply(
    ProjectStateSnapshot state,
    ProjectCommand command,
  ) {
    if (command is CreateTagCommand) return _create(state, command);
    if (command is UpdateTagCommand) return _update(state, command);
    if (command is DeleteTagCommand) return _delete(state, command);
    if (command is AssignTagCommand) {
      return _assignment(state, command, assign: true);
    }
    if (command is UnassignTagCommand) {
      return _assignment(state, command, assign: false);
    }
    return const Failure(ProjectValidationFailure('Unsupported tag command'));
  }

  Result<CommandHandlerResult> _create(
    ProjectStateSnapshot state,
    CreateTagCommand command,
  ) {
    final name = _normalized(command.name);
    if (state.tags.any((tag) => tag.id == command.tagId) ||
        !_validName(name) ||
        !_validColor(command.color) ||
        state.tags.any((tag) => _normalized(tag.name) == name)) {
      return const Failure(ProjectValidationFailure('Invalid tag'));
    }
    return Success(
      CommandHandlerResult(
        state: state.copyWith(
          tags: [
            ...state.tags,
            TagDefinition(
              id: command.tagId,
              name: command.name.trim(),
              color: command.color,
            ),
          ],
        ),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: [command.tagId],
        ),
      ),
    );
  }

  Result<CommandHandlerResult> _update(
    ProjectStateSnapshot state,
    UpdateTagCommand command,
  ) {
    final name = _normalized(command.name);
    if (!_validName(name) ||
        !_validColor(command.color) ||
        !state.tags.any((tag) => tag.id == command.tagId) ||
        state.tags.any(
          (tag) => tag.id != command.tagId && _normalized(tag.name) == name,
        )) {
      return const Failure(ProjectValidationFailure('Invalid tag update'));
    }
    return Success(
      CommandHandlerResult(
        state: state.copyWith(
          tags: state.tags.map((tag) {
            return tag.id == command.tagId
                ? TagDefinition(
                    id: tag.id,
                    name: command.name.trim(),
                    color: command.color,
                  )
                : tag;
          }).toList(),
        ),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: [command.tagId],
        ),
      ),
    );
  }

  Result<CommandHandlerResult> _delete(
    ProjectStateSnapshot state,
    DeleteTagCommand command,
  ) {
    if (!state.tags.any((tag) => tag.id == command.tagId)) {
      return const Failure(ProjectValidationFailure('Unknown tag'));
    }
    final affected = <String>[command.tagId];
    final assets = state.assets.map((asset) {
      if (!asset.tagIds.contains(command.tagId)) return asset;
      affected.add(asset.id);
      return asset.copyWith(tagIds: {...asset.tagIds}..remove(command.tagId));
    }).toList();
    final tracks = state.tracks.map((track) {
      return track.copyWith(
        clips: track.clips.map((clip) {
          if (!clip.tagIds.contains(command.tagId)) return clip;
          affected.add(clip.id);
          return clip.copyWith(tagIds: {...clip.tagIds}..remove(command.tagId));
        }).toList(),
      );
    }).toList();
    return Success(
      CommandHandlerResult(
        state: state.copyWith(
          tags: state.tags.where((tag) => tag.id != command.tagId).toList(),
          assets: assets,
          tracks: tracks,
        ),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: affected,
        ),
      ),
    );
  }

  Result<CommandHandlerResult> _assignment(
    ProjectStateSnapshot state,
    ProjectCommand command, {
    required bool assign,
  }) {
    final tagId = command is AssignTagCommand
        ? command.tagId
        : (command as UnassignTagCommand).tagId;
    final targetKind = command is AssignTagCommand
        ? command.targetKind
        : (command as UnassignTagCommand).targetKind;
    final targetId = command is AssignTagCommand
        ? command.targetId
        : (command as UnassignTagCommand).targetId;
    if (!state.tags.any((tag) => tag.id == tagId)) {
      return const Failure(ProjectValidationFailure('Unknown tag'));
    }
    if (targetKind == AssignmentTargetKind.asset) {
      var changed = false;
      final assets = state.assets.map((asset) {
        if (asset.id != targetId) return asset;
        final contains = asset.tagIds.contains(tagId);
        if (contains == assign) return asset;
        changed = true;
        final ids = {...asset.tagIds};
        assign ? ids.add(tagId) : ids.remove(tagId);
        return asset.copyWith(tagIds: ids);
      }).toList();
      if (!changed) {
        return const Failure(
          ProjectValidationFailure('Invalid tag assignment'),
        );
      }
      return Success(
        CommandHandlerResult(
          state: state.copyWith(assets: assets),
          summary: CanonicalCommandSummary(
            type: command.type,
            targetIds: [targetId],
          ),
        ),
      );
    }

    var changed = false;
    final tracks = state.tracks.map((track) {
      return track.copyWith(
        clips: track.clips.map((clip) {
          if (clip.id != targetId) return clip;
          final contains = clip.tagIds.contains(tagId);
          if (contains == assign) return clip;
          changed = true;
          final ids = {...clip.tagIds};
          assign ? ids.add(tagId) : ids.remove(tagId);
          return clip.copyWith(tagIds: ids);
        }).toList(),
      );
    }).toList();
    if (!changed) {
      return const Failure(ProjectValidationFailure('Invalid tag assignment'));
    }
    return Success(
      CommandHandlerResult(
        state: state.copyWith(tracks: tracks),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: [targetId],
        ),
      ),
    );
  }

  String _normalized(String value) => value.trim().toLowerCase();
  bool _validName(String value) => value.isNotEmpty && value.length <= 64;
  bool _validColor(String value) =>
      RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value);
}
