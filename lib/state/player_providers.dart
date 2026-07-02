import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentVideoPathProvider = StateProvider<String?>((ref) => null);

final isPlayingProvider = StateProvider<bool>((ref) => false);

final playbackPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

final videoDurationProvider = StateProvider<Duration>((ref) => Duration.zero);
