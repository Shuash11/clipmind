import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sizing policy for the editor workspace's vertical preview/timeline split.
///
/// Reference editors keep the timeline near 40% of the workspace height:
/// Premiere Pro's default Editing workspace docks the Timeline under the
/// Program Monitor and shares one draggable divider (Adobe, "Working with
/// the Timeline panel"); DaVinci Resolve expands its bottom timeline band by
/// dragging its top edge; CapCut Desktop keeps its track area in the bottom
/// ~40% of the window. ClipMind mirrors that share, with floors so neither
/// pane ever collapses into a sliver.
///
/// All values are logical pixels — Flutter's device-independent unit on
/// Windows (the platform scale factor is applied by the engine).
class WorkspaceSplitPolicy {
  const WorkspaceSplitPolicy({
    this.timelineFraction = 0.40,
    this.timelineMinHeight = 220,
    this.timelineMaxFraction = 0.45,
    this.timelineHardMinHeight = 120,
    this.previewMinHeight = 200,
    this.gap = 10,
  });

  /// The timeline's preferred share of the workspace height.
  final double timelineFraction;

  /// The timeline height the policy keeps whenever the workspace permits it.
  final double timelineMinHeight;

  /// The most the timeline may claim while the floors are reachable.
  final double timelineMaxFraction;

  /// Below this timeline height the floors are unreachable; the panes then
  /// degrade to the plain [timelineFraction] share instead of a sliver.
  final double timelineHardMinHeight;

  /// The preview height reserved whenever the workspace permits it.
  final double previewMinHeight;

  /// The visual gap between the preview and timeline panes.
  final double gap;

  /// The timeline pane's height for a workspace of [workspaceHeight].
  double timelineHeightFor(double workspaceHeight) {
    if (workspaceHeight <= 0) return 0;
    final usableHeight = math.max(0.0, workspaceHeight - gap);
    final preferredHeight = workspaceHeight * timelineFraction;

    // The largest height that keeps the preview's floor: the timeline may
    // claim no more than this, nor more than its share ceiling.
    final ceiling = math.max(
      0.0,
      math.min(
        workspaceHeight * timelineMaxFraction,
        usableHeight - previewMinHeight,
      ),
    );
    if (ceiling < timelineHardMinHeight) {
      // The workspace cannot host the floors (tiny window / extreme resize):
      // degrade proportionally so the timeline stays visible.
      return preferredHeight.clamp(0.0, usableHeight);
    }

    final floor = math.min(timelineMinHeight, ceiling);
    return preferredHeight.clamp(floor, ceiling);
  }

  /// The preview pane's height for a workspace of [workspaceHeight].
  double previewHeightFor(double workspaceHeight) =>
      math.max(0.0, workspaceHeight - gap - timelineHeightFor(workspaceHeight));
}

/// The editor workspace's vertical split: a preview pane above the timeline
/// pane, sized by [WorkspaceSplitPolicy] from the incoming constraints.
///
/// The sizing is a pure function of the available height, so pane sizes are
/// deterministic and testable; the host owns each pane's chrome.
class WorkspaceSplit extends StatelessWidget {
  const WorkspaceSplit({
    super.key,
    required this.preview,
    required this.timeline,
    this.policy = const WorkspaceSplitPolicy(),
  });

  final Widget preview;
  final Widget timeline;
  final WorkspaceSplitPolicy policy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          // Defensive fallback for unbounded hosts: keep the historical
          // 3:1 flex split rather than failing on an infinite height.
          return Column(
            children: [
              Expanded(flex: 3, child: preview),
              SizedBox(height: policy.gap),
              Expanded(flex: 1, child: timeline),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(
              height: policy.previewHeightFor(constraints.maxHeight),
              child: preview,
            ),
            SizedBox(height: policy.gap),
            SizedBox(
              height: policy.timelineHeightFor(constraints.maxHeight),
              child: timeline,
            ),
          ],
        );
      },
    );
  }
}
