import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:media_kit/media_kit.dart';

final currentVideoPathProvider = StateProvider<String?>((ref) => null);

final isPlayingProvider = StateProvider<bool>((ref) => false);

final playbackPositionProvider = StateProvider<Duration>(
  (ref) => Duration.zero,
);

final videoDurationProvider = StateProvider<Duration>((ref) => Duration.zero);

/// Single shared mpv-backed [Player] for the app (the real seek path).
///
/// Migration note (Track 3): the `Player` currently constructed inside
/// `PreviewPlayer` moves here — the preview player (and the manual
/// timeline playhead/trim/split UI) consumes it via
/// `ref.watch(playerProvider)`. The widget keeps owning its
/// `VideoController(player)` and the stream sync into
/// [playbackPositionProvider]/[videoDurationProvider]/[isPlayingProvider]
/// (that sync still lives in the preview player today); this provider
/// only owns the `Player` lifetime.
///
/// Seek path for the playhead: `ref.read(playerProvider).seek(position)`.
final playerProvider = Provider<Player>((ref) {
  final player = Player();
  ref.onDispose(player.dispose);
  return player;
});
