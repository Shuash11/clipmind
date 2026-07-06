import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/state/project_providers.dart';
import 'track_row.dart';

class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({super.key});

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  final _uuid = const Uuid();
  double _zoom = 1.0;
  String? _selectedClipId;
  bool _isEditing = false;

  void _showTimelineMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _changeZoom(double delta) {
    setState(() => _zoom = (_zoom + delta).clamp(0.5, 2.0));
  }

  Future<void> _cutSelectedClip() async {
    final project = ref.read(projectProvider).valueOrNull;
    final location = _selectedClipLocation(project);
    if (project == null || location == null) {
      _showTimelineMessage('Select a clip before cutting.');
      return;
    }

    final clip = location.clip;
    final duration = clip.endMs - clip.startMs;
    if (duration <= 1000) {
      _showTimelineMessage('Clip duration is unknown or too short to split.');
      return;
    }

    final midpoint = clip.startMs + (duration / 2).round();
    final first = clip.copyWith(endMs: midpoint);
    final second = clip.copyWith(
      id: _uuid.v4(),
      startMs: midpoint,
      positionMs: clip.positionMs + (duration / 2).round(),
      label: '${clip.label ?? _fileNameFromPath(clip.sourcePath)} split',
    );

    final updatedClips = List<Clip>.from(location.track.clips)
      ..removeAt(location.clipIndex)
      ..insertAll(location.clipIndex, [first, second]);
    await _replaceTrack(
      project,
      location.trackIndex,
      location.track.copyWith(clips: updatedClips),
      'Clip split.',
    );
  }

  Future<void> _deleteSelectedClip() async {
    final project = ref.read(projectProvider).valueOrNull;
    final location = _selectedClipLocation(project);
    if (project == null || location == null) {
      _showTimelineMessage('Select a clip before deleting.');
      return;
    }

    final updatedClips = List<Clip>.from(location.track.clips)
      ..removeAt(location.clipIndex);
    await _replaceTrack(
      project,
      location.trackIndex,
      location.track.copyWith(clips: updatedClips),
      'Clip deleted.',
    );
    if (mounted) setState(() => _selectedClipId = null);
  }

  Future<void> _copySelectedClip() async {
    final project = ref.read(projectProvider).valueOrNull;
    final location = _selectedClipLocation(project);
    if (project == null || location == null) {
      _showTimelineMessage('Select a clip before copying.');
      return;
    }

    final clip = location.clip;
    final duration = clip.endMs - clip.startMs;
    final displayDuration = duration > 0 ? duration : 30000;
    final copy = clip.copyWith(
      id: _uuid.v4(),
      positionMs: clip.positionMs + displayDuration,
      label: '${clip.label ?? _fileNameFromPath(clip.sourcePath)} copy',
    );

    final updatedClips = List<Clip>.from(location.track.clips)
      ..insert(location.clipIndex + 1, copy);
    await _replaceTrack(
      project,
      location.trackIndex,
      location.track.copyWith(clips: updatedClips),
      'Clip copied.',
    );
    if (mounted) setState(() => _selectedClipId = copy.id);
  }

  Future<void> _replaceTrack(
    Project project,
    int trackIndex,
    Track track,
    String message,
  ) async {
    final updatedTracks = List<Track>.from(project.tracks);
    updatedTracks[trackIndex] = track;
    final updatedProject = project.copyWith(
      tracks: updatedTracks,
      updatedAt: DateTime.now(),
    );

    setState(() => _isEditing = true);
    try {
      await ref.read(projectRepositoryProvider).save(updatedProject);
      if (!mounted) return;
      ref.read(projectProvider.notifier).setProject(updatedProject);
      _showTimelineMessage(message);
    } catch (_) {
      if (mounted) _showTimelineMessage('Timeline update failed. Try again.');
    } finally {
      if (mounted) setState(() => _isEditing = false);
    }
  }

  _ClipLocation? _selectedClipLocation(Project? project) {
    if (project == null || _selectedClipId == null) return null;
    for (var trackIndex = 0; trackIndex < project.tracks.length; trackIndex++) {
      final track = project.tracks[trackIndex];
      for (var clipIndex = 0; clipIndex < track.clips.length; clipIndex++) {
        final clip = track.clips[clipIndex];
        if (clip.id == _selectedClipId) {
          return _ClipLocation(
            trackIndex: trackIndex,
            clipIndex: clipIndex,
            track: track,
            clip: clip,
          );
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider).valueOrNull;
    final selectedClip = _selectedClipLocation(project)?.clip;

    return Container(
      decoration: const BoxDecoration(
        color: ClipMindColors.bgSurface,
        border: Border(top: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Text(
                  'Timeline',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                if (selectedClip != null)
                  Flexible(
                    child: Text(
                      selectedClip.label ??
                          _fileNameFromPath(selectedClip.sourcePath),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.content_cut, size: 16),
                  onPressed: _isEditing ? null : _cutSelectedClip,
                  tooltip: 'Cut selected clip',
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  onPressed: _isEditing ? null : _deleteSelectedClip,
                  tooltip: 'Delete selected clip',
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.content_copy, size: 16),
                  onPressed: _isEditing ? null : _copySelectedClip,
                  tooltip: 'Copy selected clip',
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 14),
                Text(
                  '${(_zoom * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.zoom_out, size: 16),
                  onPressed: _zoom > 0.5 ? () => _changeZoom(-0.25) : null,
                  tooltip: 'Zoom out',
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.zoom_in, size: 16),
                  onPressed: _zoom < 2.0 ? () => _changeZoom(0.25) : null,
                  tooltip: 'Zoom in',
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ClipMindColors.borderColor),
          Expanded(child: _buildTrack(TrackTypeDisplay.video, project)),
          const Divider(height: 1, color: ClipMindColors.borderColor),
          Expanded(child: _buildTrack(TrackTypeDisplay.audio, project)),
          const Divider(height: 1, color: ClipMindColors.borderColor),
          Expanded(child: _buildTrack(TrackTypeDisplay.text, project)),
          const Divider(height: 1, color: ClipMindColors.borderColor),
          Expanded(child: _buildTrack(TrackTypeDisplay.fx, project)),
        ],
      ),
    );
  }

  TrackRow _buildTrack(TrackTypeDisplay type, Project? project) {
    return TrackRow(
      trackType: type,
      clips: _clipsForType(project, type),
      zoom: _zoom,
      selectedClipId: _selectedClipId,
      onClipSelected: (id) => setState(() => _selectedClipId = id),
    );
  }

  List<Clip> _clipsForType(Project? project, TrackTypeDisplay type) {
    if (project == null) return const [];
    final modelType = _modelTypeForDisplay(type);
    return project.tracks
        .where((track) => track.type == modelType)
        .expand((track) => track.clips)
        .toList(growable: false);
  }

  TrackType _modelTypeForDisplay(TrackTypeDisplay type) {
    switch (type) {
      case TrackTypeDisplay.video:
        return TrackType.video;
      case TrackTypeDisplay.audio:
        return TrackType.audio;
      case TrackTypeDisplay.text:
        return TrackType.text;
      case TrackTypeDisplay.fx:
        return TrackType.fx;
    }
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last.trim();
    return name.isEmpty ? 'clip' : name;
  }
}

class _ClipLocation {
  final int trackIndex;
  final int clipIndex;
  final Track track;
  final Clip clip;

  const _ClipLocation({
    required this.trackIndex,
    required this.clipIndex,
    required this.track,
    required this.clip,
  });
}

enum TrackTypeDisplay { video, audio, text, fx }
