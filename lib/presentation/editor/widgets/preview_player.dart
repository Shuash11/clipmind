import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/state/player_providers.dart';

class PreviewPlayer extends ConsumerStatefulWidget {
  const PreviewPlayer({super.key});

  @override
  ConsumerState<PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends ConsumerState<PreviewPlayer> {
  final Player _player = Player();
  late final VideoController _controller;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  @override
  void initState() {
    super.initState();
    _controller = VideoController(_player);
    _listenToPlayer();
  }

  void _listenToPlayer() {
    _positionSub = _player.stream.position.listen((pos) {
      if (mounted) ref.read(playbackPositionProvider.notifier).state = pos;
    });
    _durationSub = _player.stream.duration.listen((dur) {
      if (mounted) ref.read(videoDurationProvider.notifier).state = dur;
    });
    _playingSub = _player.stream.playing.listen((playing) {
      if (mounted) ref.read(isPlayingProvider.notifier).state = playing;
    });
  }

  String? _lastPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final videoPath = ref.read(currentVideoPathProvider);
    if (videoPath != null && videoPath != _lastPath) {
      _lastPath = videoPath;
      _player.open(Media(videoPath));
      _player.play();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_player.state.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _skip(int ms) {
    final current = _player.state.position;
    final target = current + Duration(milliseconds: ms);
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(
        0,
        _player.state.duration.inMilliseconds,
      ),
    );
    _player.seek(clamped);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final videoPath = ref.watch(currentVideoPathProvider);
    final theme = Theme.of(context);

    if (videoPath == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ClipMindColors.bgSurface.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 48,
                  color: ClipMindColors.accentPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Drop a video or click to import',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: ClipMindColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isPlaying = ref.watch(isPlayingProvider);
    final position = ref.watch(playbackPositionProvider);
    final duration = ref.watch(videoDurationProvider);

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Video(controller: _controller, fill: Colors.transparent),
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: isPlaying
                          ? const SizedBox.shrink()
                          : Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 48,
                                color: ClipMindColors.accentPrimary,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 48,
            color: ClipMindColors.bgSurface,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, size: 20),
                  color: ClipMindColors.textPrimary,
                  onPressed: () => _skip(-10000),
                  tooltip: 'Back 10s',
                ),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 24,
                  ),
                  color: ClipMindColors.accentPrimary,
                  onPressed: _togglePlayPause,
                  tooltip: isPlaying ? 'Pause' : 'Play',
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, size: 20),
                  color: ClipMindColors.textPrimary,
                  onPressed: () => _skip(10000),
                  tooltip: 'Forward 10s',
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(position),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ClipMindColors.textSecondary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SliderTheme(
                      data: const SliderThemeData(
                        trackHeight: 4,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: ClipMindColors.accentPrimary,
                        inactiveTrackColor: ClipMindColors.borderColor,
                        thumbColor: ClipMindColors.accentPrimary,
                      ),
                      child: Slider(
                        value: duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0.0,
                        onChanged: (value) {
                          final target = Duration(
                            milliseconds: (value * duration.inMilliseconds)
                                .round(),
                          );
                          _player.seek(target);
                        },
                      ),
                    ),
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ClipMindColors.textSecondary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
