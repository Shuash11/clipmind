import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/entities/clip_transform.dart';
import 'package:clipmind/features/projects/domain/entities/media_asset.dart';
import 'package:clipmind/features/projects/domain/entities/persisted_transaction_record.dart';
import 'package:clipmind/features/projects/domain/entities/project_clip.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/entities/project_overlay.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';
import 'package:clipmind/features/projects/domain/entities/project_track.dart';
import 'package:clipmind/features/projects/domain/entities/tag_definition.dart';

final DateTime fixtureTime = DateTime.utc(2026, 7, 27, 12);

ProjectStateSnapshot stateWithOneClip({
  String clipId = 'clip-1',
  String assetId = 'asset-1',
  int startMs = 0,
  int endMs = 1000,
  int positionMs = 0,
  Set<String> tagIds = const {'tag-1'},
  ClipTransform transform = const ClipTransform(
    width: 1920,
    height: 1080,
    fit: ClipFit.contain,
    rotationDegrees: 0,
  ),
  double speed = 1,
  bool muted = false,
  double volume = 1,
  double brightness = 0,
}) {
  return ProjectStateSnapshot(
    assets: [
      MediaAsset(
        id: 'asset-1',
        sourcePath: r'C:\media\source.mp4',
        displayName: 'source.mp4',
        durationMs: 1000,
        tagIds: {'tag-1'},
      ),
    ],
    tracks: [
      ProjectTrack(
        id: 'track-1',
        kind: ProjectTrackKind.video,
        clips: [
          ProjectClip(
            id: clipId,
            assetId: assetId,
            trackId: 'track-1',
            startMs: startMs,
            endMs: endMs,
            positionMs: positionMs,
            tagIds: tagIds,
            transform: transform,
            speed: speed,
            muted: muted,
            volume: volume,
            brightness: brightness,
          ),
        ],
      ),
    ],
    tags: const [TagDefinition(id: 'tag-1', name: 'Travel', color: '#112233')],
    markers: const [],
    overlays: const [],
  );
}

ProjectDocument documentWithOneClip({
  int revision = 0,
  ProjectStateSnapshot? state,
  List<PersistedTransactionRecord> history = const [],
  int historyCursor = -1,
}) {
  return ProjectDocument(
    schemaVersion: 2,
    id: 'project-1',
    name: 'Fixture project',
    createdAt: fixtureTime,
    updatedAt: fixtureTime,
    outputDirectory: r'C:\exports',
    currentState: state ?? stateWithOneClip(),
    revision: revision,
    history: history,
    historyCursor: historyCursor,
  );
}

PersistedTransactionRecord recordFor({
  required ProjectStateSnapshot before,
  required ProjectStateSnapshot after,
  String planId = 'plan-1',
  TransactionSourceKind sourceKind = TransactionSourceKind.agent,
}) {
  return PersistedTransactionRecord(
    planId: planId,
    beforeState: before,
    afterState: after,
    commands: [
      CanonicalCommandSummary(
        type: 'set_clip_brightness',
        targetIds: ['clip-1'],
      ),
    ],
    appliedAt: fixtureTime,
    sourceKind: sourceKind,
  );
}

ProjectOverlay textOverlayFixture(String id) => ProjectOverlay.text(
  id: id,
  trackId: 'track-1',
  startMs: 0,
  endMs: 100,
  text: 'Title',
  x: 0.1,
  y: 0.1,
);
