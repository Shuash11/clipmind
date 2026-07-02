import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'track_row.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ClipMindColors.bgBase,
        border: Border(top: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.content_cut, size: 14, color: ClipMindColors.textMuted),
                const SizedBox(width: 8),
                Icon(Icons.delete_outline, size: 14, color: ClipMindColors.textMuted),
                const SizedBox(width: 8),
                Icon(Icons.content_copy, size: 14, color: ClipMindColors.textMuted),
                const Spacer(),
                Icon(Icons.zoom_in, size: 14, color: ClipMindColors.textMuted),
                const SizedBox(width: 4),
                Icon(Icons.zoom_out, size: 14, color: ClipMindColors.textMuted),
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
