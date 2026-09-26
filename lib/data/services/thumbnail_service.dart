import 'dart:io';
import 'ffmpeg/ffprobe_service.dart';

class ThumbnailService {
  final FfprobeService _ffprobeService;
  final Map<String, String> _cache = {};

  ThumbnailService(this._ffprobeService);

  Future<String?> generate(String videoPath, {int atMs = 0}) async {
    final cached = _cache[videoPath];
    if (cached != null && await File(cached).exists()) {
      return cached;
    }

    final thumbPath = '${videoPath}_thumb.jpg';
    final result = await _ffprobeService.generateThumbnail(
      videoPath,
      atMs: atMs,
      outputPath: thumbPath,
    );

    if (result != null) {
      _cache[videoPath] = result;
    }
    return result;
  }

  Future<bool> delete(String thumbnailPath) async {
    _cache.removeWhere((_, v) => v == thumbnailPath);
    try {
      final file = File(thumbnailPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String? getCached(String videoPath) => _cache[videoPath];

  void clearCache() {
    _cache.clear();
  }
}
