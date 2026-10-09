import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
import 'package:clipmind/state/player_providers.dart';
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
  static const double _minZoom = 0.5;
  static const double _maxZoom = 4.0;

  /// The tracks region's minimum viable row height: a 38px clip block plus
  /// its 5px vertical padding on each side.
  static const double _minTrackRowHeight = 48;

  /// The hairline between track rows.
  static const double _trackDividerHeight = 1;

  final _uuid = const Uuid();
  final _rulerKey = GlobalKey();
  double _zoom = 1.0;
  String? _selectedClipId;
  bool _isEditing = false;
  bool _rendered = false;

  // One shared scroll: all 4 track rows host their positions on this
  // controller; scrolling any row moves the others with it (synced below).
  final _trackScrollController = ScrollController();
  bool _syncingTrackScroll = false;
  double _lastSyncedOffset = 0;

  // The tracks region's vertical fallback: when the panel is too short for
  // every row at its minimum height, the four rows scroll as one column
  // (the toolbar and ruler above stay pinned outside that scroll area).
  final _tracksScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _trackScrollController.addListener(_syncTrackScrolls);
  }

  @override
  void dispose() {
    _trackScrollController
      ..removeListener(_syncTrackScrolls)
      ..dispose();
    _tracksScrollController.dispose();
    super.dispose();
  }

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
    setState(() => _zoom = (_zoom + delta).clamp(_minZoom, _maxZoom));
  }

  /// Ctrl+wheel zoom: a [Listener.onPointerSignal] handler on the canvas —
  /// wheel down zooms out, wheel up zooms in (the browser convention).
  /// Without Ctrl the wheel scrolls the track under the cursor as usual.
  void _onCanvasPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent &&
        HardwareKeyboard.instance.isControlPressed) {
      _changeZoom(event.scrollDelta.dy > 0 ? -0.25 : 0.25);
    }
  }

  /// The scrolled track row (the one off the last-synced offset) is the
  /// source of truth; the other rows jump to it. Re-entrant notifications
  /// from the jumps are gated by the flag.
  void _syncTrackScrolls() {
    if (_syncingTrackScroll) return;
    final positions =
        _trackScrollController.positions.toList(growable: false);
    if (positions.isEmpty) return;
    if (positions.length == 1) {
      _lastSyncedOffset = positions.first.pixels;
      return;
    }
    ScrollPosition? source;
    for (final position in positions) {
      if ((position.pixels - _lastSyncedOffset).abs() > 0.01) {
        source = position;
      }
    }
    if (source == null) {
      _lastSyncedOffset = positions.first.pixels;
      return;
    }
    _syncingTrackScroll = true;
    try {
      final target = source.pixels;
      for (final position in positions) {
        if (identical(position, source) || !position.hasContentDimensions) {
          continue;
        }
        if ((position.pixels - target).abs() <= 0.01) continue;
        position.jumpTo(math.min(target, position.maxScrollExtent));
      }
      _lastSyncedOffset = target;
    } finally {
      _syncingTrackScroll = false;
    }
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
        widget.project ?? ref.read(projectProvider).value;
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

  /// Trim-handle edge commit through the manual-edit controller: the
  /// dragged edge's new LOCAL source time; the other edge comes from the
  /// clip's current range. The controller's validation (in/out, the
  /// original-range outward limits) clamps the values — failures are
  /// actionable strings with zero side effects. Undoable + journaled.
  Future<void> _onTrimEdge(String clipId, bool isStart, int newLocalMs) async {
    if (_isEditing) return;
    final project = ref.read(projectProvider).value;
    final clip = resolveSelectedClip(project, clipId);
    if (clip == null) {
      _showTimelineMessage('Select a clip before trimming.');
      return;
    }
    final startMs = isStart ? newLocalMs : clip.startMs;
    final endMs = isStart ? clip.endMs : newLocalMs;
    setState(() => _isEditing = true);
    try {
      final result = await ref
          .read(manualEditControllerProvider)
          .submitTrim(clipId: clipId, startMs: startMs, endMs: endMs);
      if (mounted) _showTimelineMessage(result.message);
    } finally {
      if (mounted) setState(() => _isEditing = false);
    }
  }

  /// Split at the playhead through the manual-edit controller: the
  /// playhead's position maps linearly onto the ruler's fit-to-width
  /// space, so it passes straight through as the PROJECT time; the
  /// controller owns the clip lookup (the clip whose range contains the
  /// playhead time) and the source conversion. Undoable + journaled.
  Future<void> _splitAtPlayhead() async {
    if (_isEditing) return;
    final durationMs = _rulerRangeDurationMs();
    if (durationMs <= 0) {
      _showTimelineMessage('Import a video before splitting.');
      return;
    }
    final positionMs = ref.read(playbackPositionProvider).inMilliseconds;
    final atProjectMs = positionMs.clamp(0, durationMs);
    final clip = _clipAt(atProjectMs);
    if (clip == null) {
      _showTimelineMessage('Move the playhead over a clip before splitting.');
      return;
    }
    setState(() => _isEditing = true);
    try {
      final result = await ref
          .read(manualEditControllerProvider)
          .submitSplit(clipId: clip.id, atProjectMs: atProjectMs);
      if (mounted) _showTimelineMessage(result.message);
    } finally {
      if (mounted) setState(() => _isEditing = false);
    }
  }

  // Scrub state: the last update's area px + the throttle gate's last seek.
  double? _lastScrubPx;
  DateTime? _lastScrubSeek;

  void _onScrubStart(DragStartDetails details) {
    final px = _scrubAreaPx(details.globalPosition.dx);
    _lastScrubPx = px;
    _lastScrubSeek = null;
    // Grab: the playhead jumps to the grab point immediately.
    if (px != null) _seekToAreaPx(px);
  }

  void _onScrubUpdate(DragUpdateDetails details) {
    final px = _scrubAreaPx(details.globalPosition.dx);
    if (px == null) return;
    _lastScrubPx = px;
    // Throttle: at most one seek per ~80ms during the drag (mpv-backed
    // seeks are async); the final seek on release lands the exact spot.
    final now = DateTime.now();
    final last = _lastScrubSeek;
    if (last != null && now.difference(last).inMilliseconds < 80) return;
    _lastScrubSeek = now;
    _seekToAreaPx(px);
  }

  void _onScrubEnd(DragEndDetails details) {
    // Final seek: land exactly where the scrub released.
    final px = _lastScrubPx;
    _lastScrubPx = null;
    _lastScrubSeek = null;
    if (px != null) _seekToAreaPx(px);
  }

  /// The area-relative px for a global x (the ruler's fit-to-width space).
  double? _scrubAreaPx(double globalDx) {
    final box = _rulerBox;
    if (box == null) return null;
    final width = box.size.width;
    if (width <= 0) return null;
    return box.globalToLocal(Offset(globalDx, 0)).dx;
  }

  /// Seek the shared player to the area px's time (the ruler's linear
  /// x→time mapping), clamped to the ruler duration.
  void _seekToAreaPx(double areaPx) {
    final box = _rulerBox;
    if (box == null) return;
    final width = box.size.width;
    if (width <= 0) return;
    final durationMs = _rulerRangeDurationMs();
    if (durationMs <= 0) return;
    final targetMs =
        (areaPx / width * durationMs).round().clamp(0, durationMs);
    ref.read(playerProvider).seek(Duration(milliseconds: targetMs));
  }

  /// A ruler click also seeks: tap = no movement → the drag never starts
  /// → the tap fires naturally on the ruler's GestureDetector.
  void _onRulerTapUp(TapUpDetails details) {
    _seekToAreaPx(details.localPosition.dx);
  }

  Future<void> _deleteSelectedClip() async {
    final project = ref.read(projectProvider).value;
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
    final project = ref.read(projectProvider).value;
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
      // In-memory first: the timeline reflects the edit immediately. A failed
      // disk write is recorded in projectSaveFailureProvider and surfaced
      // without rolling the visible state back.
      ref.read(projectProvider.notifier).setProject(updatedProject);
      final saved = await ref.read(persistProjectProvider)(updatedProject);
      if (!mounted) return;
      _showTimelineMessage(
        saved ? message : 'Change applied, but it could not be saved to disk.',
      );
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
    final project = widget.project ?? ref.watch(projectProvider).value;
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
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.call_split, size: 16),
                  onPressed: _isEditing ? null : _splitAtPlayhead,
                  tooltip: 'Split at playhead',
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
                  onPressed: _zoom > _minZoom ? () => _changeZoom(-0.25) : null,
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
                  onPressed: _zoom < _maxZoom ? () => _changeZoom(0.25) : null,
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
          Expanded(
            child: Listener(
              onPointerSignal: _onCanvasPointerSignal,
              child: Column(
                children: [
                  if (rulerDuration != null) ...[
                    SizedBox(
                      height: 59, // 44 ruler + 1 divider + 14 seek strip
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final areaWidth = constraints.maxWidth > 93
                              ? constraints.maxWidth - 93
                              : 0.0;
                          return Stack(
                            children: [
                              Column(
                                children: [
                                  _buildRulerRow(
                                    rulerDuration,
                                    areaWidth,
                                    taggingDocument,
                                  ),
                                  const Divider(
                                    height: 1,
                                    color: ClipMindColors.borderColor,
                                  ),
                                  _buildSeekStrip(),
                                ],
                              ),
                              _playheadOverlay(rulerDuration, areaWidth),
                            ],
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1, color: ClipMindColors.borderColor),
                  ],
                  Expanded(child: _buildTracksRegion(project)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulerRow(
    int rulerDuration,
    double areaWidth,
    ProjectDocument? taggingDocument,
  ) {
    return SizedBox(
      height: 44,
      child: Row(
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
              // A ruler click also seeks: tap = no movement → the drag
              // never starts → the tap fires naturally.
              onTapUp: _onRulerTapUp,
              child: Stack(
                children: [
                  MarkerRuler(
                    durationMs: rulerDuration,
                    width: areaWidth,
                    document: taggingDocument,
                  ),
                  _rangeHighlight(rulerDuration),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The dedicated seek strip: its own GestureDetector (no gesture
  /// conflicts) — drag to scrub (throttled seeks via the player) and
  /// tap-to-seek, in the ruler's fit-to-width coordinate space.
  Widget _buildSeekStrip() {
    return SizedBox(
      height: 14,
      child: Row(
        // Stretch: the strip surface must fill the row's 14px height
        // (a childless ColoredBox has no intrinsic height).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 92),
          const SizedBox(
            width: 1,
            child: ColoredBox(color: ClipMindColors.borderColor),
          ),
          Expanded(
            child: GestureDetector(
              key: const ValueKey('timeline-seek-strip'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _onScrubStart,
              onHorizontalDragUpdate: _onScrubUpdate,
              onHorizontalDragEnd: _onScrubEnd,
              onTapUp: (details) => _seekToAreaPx(details.localPosition.dx),
              child: const ColoredBox(color: ClipMindColors.bgElevated),
            ),
          ),
        ],
      ),
    );
  }

  /// The playhead: a vertical accent line at the playback position across
  /// the ruler + the seek strip (one fit-to-width coordinate space; the
  /// player's position maps linearly), with a ~12px grabbable hit zone
  /// that drags to scrub.
  Widget _playheadOverlay(int rulerDuration, double areaWidth) {
    final positionMs = ref.watch(playbackPositionProvider).inMilliseconds;
    if (rulerDuration <= 0 || areaWidth <= 0) return const SizedBox.shrink();
    final clampedMs = positionMs.clamp(0, rulerDuration);
    final x = 93.0 + clampedMs / rulerDuration * areaWidth;
    final zoneLeft = math.max(93.0, x - 8);
    return Stack(
      children: [
        Positioned(
          left: x - 1,
          top: 0,
          bottom: 0,
          width: 2,
          child: const ColoredBox(color: ClipMindColors.accentPrimary),
        ),
        Positioned(
          left: zoneLeft,
          top: 0,
          bottom: 0,
          width: 16,
          child: GestureDetector(
            key: const ValueKey('timeline-playhead'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onScrubStart,
            onHorizontalDragUpdate: _onScrubUpdate,
            onHorizontalDragEnd: _onScrubEnd,
            onTapUp: (details) =>
                _seekToAreaPx(zoneLeft - 93.0 + details.localPosition.dx),
            child: const SizedBox.expand(),
          ),
        ),
      ],
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
      onTrimEdge: _onTrimEdge,
      scrollController: _trackScrollController,
    );
  }

  /// The four track rows below the ruler.
  ///
  /// While the region can host every row at its minimum usable height the
  /// rows share the space evenly (the historical fit behavior). When the
  /// region is shorter, the rows keep that minimum height and the region
  /// scrolls vertically: the Video row starts at the top and the toolbar +
  /// ruler above stay pinned, because they live outside this region.
  Widget _buildTracksRegion(Project? project) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minRegionHeight = 4 * _minTrackRowHeight + 3 * _trackDividerHeight;
        if (constraints.maxHeight >= minRegionHeight) {
          return _buildTrackColumn(project, fillHeight: true);
        }
        return Scrollbar(
          controller: _tracksScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            key: const ValueKey('timeline-tracks-scroll'),
            controller: _tracksScrollController,
            child: _buildTrackColumn(project, fillHeight: false),
          ),
        );
      },
    );
  }

  /// The Video/Audio/Text/FX rows with hairline dividers. In fit mode every
  /// row is an [Expanded] sharing the region; in scroll mode every row is
  /// fixed at [_minTrackRowHeight] and the column overflows the viewport.
  Widget _buildTrackColumn(Project? project, {required bool fillHeight}) {
    const trackTypes = [
      TrackTypeDisplay.video,
      TrackTypeDisplay.audio,
      TrackTypeDisplay.text,
      TrackTypeDisplay.fx,
    ];
    final children = <Widget>[];
    for (final type in trackTypes) {
      if (children.isNotEmpty) {
        children.add(
          const Divider(
            height: _trackDividerHeight,
            color: ClipMindColors.borderColor,
          ),
        );
      }
      final row = _buildTrack(type, project);
      children.add(
        fillHeight
            ? Expanded(child: row)
            : SizedBox(height: _minTrackRowHeight, child: row),
      );
    }
    return Column(children: children);
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
