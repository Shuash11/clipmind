import 'tool_definition.dart';

/// Curated tool surface for the agentic loop (D4, Phase 6a).
///
/// Exactly 17 tools (< 20 per OpenAI guidance). The model references clips
/// by ID learned from [list_project_clips]; the app resolves file paths
/// itself — file paths are never model-filled args.
class ToolRegistry {
  /// Max LLM round trips per agent run (D-bounds).
  static const int maxToolRounds = 4;

  /// Max FFmpeg jobs executed per agent run (D-bounds).
  static const int maxEditJobsPerRun = 20;

  /// Tool names must fit the OpenAI function-name charset (≤64 chars).
  static final RegExp validName = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');

  final Map<String, ToolDefinition> _byName;
  final Map<String, ToolExecutor> _executors;

  ToolRegistry({required Map<String, ToolExecutor> executors})
      : _executors = Map.unmodifiable(executors),
        _byName = Map.unmodifiable({
          for (final d in defaultDefinitions()) d.name: d,
        }) {
    _validate();
  }

  /// The 17 canonical definitions.
  static List<ToolDefinition> defaultDefinitions() => _catalog;

  List<ToolDefinition> definitions() => _byName.values.toList();

  ToolDefinition? definitionFor(String name) => _byName[name];

  ToolExecutor? executorFor(String name) => _executors[name];

  bool get hasAllExecutors =>
      _byName.keys.every(_executors.containsKey);

  void _validate() {
    final seen = <String>{};
    for (final def in _byName.values) {
      if (!validName.hasMatch(def.name)) {
        throw ArgumentError('Invalid tool name "${def.name}".');
      }
      if (!seen.add(def.name)) {
        throw ArgumentError('Duplicate tool name "${def.name}".');
      }
      _validateStrictSchema(def);
    }
  }

  static void _validateStrictSchema(ToolDefinition def) {
    final schema = def.inputSchema;
    if (schema['type'] != 'object') {
      throw ArgumentError('Tool "${def.name}": schema type must be object.');
    }
    final properties = schema['properties'];
    if (properties is! Map) {
      throw ArgumentError('Tool "${def.name}": schema needs properties.');
    }
    final required = schema['required'];
    if (required is! List ||
        !properties.keys.every(required.contains)) {
      throw ArgumentError(
        'Tool "${def.name}": strict mode requires every property in required.',
      );
    }
    if (schema['additionalProperties'] != false) {
      throw ArgumentError(
        'Tool "${def.name}": strict mode requires additionalProperties: false.',
      );
    }
  }

  static final List<ToolDefinition> _catalog = [
    // --- Read tools -------------------------------------------------------
    const ToolDefinition(
      name: 'list_project_clips',
      description:
          'List all clips in the project with their IDs, labels and time ranges. Call this first to learn clip IDs.',
      inputSchema: {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
        'additionalProperties': false,
      },
      category: ToolCategory.read,
    ),
    const ToolDefinition(
      name: 'probe_video',
      description:
          'Return real ffprobe metadata (duration, resolution, fps, codec, audio) for one clip ID.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
        },
        'required': ['clip_id'],
        'additionalProperties': false,
      },
      category: ToolCategory.read,
    ),
    const ToolDefinition(
      name: 'get_edit_history',
      description:
          'Return the edit operations already applied in this project.',
      inputSchema: {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
        'additionalProperties': false,
      },
      category: ToolCategory.read,
    ),
    const ToolDefinition(
      name: 'detect_scenes',
      description:
          'Detect scene-change boundaries in one clip and return their start '
          'timestamps in milliseconds. Results are cached per media file.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'threshold': {
            'type': ['number', 'null'],
            'description':
                'Scene sensitivity 0.0-1.0 (lower = more scenes). Default 0.3.',
          },
          'max_scenes': {
            'type': ['number', 'null'],
            'description': 'Cap on returned scenes. Default 50.',
          },
        },
        'required': ['clip_id', 'threshold', 'max_scenes'],
        'additionalProperties': false,
      },
      category: ToolCategory.read,
    ),
    const ToolDefinition(
      name: 'get_storyboard',
      description:
          'Summarise the project structure: clips with time ranges, cached '
          'scene timestamps, and edit-history count. Call detect_scenes '
          'first when scenes are missing.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': ['string', 'null'],
            'description':
                'Clip ID to summarise, or null for the whole project.',
          },
        },
        'required': ['clip_id'],
        'additionalProperties': false,
      },
      category: ToolCategory.read,
    ),
    const ToolDefinition(
      name: 'get_transcript',
      description:
          'Transcribe one clip\'s speech to text (optional tool: fails with '
          'setup instructions when the whisper.cpp binary/model is missing).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'max_chars': {
            'type': ['number', 'null'],
            'description':
                'Max transcript characters returned. Default 4000.',
          },
        },
        'required': ['clip_id', 'max_chars'],
        'additionalProperties': false,
      },
      category: ToolCategory.read,
    ),
    // --- Edit tools -------------------------------------------------------
    const ToolDefinition(
      name: 'trim_clip',
      description:
          'Keep only the portion of a clip between start and end timecodes (HH:MM:SS.mmm).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'start': {
            'type': 'string',
            'description': 'Start timecode HH:MM:SS.mmm.',
          },
          'end': {
            'type': 'string',
            'description': 'End timecode HH:MM:SS.mmm.',
          },
        },
        'required': ['clip_id', 'start', 'end'],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
    const ToolDefinition(
      name: 'cut_segment',
      description:
          'Remove the segment between two timecodes from the middle of a clip (HH:MM:SS.mmm).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'remove_start': {
            'type': 'string',
            'description': 'Removal start HH:MM:SS.mmm.',
          },
          'remove_end': {
            'type': 'string',
            'description': 'Removal end HH:MM:SS.mmm.',
          },
        },
        'required': ['clip_id', 'remove_start', 'remove_end'],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
    const ToolDefinition(
      name: 'merge_clips',
      description: 'Concatenate two or more clips together in order.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_ids': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Clip IDs in concat order.',
          },
        },
        'required': ['clip_ids'],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
    const ToolDefinition(
      name: 'change_speed',
      description:
          'Change playback speed. factor 2.0 is double speed, 0.5 is half speed.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'factor': {
            'type': 'number',
            'description': 'Speed multiplier, e.g. 2.0 or 0.5.',
          },
        },
        'required': ['clip_id', 'factor'],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
    const ToolDefinition(
      name: 'mute_clip',
      description: 'Remove all audio from a clip.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
        },
        'required': ['clip_id'],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
    const ToolDefinition(
      name: 'overlay_text',
      description: 'Overlay text on a clip.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'text': {'type': 'string', 'description': 'Text to display.'},
          'position': {
            'type': ['string', 'null'],
            'description':
                'center, top-left, top-right, bottom-left or bottom-right.',
          },
          'font_size': {
            'type': ['number', 'null'],
            'description': 'Font size in pixels.',
          },
          'color': {
            'type': ['string', 'null'],
            'description': 'Font color as #RRGGBB.',
          },
          'start': {
            'type': ['string', 'null'],
            'description': 'Show-from time in seconds.',
          },
          'end': {
            'type': ['string', 'null'],
            'description': 'Show-until time in seconds.',
          },
        },
        'required': [
          'clip_id',
          'text',
          'position',
          'font_size',
          'color',
          'start',
          'end',
        ],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
    const ToolDefinition(
      name: 'resize_clip',
      description: 'Change clip resolution.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'width': {'type': 'number', 'description': 'Target width.'},
          'height': {'type': 'number', 'description': 'Target height.'},
          'fit': {
            'type': ['string', 'null'],
            'description': 'fill, fit or stretch.',
          },
        },
        'required': ['clip_id', 'width', 'height', 'fit'],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
    const ToolDefinition(
      name: 'rotate_clip',
      description: 'Rotate a clip. Supported degrees: 90, 180, 270.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'degrees': {'type': 'number', 'description': '90, 180 or 270.'},
        },
        'required': ['clip_id', 'degrees'],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
    const ToolDefinition(
      name: 'adjust_brightness',
      description: 'Adjust brightness from -1.0 (darkest) to 1.0.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'value': {
            'type': 'number',
            'description': 'Brightness -1.0 to 1.0.',
          },
        },
        'required': ['clip_id', 'value'],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
    const ToolDefinition(
      name: 'change_volume',
      description: 'Change audio volume. 1.0 is original loudness.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'factor': {'type': 'number', 'description': 'Volume multiplier.'},
        },
        'required': ['clip_id', 'factor'],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
    const ToolDefinition(
      name: 'extract_audio',
      description: 'Extract the audio track of a clip to a file.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clip_id': {
            'type': 'string',
            'description': 'Clip ID from list_project_clips.',
          },
          'output_format': {
            'type': ['string', 'null'],
            'description': 'mp3, aac or wav.',
          },
        },
        'required': ['clip_id', 'output_format'],
        'additionalProperties': false,
      },
      category: ToolCategory.edit,
    ),
  ];
}
