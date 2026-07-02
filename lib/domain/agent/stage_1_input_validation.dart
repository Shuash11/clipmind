import 'package:clipmind/core/utils/timecode_utils.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'operation_schema.dart';

class InputValidator {
  static const int maxPromptLength = 2000;

  static (ValidatedCommand?, Stage1Failure?) validate(
    String rawText,
    VideoMetadata? metadata, {
    List<ClipSnapshot> projectClips = const [],
  }) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return (null, const Stage1Failure('Command cannot be empty'));
    }
    if (trimmed.length > maxPromptLength) {
      return (
        null,
        Stage1Failure('Command exceeds ${maxPromptLength} characters'),
      );
    }

    final timecodes = <String, int>{};
    final words = trimmed.split(RegExp(r'\s+'));

    for (final word in words) {
      if (word.isEmpty) continue;
      final ms = TimecodeUtils.parseToMilliseconds(word);
      if (ms != null) {
        timecodes[word] = ms;
      }
    }

    final snapshot = ProjectSnapshot(
      durationMs: metadata?.durationMs ?? 0,
      width: metadata?.width ?? 0,
      height: metadata?.height ?? 0,
      fps: metadata?.fps ?? 30.0,
      codec: metadata?.codec ?? 'unknown',
      hasAudio: metadata?.hasAudio ?? false,
      clips: projectClips,
    );

    return (
      ValidatedCommand(
        text: trimmed,
        normalizedTimecodes: timecodes,
        projectSnapshot: snapshot,
      ),
      null,
    );
  }
}
