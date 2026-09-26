import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';

final ffmpegServiceProvider = Provider<FfmpegService>((ref) {
  return FfmpegService();
});

final ffprobeServiceProvider = Provider<FfprobeService>((ref) {
  return FfprobeService();
});

final activeJobsProvider =
    StateNotifierProvider<ActiveJobsNotifier, List<FfmpegJob>>((ref) {
      return ActiveJobsNotifier();
    });

class ActiveJobsNotifier extends StateNotifier<List<FfmpegJob>> {
  ActiveJobsNotifier() : super([]);

  void add(FfmpegJob job) {
    state = [...state, job];
  }

  void remove(String jobId) {
    state = state.where((j) => j.id != jobId).toList();
  }

  void clear() {
    state = [];
  }
}
