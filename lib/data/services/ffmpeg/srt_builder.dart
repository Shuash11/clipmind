import 'package:clipmind/data/services/transcription/whisper_service.dart';

/// Pure SRT subtitle builder for `burn_captions`.
///
/// Renders cached [TranscriptSegment]s as SubRip text (comma
/// milliseconds, 1-based indices, input order preserved, empty-text
/// segments skipped). The executor writes the result to a temp `.srt`
/// file consumed by the FFmpeg `subtitles` filter — the model never
/// passes subtitle paths.
class SrtBuilder {
  /// Build full SRT content from timed segments.
  static String buildSrt(List<TranscriptSegment> segments) {
    final out = StringBuffer();
    var index = 0;
    for (final segment in segments) {
      if (segment.text.trim().isEmpty) continue;
      index++;
      out.writeln(index);
      out.writeln(
        '${formatTimestamp(segment.startMs)} --> '
        '${formatTimestamp(segment.endMs)}',
      );
      out.writeln(segment.text.trim());
      out.writeln();
    }
    return out.toString();
  }

  /// `ms` → `HH:MM:SS,mmm` (SRT comma format, distinct from whisper dots).
  static String formatTimestamp(int ms) {
    final clamped = ms < 0 ? 0 : ms;
    final hours = clamped ~/ 3600000;
    final minutes = (clamped % 3600000) ~/ 60000;
    final seconds = (clamped % 60000) ~/ 1000;
    final millis = clamped % 1000;
    String pad2(int v) => v.toString().padLeft(2, '0');
    return '${pad2(hours)}:${pad2(minutes)}:${pad2(seconds)},'
        '${millis.toString().padLeft(3, '0')}';
  }
}
