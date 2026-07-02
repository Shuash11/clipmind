import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'timeline_view.dart';

class TrackRow extends StatelessWidget {
  final TrackTypeDisplay trackType;
  const TrackRow({super.key, required this.trackType});

  Color get _trackColor {
    switch (trackType) {
      case TrackTypeDisplay.video: return ClipMindColors.trackVideo;
      case TrackTypeDisplay.audio: return ClipMindColors.trackAudio;
      case TrackTypeDisplay.text: return ClipMindColors.trackText;
      case TrackTypeDisplay.fx: return ClipMindColors.trackFx;
    }
  }

  String get _label {
    switch (trackType) {
      case TrackTypeDisplay.video: return 'Video';
      case TrackTypeDisplay.audio: return 'Audio';
      case TrackTypeDisplay.text: return 'Text';
      case TrackTypeDisplay.fx: return 'FX';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: ClipMindColors.bgSurface,
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.only(left: 8),
            alignment: Alignment.centerLeft,
            child: Text(_label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _trackColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            height: double.infinity,
            width: 1,
            color: ClipMindColors.borderColor,
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  ClipBlock(color: _trackColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClipBlock extends StatelessWidget {
  final Color color;
  const ClipBlock({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 32,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Center(
        child: Text('clip_01', style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w500,
        )),
      ),
    );
  }
}
