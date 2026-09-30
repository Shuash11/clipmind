import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class ClipBlock extends StatelessWidget {
  final Color color;
  final String label;
  final String durationLabel;
  final double width;
  final bool selected;
  final bool muted;
  final String? clipId;
  final VoidCallback? onTap;
  final int startMs;
  final int endMs;
  final double zoom;
  final void Function(String clipId, bool isStart, int newLocalMs)? onTrimEdge;

  const ClipBlock({
    super.key,
    required this.color,
    required this.label,
    required this.durationLabel,
    this.width = 120,
    this.selected = false,
    this.muted = false,
    this.clipId,
    this.onTap,
    this.startMs = 0,
    this.endMs = 0,
    this.zoom = 1.0,
    this.onTrimEdge,
  });

  @override
  Widget build(BuildContext context) {
    final block = _buildBlock(context);
    // Clips with an id are drag-reorderable (horizontal); standalone
    // blocks (no id) keep tap-only.
    if (clipId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Tooltip(message: '$label - $durationLabel', child: block),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Tooltip(
        message: '$label - $durationLabel',
        child: Draggable<String>(
          data: clipId,
          axis: Axis.horizontal,
          feedback: _buildGhost(),
          childWhenDragging: _buildDraggingPlaceholder(),
          child: _withTrimHandles(block),
        ),
      ),
    );
  }

  /// Trim handles: ~8px GestureDetector zones on the SELECTED block's
  /// left/right edges (grip bars, overlays — the block's footprint does
  /// not change). As the deepest hit-test members they win the gesture
  /// arena against the block's Draggable and the track's horizontal
  /// scroll, so an edge drag trims while the middle keeps reorder-drag
  /// and taps select. Absent when not selected. The zone width adapts
  /// down to half the block so the two zones never overlap on narrow
  /// (short-clip) blocks.
  Widget _withTrimHandles(Widget block) {
    if (!selected || onTrimEdge == null || clipId == null) return block;
    final handleWidth = math.max(1.0, math.min(8.0, width / 2));
    return Stack(
      children: [
        block,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: handleWidth,
          child: _TrimHandle(
            key: ValueKey('trim-start-$clipId'),
            clipId: clipId!,
            isStart: true,
            currentMs: startMs,
            zoom: zoom,
            onTrimEdge: onTrimEdge,
            onTap: onTap,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: handleWidth,
          child: _TrimHandle(
            key: ValueKey('trim-end-$clipId'),
            clipId: clipId!,
            isStart: false,
            currentMs: endMs,
            zoom: zoom,
            onTrimEdge: onTrimEdge,
            onTap: onTap,
          ),
        ),
      ],
    );
  }

  Widget _buildBlock(BuildContext context) {
    final textColor = muted
        ? ClipMindColors.textMuted
        : ClipMindColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: width,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.34 : 0.20),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? ClipMindColors.textPrimary
                  : color.withValues(alpha: 0.66),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: color.withValues(alpha: 0.20),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: _blockRow(textColor),
        ),
      ),
    );
  }

  Widget _blockRow(Color textColor) {
    // Tiered content: the label always renders (the tooltip carries the
    // label + duration on hover); the fixed gaps shrink and the duration
    // label hides on narrow blocks so short clips at low zoom never
    // overflow (a 1s clip is 12px at zoom 1.0). The tiers use the row's
    // available width (the block minus its 1px border on each side).
    final rowWidth = math.max(0.0, width - 2);
    if (rowWidth < 12) {
      return Row(
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    if (rowWidth < 64) {
      return Row(
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      );
    }
    // Wide blocks: the accent bar + the label + the duration.
    return Row(
      children: [
        Container(
          width: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(6),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          durationLabel,
          style: const TextStyle(
            color: ClipMindColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Drag ghost: the block visual at full strength with a lift shadow.
  Widget _buildGhost() {
    return Opacity(
      opacity: 0.9,
      child: Container(
        width: width,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ClipMindColors.textPrimary, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _blockRow(ClipMindColors.textPrimary),
      ),
    );
  }

  /// Dimmed placeholder where the block sat while dragging.
  Widget _buildDraggingPlaceholder() {
    return Container(
      width: width,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
    );
  }
}

/// One trim-handle edge zone: an 8px GestureDetector with grip bars that
/// accumulates the drag delta and commits the edge's new LOCAL source
/// time on release (one trim op per gesture; the controller's validation
/// clamps the values).
class _TrimHandle extends StatefulWidget {
  const _TrimHandle({
    super.key,
    required this.clipId,
    required this.isStart,
    required this.currentMs,
    required this.zoom,
    this.onTrimEdge,
    this.onTap,
  });

  final String clipId;
  final bool isStart;
  final int currentMs;
  final double zoom;
  final void Function(String clipId, bool isStart, int newLocalMs)? onTrimEdge;
  final VoidCallback? onTap;

  @override
  State<_TrimHandle> createState() => _TrimHandleState();
}

class _TrimHandleState extends State<_TrimHandle> {
  static const double _pxPerSecondBase = 12;

  double _dragPx = 0;
  double? _lastGlobalDx;
  bool _dragging = false;

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _dragging = true;
      _dragPx = 0;
      // With dragStartBehavior.down, globalPosition is the DOWN event's
      // position, so the delta accumulation below measures from the true
      // down point and captures the full drag movement even when
      // intermediate updates are skipped.
      _lastGlobalDx = details.globalPosition.dx;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final last = _lastGlobalDx;
    if (last == null) return;
    _dragPx += details.globalPosition.dx - last;
    _lastGlobalDx = details.globalPosition.dx;
  }

  void _onDragEnd(DragEndDetails details) {
    final px = _dragPx;
    setState(() {
      _dragging = false;
      _dragPx = 0;
    });
    _lastGlobalDx = null;
    if (px == 0) return;
    // The track's unclamped linear scale: 1 px = 1000/(12 * zoom) ms.
    final deltaMs = (px * 1000 / (_pxPerSecondBase * widget.zoom)).round();
    if (deltaMs == 0) return;
    widget.onTrimEdge?.call(
      widget.clipId,
      widget.isStart,
      widget.currentMs + deltaMs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // dragStartBehavior.down: the start's position is the DOWN event's
      // position and the first update carries the slop movement, so the
      // delta accumulation captures the FULL drag movement.
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      // An edge tap also selects (consistent with the block's middle).
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Center(child: _gripBars()),
      ),
    );
  }

  /// Grip bars: two thin vertical lines marking the trim affordance,
  /// brighter while the handle is being dragged.
  Widget _gripBars() {
    final barColor = ClipMindColors.textPrimary.withValues(
      alpha: _dragging ? 0.95 : 0.65,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 2, height: 14, color: barColor),
        const SizedBox(width: 3),
        Container(width: 2, height: 14, color: barColor),
      ],
    );
  }
}
