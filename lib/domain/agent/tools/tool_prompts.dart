import 'package:clipmind/domain/agent/operation_schema.dart';

/// Shared writer for the PROJECT CONTEXT block.
///
/// Used by both the legacy [PromptConstructor] and the agentic
/// [ToolPromptBuilder] so the model always sees the same ground truth.
class ProjectContextWriter {
  static String write(ProjectSnapshot project) {
    final clipContext = StringBuffer();

    clipContext.writeln('PROJECT CONTEXT:');
    clipContext.writeln('  Duration: ${project.durationMs}ms');
    clipContext.writeln('  Resolution: ${project.width}x${project.height}');
    clipContext.writeln('  FPS: ${project.fps}');
    clipContext.writeln('  Codec: ${project.codec}');
    clipContext.writeln('  Has Audio: ${project.hasAudio}');
    clipContext.writeln('  Available clips: ${project.clips.length}');
    for (final clip in project.clips) {
      clipContext.writeln(
        '    - ${clip.id}: "${clip.label}" '
        '(track: ${clip.trackId}, '
        '${clip.startMs}ms - ${clip.endMs}ms)',
      );
    }
    return clipContext.toString();
  }
}

/// System + user prompt builder for the tool-calling loop.
class ToolPromptBuilder {
  static String buildSystemPrompt() {
    return '''
You are ClipMind, an AI video editing agent. You edit videos by calling tools.

READ TOOLS (ground truth first):
- list_project_clips: all clip IDs, labels and time ranges. Call this first.
- probe_video: real ffprobe metadata (duration, resolution, fps, codec, audio) for one clip ID.
- get_edit_history: edits already applied in this project.
- detect_scenes / get_storyboard / get_transcript: understand the video content (scene changes, narration) before creative edits. get_transcript returns timed segments — usable for caption timing and highlights.

EDIT TOOLS:
- trim_clip, cut_segment, merge_clips, change_speed, mute_clip,
  overlay_text, resize_clip, rotate_clip, adjust_brightness,
  change_volume, extract_audio.

RULES:
1. Always call list_project_clips first to learn the real clip IDs. Reference clips by ID only — never invent file paths.
2. All timecodes must be HH:MM:SS.mmm (e.g. 00:00:05.000).
3. Only batch independent calls; edits touching the same clip run sequentially.
4. When a tool reports an error it names the fix — self-correct and retry. If you cannot proceed, explain in plain text and ask for clarification instead of guessing.
5. Keep runs small: at most ~15 edits per request. When finished, summarise what was done in plain text.
6. For creative commands (highlight reels, summaries), call detect_scenes/get_storyboard first.
''';
  }

  static String buildUserContent(ValidatedCommand command) {
    final content = StringBuffer();
    content.writeln(command.text);
    content.writeln();
    content.writeln('---');
    content.writeln(ProjectContextWriter.write(command.projectSnapshot));

    if (command.normalizedTimecodes.isNotEmpty) {
      content.writeln();
      content.writeln('NORMALIZED TIMECODES:');
      for (final entry in command.normalizedTimecodes.entries) {
        content.writeln('  ${entry.key} = ${entry.value}ms');
      }
    }
    return content.toString();
  }
}
