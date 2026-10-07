import 'package:clipmind/domain/agent/operation_schema.dart';

import 'tool_definition.dart';

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
  /// One-line hints for the deferred catalog tools. A name without a hint
  /// renders as a bare list entry, so catalog growth never breaks the
  /// prompt.
  static const Map<String, String> _deferredHints = {
    'resize_clip': 'change resolution (fill, fit or stretch).',
    'rotate_clip': 'rotate a clip 90, 180 or 270 degrees.',
    'extract_audio':
        "extract a clip's audio track to a file (mp3, aac or wav).",
    'burn_captions':
        'burn the cached transcript as timed captions — call get_transcript '
        'first. Use for "add captions/subtitles" commands; never invent '
        'subtitle files.',
    'add_transition':
        'merge two clips with a cross-fade (fade, dissolve, wipes, slides…) '
        'into one clip. Clips must share resolution and frame rate — '
        'resize_clip first if they differ.',
    'apply_effect':
        'apply creative looks: vignette, blur, grayscale, contrast or '
        'saturation. strength 0-1 drives vignette/blur; contrast/saturation '
        'are 0-3 multipliers (1.0 unchanged). For brightness use '
        'adjust_brightness.',
  };

  /// Builds the system prompt from the tools actually on offer: the
  /// AVAILABLE TOOLS block renders [available] from data (no hard-coded
  /// list) and DEFERRED TOOLS renders [deferredNames], so exposure changes
  /// never drift from the catalog.
  static String buildSystemPrompt({
    required List<ToolDefinition> available,
    required List<String> deferredNames,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are ClipMind, an AI video editing agent. You edit videos by '
      'calling tools.',
    );
    buffer.writeln();
    buffer.writeln('AVAILABLE TOOLS:');
    for (final def in available) {
      buffer.writeln('- ${def.name}: ${_oneLine(def.description)}');
    }
    buffer.writeln();
    buffer.writeln('DEFERRED TOOLS (call load_tools to unlock):');
    for (final name in deferredNames) {
      final hint = _deferredHints[name];
      buffer.writeln(hint == null ? '- $name' : '- $name: $hint');
    }
    buffer.write('''

RULES:
1. Always call list_project_clips first to learn the real clip IDs. Reference clips by ID only — never invent file paths.
2. All timecodes must be HH:MM:SS.mmm (e.g. 00:00:05.000).
3. Only batch independent calls; edits touching the same clip run sequentially.
4. When a tool reports an error it names the fix — self-correct and retry. If you cannot proceed, explain in plain text and ask for clarification instead of guessing.
5. Keep runs small: at most ~15 edits per request. When finished, summarise what was done in plain text.
6. For creative commands (highlight reels, summaries), call detect_scenes/get_storyboard first.
7. A capability missing from AVAILABLE TOOLS lives in DEFERRED TOOLS: call load_tools with its exact name(s) — loaded tools become available in the next round. Never invent tool names; only load names listed in DEFERRED TOOLS.
8. overlay_text font: pick a bundled font (Inter, Montserrat, Roboto, Lato, Source Code Pro, EB Garamond) — or omit for the system default.
''');
    return buffer.toString();
  }

  /// Collapses a definition description to one prompt line.
  static String _oneLine(String description) =>
      description.replaceAll(RegExp(r'\s+'), ' ').trim();

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
