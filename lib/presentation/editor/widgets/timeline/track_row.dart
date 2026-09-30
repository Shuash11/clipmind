import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/clip_block.dart';
import 'timeline_view.dart';

class TrackRow extends StatefulWidget {
  final TrackTypeDisplay trackType;
  final List<Clip> clips;
  final double zoom;
  final String? selectedClipId;
  final ValueChanged<String>? onClipSelected;
  final void Function(String clipId, String? afterClipId)? onMoveClip;
  final void Function(String clipId, bool isStart, int newLocalMs)? onTrimEdge;

  /// Optional shared scroll controller: when provided, the row hosts its
  /// scroll position on it (the timeline syncs all 4 tracks through one
  /// controller); null = the row's own controller — behavior-preserving
  /// for standalone usage and tests.
  final ScrollController? scrollController;

  const TrackRow({
    super.key,
    required this.trackType,
    this.clips = const [],
    this.zoom = 1.0,
    this.selectedClipId,
    this.onClipSelected,
    this.onMoveClip,
    this.onTrimEdge,
    this.scrollController,
  });

  @override
  State<TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<TrackRow> {
  // The row's own scroll controller, used when no shared controller is
  // provided (standalone usage and tests).
  final _ownScrollController = ScrollController();

  ScrollController get _scrollController =>
      widget.scrollController ?? _ownScrollController;

  @override
  void dispose() {
    // Only the row's own controller is disposed; a shared controller is
    // owned by the timeline.
    if (widget.scrollController == null) _ownScrollController.dispose();
    super.dispose();
  }

  Color get _trackColor {
    switch (widget.trackType) {
      case TrackTypeDisplay.video:
        return ClipMindColors.trackVideo;
      case TrackTypeDisplay.audio:
        return ClipMindColors.trackAudio;
      case TrackTypeDisplay.text:
        return ClipMindColors.trackText;
      case TrackTypeDisplay.fx:
        return ClipMindColors.trackFx;
    }
  }

  IconData get _icon {
    switch (widget.trackType) {
      case TrackTypeDisplay.video:
        return Icons.movie_outlined;
      case TrackTypeDisplay.audio:
        return Icons.graphic_eq_rounded;
      case TrackTypeDisplay.text:
        return Icons.title_rounded;
      case TrackTypeDisplay.fx:
        return Icons.auto_fix_high_outlined;
    }
  }

  String get _label {
    switch (widget.trackType) {
      case TrackTypeDisplay.video:
        return 'Video';
      case TrackTypeDisplay.audio:
        return 'Audio';
      case TrackTypeDisplay.text:
        return 'Text';
      case TrackTypeDisplay.fx:
        return 'FX';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clips = widget.clips;
    return Container(
      color: ClipMindColors.bgSurface,
      child: Row(
        children: [
          Container(
            width: 92,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(_icon, size: 15, color: _trackColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _trackColor,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: double.infinity,
            width: 1,
            color: ClipMindColors.borderColor,
          ),
          Expanded(
            child: clips.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('No clips', style: theme.textTheme.bodySmall),
                    ),
                  )
                : DragTarget<String>(
                    onAcceptWithDetails: widget.onMoveClip == null
                        ? null
                        : (details) {
                            final box =
                                context.findRenderObject() as RenderBox;
                            final localX =
                                box.globalToLocal(details.offset).dx;
                            widget.onMoveClip!(
                              details.data,
                              _afterClipIdFor(localX),
                            );
                          },
                    builder: (context, candidateData, rejectedData) {
                      return Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: false,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(children: _buildClipWidgets()),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildClipWidgets() {
    final sorted = _sorted;
    final widgets = <Widget>[const SizedBox(width: 16)];
    var cursorMs = 0;

    for (final clip in sorted) {
      final gapMs = math.max(0, clip.positionMs - cursorMs);
      if (gapMs > 0) widgets.add(SizedBox(width: _gapWidth(gapMs)));

      final durationMs = _clipDurationMs(clip);
      widgets.add(
        ClipBlock(
          color: _trackColor,
          label: clip.label?.trim().isNotEmpty == true
              ? clip.label!.trim()
              : _fileNameFromPath(clip.sourcePath),
          durationLabel: _durationLabel(clip),
          width: _clipWidth(durationMs),
          muted: clip.muted,
          selected: widget.selectedClipId == clip.id,
          clipId: clip.id,
          onTap: () => widget.onClipSelected?.call(clip.id),
          startMs: clip.startMs,
          endMs: clip.endMs,
          zoom: widget.zoom,
          onTrimEdge: widget.onTrimEdge,
        ),
      );
      cursorMs = math.max(cursorMs, clip.positionMs + durationMs);
    }

    widgets.add(const SizedBox(width: 24));
    return widgets;
  }

  List<Clip> get _sorted {
    final sorted = [...widget.clips]
      ..sort((a, b) => a.positionMs.compareTo(b.positionMs));
    return sorted;
  }

  /// Pure insert-index math for a drag-reorder: the drop's local x within
  /// the track's clip area -> the clip id to anchor after (null = track
  /// front). Reuses the same cursor/width math as the block layout (the
  /// exact unclamped linear scale), splitting each block at its midpoint.
  String? _afterClipIdFor(double localX) {
    final sorted = _sorted;
    if (sorted.isEmpty) return null;

    var cursorMs = 0;
    var cursorPx = 16.0; // the leading SizedBox(16)
    String? previousId;

    for (final clip in sorted) {
      final gapMs = math.max(0, clip.positionMs - cursorMs);
      if (gapMs > 0) cursorPx += _gapWidth(gapMs);
      final width = _clipWidth(_clipDurationMs(clip));
      if (localX <= cursorPx + width / 2) {
        // Left half: insert before this clip (front when it is the first).
        return previousId;
      }
      if (localX <= cursorPx + width) {
        // Right half: insert after this clip.
        return clip.id;
      }
      cursorPx += width;
      cursorMs = math.max(cursorMs, clip.positionMs + _clipDurationMs(clip));
      previousId = clip.id;
    }
    return previousId; // beyond the last block
  }

  int _clipDurationMs(Clip clip) {
    final duration = clip.endMs - clip.startMs;
    return duration > 0 ? duration : 30000;
  }

  /// The exact linear scale (no clamps): 1 second = 12 * zoom px, so the
  /// block layout, the drop math and the trim handles' px→ms share one
  /// unclamped mapping.
  double _clipWidth(int durationMs) {
    return (durationMs / 1000) * 12 * widget.zoom;
  }

  double _gapWidth(int durationMs) {
    return (durationMs / 1000) * 12 * widget.zoom;
  }

  String _durationLabel(Clip clip) {
    final duration = clip.endMs - clip.startMs;
    if (duration <= 0) return 'unknown';
    final d = Duration(milliseconds: duration);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last.trim();
    return name.isEmpty ? 'clip' : name;
  }
}
