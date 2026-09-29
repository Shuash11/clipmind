import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:clipmind/features/tagging/presentation/widgets/marker_ruler.dart';
import 'package:clipmind/presentation/editor/providers/selected_clip_provider.dart';
import 'package:clipmind/state/manual_edit_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/structural_edit_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';
import 'track_row.dart';

final class TimelineClipRange {
  const TimelineClipRange({
    required this.clipId,
    required this.startMs,
    required this.endMs,
  });

  final String clipId;
  final int startMs;
  final int endMs;
}

/// The ruler drag-select range (timeline ruler times); null = none.
/// Drag again to re-select; cleared when a cut consumes it.
final timelineRangeProvider = StateProvider<TimelineClipRange?>((ref) => null);

class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({
    this.selectedRange,
    this.onRemoveRange,
    this.project,
    this.projectDocument,
    this.onRendered,
    super.key,
  });

  final TimelineClipRange? selectedRange;
  final Future<void> Function({
    required String clipId,
    required int startMs,
    required int endMs,
  })?
  onRemoveRange;
  final Project? project;
  final ProjectDocument? projectDocument;
  final VoidCallback? onRendered;

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  final _uuid = const Uuid();
  final _rulerKey = GlobalKey();
  double _zoom = 1.0;
  String? _selectedClipId;
  bool _isEditing = false;
  bool _rendered = false;

  @override
  void didUpdateWidget(covariant TimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.project, widget.project)) _rendered = false;
  }

  void _showTimelineMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  /// The clip selection's single write point: the local state drives the
  /// track highlight, and [selectedClipIdProvider] shares the selection
  /// with the CapCut-style left panel (effects/text/sound targets).
  void _selectClip(String? clipId) {
    setState(() => _selectedClipId = clipId);
    ref.read(selectedClipIdProvider.notifier).state = clipId;
  }

  void _changeZoom(double delta) {
    setState(() => _zoom = (_zoom + delta).clamp(0.5, 2.0));
  }

  /// The tested transaction-bridge remove-range flow (dev/test harnesses
  /// provide [onRemoveRange]; production wires the live range cut below).
  Future<void> _removeSelectedRange() async {
    if (_isEditing) return;
    final range = widget.selectedRange;
    final removeRange = widget.onRemoveRange;
    if (range == null || removeRange == null) {
      _showTimelineMessage('Select a range before removing.');
      return;
    }
    if (range.startMs < 0 || range.endMs <= range.startMs) {
      _showTimelineMessage('Select a valid range before removing.');
      return;
    }

    setState(() => _isEditing = true);
    try {
      await removeRange(
        clipId: range.clipId,
        startMs: range.startMs,
        endMs: range.endMs,
      );
      if (mounted) _showTimelineMessage('Range removed.');
    } catch (_) {
      if (mounted) _showTimelineMessage('Range removal failed. Try again.');
    } finally {
      if (mounted) setState(() => _isEditing = false);
    }
  }

  // Ruler drag-select (timeline ruler times); null = no selection.
  double? _rangeDragStartPx;
  double? _rangeDragCurrentPx;

  RenderBox? get _rulerBox =>
      _rulerKey.currentContext?.findRenderObject() as RenderBox?;

  void _onRangeDragStart(DragStartDetails details) {
    final box = _rulerBox;
    if (box == null) return;
    setState(() {
      _rangeDragStartPx = box.globalToLocal(details.globalPosition).dx;
      _rangeDragCurrentPx = _rangeDragStartPx;
    });
  }

  void _onRangeDragUpdate(DragUpdateDetails details) {
    final box = _rulerBox;
    if (box == null || _rangeDragStartPx == null) return;
    setState(() {
      _rangeDragCurrentPx = box.globalToLocal(details.globalPosition).dx;
    });
  }

  void _onRangeDragEnd(DragEndDetails details) {
    final box = _rulerBox;
    final startPx = _rangeDragStartPx;
    final currentPx = _rangeDragCurrentPx;
    _clearRangeDrag();
    if (box == null || startPx == null || currentPx == null) return;
    final width = box.size.width;
    if (width <= 0) return;
    final leftPx = math.min(startPx, currentPx);
    final rightPx = math.max(startPx, currentPx);
    // The ruler's x→time mapping is linear (no clamps).
    final durationMs = _rulerRangeDurationMs();
    final startMs = (leftPx / width * durationMs).round();
    final endMs = (rightPx / width * durationMs).round();
    if (endMs - startMs < 50) {
      // Too small to be a deliberate selection.
      ref.read(timelineRangeProvider.notifier).state = null;
      return;
    }
    ref.read(timelineRangeProvider.notifier).state = TimelineClipRange(
      clipId: _clipAt(startMs)?.id ?? '',
      startMs: startMs,
      endMs: endMs,
    );
  }

  void _clearRangeDrag() {
    setState(() {
      _rangeDragStartPx = null;
      _rangeDragCurrentPx = null;
    });
  }

  /// The clip whose span contains [timeMs] (timeline ruler times), or null.
  Clip? _clipAt(int timeMs) {
    final project =
        widget.project ?? ref.read(projectProvider).valueOrNull;
    if (project == null) return null;
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        final spanEnd = clip.positionMs + (clip.endMs - clip.startMs);
        if (timeMs >= clip.positionMs && timeMs < spanEnd) return clip;
      }
    }
    return null;
  }

  /// The ruler's duration for the range math (fresh read; 0 without one).
  int _rulerRangeDurationMs() {
    final document =
        widget.projectDocument ?? ref.read(taggingProvidersProvider)?.document;
    return _rulerDuration(document) ?? 0;
  }

  /// Live range cut through the manual-edit controller: raw ruler times —
  /// the controller owns clip lookup, span validation and conversion, so
  /// the cut is repointed, undoable and journaled like an agent edit.
  Future<void> _cutRange() async {
    if (_isEditing) return;
    final range = ref.read(timelineRangeProvider);
    if (range == null) {
      _showTimelineMessage('Drag a range on the ruler first.');
      return;
    }
    setState(() => _isEditing = true);
    try {
      final result = await ref
          .read(manualEditControllerProvider)
          .submitCut(
            clipId: range.clipId,
            startMs: range.startMs,
            endMs: range.endMs,
          );
      if (!mounted) return;
      if (result.success) {
        ref.read(timelineRangeProvider.notifier).state = null;
      }
      _showTimelineMessage(result.message);
    } finally {
      if (mounted) setState(() => _isEditing = false);
    }
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
    if (mounted) _selectClip(null);
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
    if (mounted) _selectClip(copy.id);
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

    // Memento order: snapshot the PRE-edit project first, then mutate —
    // manual delete/copy enter the undo stack (op-less) and stay persisted.
    ref.read(undoRedoProvider.notifier).pushStructural(project);
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
    final project = widget.project ?? ref.watch(projectProvider).valueOrNull;
    final selectedClip = _selectedClipLocation(project)?.clip;
    final taggingDocument =
        widget.projectDocument ?? ref.watch(taggingProvidersProvider)?.document;
    final rulerDuration = _rulerDuration(taggingDocument);
    _scheduleRendered(project);
    final range = ref.watch(timelineRangeProvider);

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
                // The cut button: the transaction-bridge remove-range flow
                // when [onRemoveRange] is provided (test harnesses); the
                // live range cut through the manual-edit controller in
                // production, enabled when a ruler range is selected.
                IconButton(
                  key: const ValueKey('timeline-cut-range'),
                  icon: const Icon(Icons.content_cut, size: 16),
                  onPressed: _isEditing
                      ? null
                      : (widget.onRemoveRange != null
                          ? _removeSelectedRange
                          : (range != null ? _cutRange : null)),
                  tooltip: 'Remove selected range',
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
          if (rulerDuration != null) ...[
            SizedBox(
              height: 44,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final rulerWidth = constraints.maxWidth > 93
                      ? constraints.maxWidth - 93
                      : 0.0;
                  return Row(
                    children: [
                      const SizedBox(width: 92),
                      const SizedBox(
                        width: 1,
                        height: double.infinity,
                        child: ColoredBox(color: ClipMindColors.borderColor),
                      ),
                      Expanded(
                        child: GestureDetector(
                          key: _rulerKey,
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _onRangeDragStart,
                          onHorizontalDragUpdate: _onRangeDragUpdate,
                          onHorizontalDragEnd: _onRangeDragEnd,
                          child: Stack(
                            children: [
                              MarkerRuler(
                                durationMs: rulerDuration,
                                width: rulerWidth,
                                document: taggingDocument,
                              ),
                              _rangeHighlight(rulerDuration),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1, color: ClipMindColors.borderColor),
          ],
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
      onClipSelected: _selectClip,
      onMoveClip: _moveClip,
    );
  }

  /// Drag-reorder through the structural applier (a `moveClip` op with
  /// `after_clip_id`; front = null/empty) — the op-less undo entry, DB
  /// journal and file persist all flow through the expose-point. A
  /// cross-track drop is a graceful no-op (the applier returns false).
  Future<void> _moveClip(String clipId, String? afterClipId) async {
    if (_isEditing) return;
    final applied = await ref
        .read(structuralEditApplierProvider)
        .apply(
          EditOperation(
            id: _uuid.v4(),
            type: EditOperationType.moveClip,
            targetClipIds: [clipId],
            params: {
              'clip_id': clipId,
              if (afterClipId != null && afterClipId.isNotEmpty)
                'after_clip_id': afterClipId,
            },
            createdAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    if (applied) {
      _showTimelineMessage('Clip moved.');
    }
  }

  /// Highlight overlay: the live drag selection while dragging, then the
  /// committed range from [timelineRangeProvider] until re-selected.
  Widget _rangeHighlight(int rulerDuration) {
    if (_rangeDragStartPx != null && _rangeDragCurrentPx != null) {
      final left = math.min(_rangeDragStartPx!, _rangeDragCurrentPx!);
      final width = math.max(_rangeDragStartPx!, _rangeDragCurrentPx!) - left;
      return Positioned(
        left: left,
        width: width,
        top: 0,
        bottom: 0,
        child: Container(
          color: ClipMindColors.accentPrimary.withValues(alpha: 0.25),
        ),
      );
    }
    final range = ref.watch(timelineRangeProvider);
    if (range == null || rulerDuration <= 0) return const SizedBox.shrink();
    final width = _rulerBox?.size.width ?? 0;
    if (width <= 0) return const SizedBox.shrink();
    final left = range.startMs / rulerDuration * width;
    final highlightWidth =
        (range.endMs - range.startMs) / rulerDuration * width;
    return Positioned(
      left: left,
      width: highlightWidth,
      top: 0,
      bottom: 0,
      child: Container(
        color: ClipMindColors.accentPrimary.withValues(alpha: 0.25),
      ),
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

  void _scheduleRendered(Project? project) {
    if (_rendered ||
        project == null ||
        !project.tracks.any((track) => track.clips.isNotEmpty)) {
      return;
    }
    _rendered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRendered?.call();
    });
  }

  int? _rulerDuration(ProjectDocument? document) {
    if (document == null) return null;
    final state = document.currentState;
    final hasTimelineContent =
        state.assets.isNotEmpty ||
        state.tracks.any((track) => track.clips.isNotEmpty) ||
        state.markers.isNotEmpty;
    if (!hasTimelineContent) return null;
    final values = <int>[
      for (final asset in state.assets)
        if (asset.durationMs > 0) asset.durationMs,
      for (final track in state.tracks)
        for (final clip in track.clips) ...[
          if (clip.endMs > 0) clip.endMs,
          if (clip.endMs > clip.startMs)
            clip.positionMs + (clip.endMs - clip.startMs),
        ],
      for (final marker in state.markers) ...[
        if (marker.atMs != null && marker.atMs! > 0) marker.atMs!,
        if (marker.endMs != null && marker.endMs! > 0) marker.endMs!,
      ],
    ];
    var duration = 1;
    for (final value in values) {
      if (value > duration) duration = value;
    }
    return duration;
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
