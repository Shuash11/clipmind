import 'operation_schema.dart';

class PromptConstructor {
  static const String _operationList = '''
1. trim: { "id": "op_1", "type": "trim", "target_clip_id": "clip_1", "params": { "start": "00:00:05.000", "end": "00:00:15.000" } }
   Cuts a segment from the clip, keeping only the portion between start and end.
   Required params: start (string), end (string)

2. cut: { "id": "op_1", "type": "cut", "target_clip_id": "clip_1", "params": { "remove_start": "00:00:10.000", "remove_end": "00:00:20.000" } }
   Removes a segment from the middle of the clip.
   Required params: remove_start (string), remove_end (string)

3. merge: { "id": "op_1", "type": "merge", "target_clip_id": "clip_1", "params": { "clip_ids": ["clip_1", "clip_2"] } }
   Concatenates multiple clips together in order.
   Required params: clip_ids (array of strings)

4. change_speed: { "id": "op_1", "type": "change_speed", "target_clip_id": "clip_1", "params": { "factor": 2.0 } }
   Speeds up or slows down the clip. factor=2.0 is double speed, factor=0.5 is half speed.
   Required params: factor (number)

5. mute: { "id": "op_1", "type": "mute", "target_clip_id": "clip_1", "params": {} }
   Removes all audio from the clip.
   No required params.

6. overlay_text: { "id": "op_1", "type": "overlay_text", "target_clip_id": "clip_1", "params": { "text": "Hello World", "position": "center", "font_size": 48, "color": "#FFFFFF", "start": "5", "end": "15" } }
   Adds text overlay on the clip. position: center, top-left, top-right, bottom-left, bottom-right.
   Required params: text (string). Optional: position, font_size, color, start, end.

7. resize: { "id": "op_1", "type": "resize", "target_clip_id": "clip_1", "params": { "width": 1920, "height": 1080, "fit": "fill" } }
   Changes clip resolution. fit: fill (crop to fill), fit (letterbox), stretch.
   Required params: width (number), height (number). Optional: fit.

8. rotate: { "id": "op_1", "type": "rotate", "target_clip_id": "clip_1", "params": { "degrees": 90 } }
   Rotates the clip. Supported: 90, 180, 270.
   Required params: degrees (number).

9. extract_audio: { "id": "op_1", "type": "extract_audio", "target_clip_id": "clip_1", "params": { "output_format": "mp3" } }
   Extracts audio track to a separate file.
   Optional params: output_format (mp3, aac, wav).

10. generate_thumbnail: { "id": "op_1", "type": "generate_thumbnail", "target_clip_id": "clip_1", "params": { "timestamp": "00:00:10.000" } }
    Generates a thumbnail image at the given timestamp.
    Optional params: timestamp (string).

11. change_format: { "id": "op_1", "type": "change_format", "target_clip_id": "clip_1", "params": { "target_ext": "mp4", "codec_preset": "libx264" } }
    Re-encodes the clip to a different format/codec.
    Required params: target_ext (string). Optional: codec_preset.

12. adjust_brightness: { "id": "op_1", "type": "adjust_brightness", "target_clip_id": "clip_1", "params": { "value": 0.2 } }
    Adjusts brightness. Range -1.0 to 1.0 (-1 = darkest, 0 = normal, 1 = brightest).
    Required params: value (number).

13. change_volume: { "id": "op_1", "type": "change_volume", "target_clip_id": "clip_1", "params": { "factor": 0.5 } }
    Changes audio volume. factor=1.0 is original, factor=0.5 is half volume, factor=2.0 is double.
    Required params: factor (number).

14. overlay_watermark: { "id": "op_1", "type": "overlay_watermark", "target_clip_id": "clip_1", "params": { "image_path": "watermark.png", "position": "bottom-right", "opacity": 0.7 } }
    Overlays an image watermark on the clip.
    Required params: image_path (string). Optional: position, opacity.
''';

  static const String _systemHeader = '''
You are ClipMind, an AI video editing agent. You convert natural language commands into structured JSON operations for FFmpeg.

You MUST return a JSON object with this exact structure:
{
  "operations": [
    {
      "id": "op_N",
      "type": "operation_type",
      "target_clip_id": "clip_id",
      "params": { ... }
    }
  ],
  "summary": "Plain-language description of what was done",
  "clarification_needed": null
}

If the command is ambiguous or missing critical information, set "clarification_needed" to a question asking for the missing details, and leave operations as an empty array.

RULES:
1. Return ONLY the JSON object, no markdown fences, no explanation.
2. Use the exact operation names listed below.
3. Every operation must have a unique id.
4. target_clip_id must reference one of the available clips listed below.
5. All timecodes must be in HH:MM:SS.mmm format.
6. summary must be a brief plain-language description.
7. If you cannot parse the intent, set clarification_needed instead of guessing.
''';

  static const String _systemFooter = '''
AVAILABLE OPERATIONS:
$_operationList
CRITICAL: Your response must be valid JSON and NOTHING else. No code fences, no markdown, no explanation outside the JSON, no trailing whitespace after the closing brace.
''';

  static String buildSystemPrompt() {
    return '$_systemHeader\n$_systemFooter';
  }

  static AgentRequest build(
    ValidatedCommand command,
    String schemaJson, {
    List<AgentRequest>? recentHistory,
  }) {
    final project = command.projectSnapshot;
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

    if (command.normalizedTimecodes.isNotEmpty) {
      clipContext.writeln();
      clipContext.writeln('NORMALIZED TIMECODES:');
      for (final entry in command.normalizedTimecodes.entries) {
        clipContext.writeln('  ${entry.key} = ${entry.value}ms');
      }
    }

    final userCommand = StringBuffer();
    userCommand.writeln(command.text);
    userCommand.writeln();
    userCommand.writeln('---');
    userCommand.writeln(clipContext.toString());

    if (recentHistory != null && recentHistory.isNotEmpty) {
      userCommand.writeln('---');
      userCommand.writeln('RECENT CHAT HISTORY (for context):');
      for (final entry in recentHistory.take(3)) {
        userCommand.writeln('User: ${entry.userCommand}');
        final truncated = entry.systemPrompt.length > 100
            ? entry.systemPrompt.substring(0, 100)
            : entry.systemPrompt;
        userCommand.writeln('System summary: $truncated');
      }
    }

    return AgentRequest(
      systemPrompt: '$_systemHeader\n$_systemFooter\n\n$clipContext',
      userCommand: userCommand.toString(),
      schemaJson: schemaJson,
      timeoutSeconds: 30,
    );
  }
}
