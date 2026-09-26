import 'package:clipmind/features/projects/domain/commands/marker_commands.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/commands/tag_commands.dart';
import 'package:clipmind/features/tagging/domain/tagging_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';

void main() {
  test(
    'manual intents return the exact factory commands and factory-issued IDs',
    () {
      final controller = TaggingController(
        ProjectCommandFactory(
          SequenceIdGenerator(['tag-created', 'marker-created']),
        ),
      );

      final createdTag = controller.createTag(name: 'Travel', color: '#112233');
      final createdMarker = controller.createMarker(
        label: 'Beat',
        color: '#445566',
        atMs: 250,
      );

      expect(createdTag, isA<CreateTagCommand>());
      expect(createdTag.tagId, 'tag-created');
      expect(createdTag.name, 'Travel');
      expect(createdTag.color, '#112233');
      expect(createdMarker, isA<CreateMarkerCommand>());
      expect(createdMarker.markerId, 'marker-created');
      expect(createdMarker.label, 'Beat');
      expect(createdMarker.color, '#445566');
      expect(createdMarker.atMs, 250);
    },
  );

  test(
    'update, deletion, and assignment intents preserve typed parameters',
    () {
      final controller = TaggingController(
        ProjectCommandFactory(SequenceIdGenerator(const [])),
      );

      final updateTag = controller.updateTag(
        tagId: 'tag-1',
        name: 'Work',
        color: '#AABBCC',
      );
      final deleteTag = controller.deleteTag(tagId: 'tag-1');
      final assign = controller.assignTag(
        tagId: 'tag-1',
        targetKind: AssignmentTargetKind.asset,
        targetId: 'asset-1',
      );
      final unassign = controller.unassignTag(
        tagId: 'tag-1',
        targetKind: AssignmentTargetKind.clip,
        targetId: 'clip-1',
      );
      final updateMarker = controller.updateMarker(
        markerId: 'marker-1',
        label: 'Section',
        color: '#123456',
        startMs: 100,
        endMs: 400,
      );
      final deleteMarker = controller.deleteMarker(markerId: 'marker-1');

      expect(updateTag, isA<UpdateTagCommand>());
      expect(updateTag.tagId, 'tag-1');
      expect(updateTag.name, 'Work');
      expect(updateTag.color, '#AABBCC');
      expect(deleteTag, isA<DeleteTagCommand>());
      expect(deleteTag.tagId, 'tag-1');
      expect(assign, isA<AssignTagCommand>());
      expect(assign.tagId, 'tag-1');
      expect(assign.targetKind, AssignmentTargetKind.asset);
      expect(assign.targetId, 'asset-1');
      expect(unassign, isA<UnassignTagCommand>());
      expect(unassign.tagId, 'tag-1');
      expect(unassign.targetKind, AssignmentTargetKind.clip);
      expect(unassign.targetId, 'clip-1');
      expect(updateMarker, isA<UpdateMarkerCommand>());
      expect(updateMarker.markerId, 'marker-1');
      expect(updateMarker.label, 'Section');
      expect(updateMarker.color, '#123456');
      expect(updateMarker.startMs, 100);
      expect(updateMarker.endMs, 400);
      expect(updateMarker.atMs, isNull);
      expect(deleteMarker, isA<DeleteMarkerCommand>());
      expect(deleteMarker.markerId, 'marker-1');
    },
  );
}
