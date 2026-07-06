import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/clip_block.dart';
import 'timeline_view.dart';

class TrackRow extends StatelessWidget {
  final TrackTypeDisplay trackType;
  final List<Clip> clips;
  final double zoom;
  final String? selectedClipId;
  final ValueChanged<String>? onClipSelected;

  const TrackRow({
    super.key,
    required this.trackType,
    this.clips = const [],
    this.zoom = 1.0,
    this.selectedClipId,
    this.onClipSelected,
  });

  Color get _trackColor {
    switch (trackType) {
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
    switch (trackType) {
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
    switch (trackType) {
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
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _buildClipWidgets()),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildClipWidgets() {
    final sorted = [...clips]
      ..sort((a, b) => a.positionMs.compareTo(b.positionMs));
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
          selected: selectedClipId == clip.id,
          onTap: () => onClipSelected?.call(clip.id),
        ),
      );
      cursorMs = math.max(cursorMs, clip.positionMs + durationMs);
    }

    widgets.add(const SizedBox(width: 24));
    return widgets;
  }

  int _clipDurationMs(Clip clip) {
    final duration = clip.endMs - clip.startMs;
    return duration > 0 ? duration : 30000;
  }

  double _clipWidth(int durationMs) {
    final raw = (durationMs / 1000) * 12 * zoom;
    return raw.clamp(96, 720).toDouble();
  }

  double _gapWidth(int durationMs) {
    final raw = (durationMs / 1000) * 12 * zoom;
    return raw.clamp(10, 360).toDouble();
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
