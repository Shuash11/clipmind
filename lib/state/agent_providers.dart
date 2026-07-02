import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/data/models/chat_message.dart';

final ffmpegServiceProvider = Provider<FfmpegService>((ref) {
  return FfmpegService();
});

final ffprobeServiceProvider = Provider<FfprobeService>((ref) {
  return FfprobeService();
});

final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  return ProviderRegistry();
});

final nl2vecPipelineProvider = Provider<Nl2VecPipeline>((ref) {
  final ffmpeg = ref.watch(ffmpegServiceProvider);
  final ffprobe = ref.watch(ffprobeServiceProvider);
  return Nl2VecPipeline(ffmpegService: ffmpeg, ffprobeService: ffprobe);
});

final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier();
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier() : super([]);

  void add(ChatMessage message) {
    state = [...state, message];
  }

  void clear() {
    state = [];
  }
}
