import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'track_row.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ClipMindColors.bgBase,
        border: Border(top: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.content_cut, size: 14, color: ClipMindColors.textMuted),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cut - coming soon'), duration: Duration(seconds: 1)),
                  ),
                  tooltip: 'Cut',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 14, color: ClipMindColors.textMuted),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete - coming soon'), duration: Duration(seconds: 1)),
                  ),
                  tooltip: 'Delete',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.content_copy, size: 14, color: ClipMindColors.textMuted),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copy - coming soon'), duration: Duration(seconds: 1)),
                  ),
                  tooltip: 'Copy',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.zoom_in, size: 14, color: ClipMindColors.textMuted),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Zoom In - coming soon'), duration: Duration(seconds: 1)),
                  ),
                  tooltip: 'Zoom In',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.zoom_out, size: 14, color: ClipMindColors.textMuted),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Zoom Out - coming soon'), duration: Duration(seconds: 1)),
                  ),
                  tooltip: 'Zoom Out',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ClipMindColors.borderColor),
          const Expanded(child: TrackRow(trackType: TrackTypeDisplay.video)),
          const Divider(height: 1, color: ClipMindColors.borderColor),
          const Expanded(child: TrackRow(trackType: TrackTypeDisplay.audio)),
          const Divider(height: 1, color: ClipMindColors.borderColor),
          const Expanded(child: TrackRow(trackType: TrackTypeDisplay.text)),
          const Divider(height: 1, color: ClipMindColors.borderColor),
          const Expanded(child: TrackRow(trackType: TrackTypeDisplay.fx)),
        ],
      ),
    );
  }
}

enum TrackTypeDisplay { video, audio, text, fx }
