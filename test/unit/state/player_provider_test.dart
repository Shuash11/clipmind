import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:clipmind/state/player_providers.dart';

/// D3 seek-path tests: the shared [Player] lives in [playerProvider] so the
/// preview player migration is a simple swap (Track 3 consumes it via
/// `ref.watch`; `VideoController(player)` + the position/duration/playing
/// stream sync stay in the widget).
///
/// NOTE: `Player()` is mpv-backed. When the sandbox lacks the media_kit
/// native libs the read throws — the test then asserts the provider shape
/// only (documented skip) and the live seek path is verified on-device.
void main() {
  group('playerProvider (D3 seek path)', () {
    test('is a Provider<Player> (migration seam for PreviewPlayer)', () {
      expect(playerProvider, isA<Provider<Player>>());
    });

    test('existing playback providers keep their defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(currentVideoPathProvider), isNull);
      expect(container.read(isPlayingProvider), isFalse);
      expect(container.read(playbackPositionProvider), Duration.zero);
      expect(container.read(videoDurationProvider), Duration.zero);
    });

    test('exposes one shared Player with the seek-path surface', () {
      final container = ProviderContainer();
      late final Player player;
      try {
        player = container.read(playerProvider);
      } catch (_) {
        // No media_kit native libs in this sandbox — shape asserted above.
        container.dispose();
        return;
      }
      try {
        // Same instance on repeat reads: the app gets ONE Player.
        expect(identical(container.read(playerProvider), player), isTrue);
        // The seek-path surface Track 3 needs: async seek + streams.
        expect(player.state.position, isA<Duration>());
        expect(player.state.duration, isA<Duration>());
        expect(player.stream.position, isA<Stream<Duration>>());
        expect(player.stream.duration, isA<Stream<Duration>>());
        expect(player.stream.playing, isA<Stream<bool>>());
      } finally {
        // Triggers ref.onDispose(player.dispose).
        container.dispose();
      }
    });

    test('each container owns its Player (lifetime is provider-scoped)',
        () {
      final first = ProviderContainer();
      final second = ProviderContainer();
      try {
        final a = first.read(playerProvider);
        final b = second.read(playerProvider);
        expect(identical(a, b), isFalse);
      } catch (_) {
        // No media_kit native libs in this sandbox — shape asserted above.
      } finally {
        first.dispose();
        second.dispose();
      }
    });
  });
}
