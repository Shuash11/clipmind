import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:clipmind/data/local/secure_key_store.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/ollama_provider.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/stage_1_input_validation.dart';
import 'package:clipmind/domain/agent/tool_calling_agent.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';

class _MockDio extends Mock implements Dio {}

class _MockKeyStore extends Mock implements SecureKeyStore {}

class _OkExecutor implements ToolExecutor {
  @override
  Future<ToolResult> execute(ToolCall call) async => ToolResult.ok(
        data: {'output_path': '/out/${call.id}.mp4'},
        summary: 'ok',
      );
}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
    registerFallbackValue(Options());
  });

  test('Ollama provider runs the agentic loop end-to-end', () async {
    final dio = _MockDio();
    var calls = 0;
    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        // Round 1: assistant requests a trim tool call.
        return Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          statusCode: 200,
          data: {
            'choices': [
              {
                'finish_reason': 'tool_calls',
                'message': {
                  'role': 'assistant',
                  'content': null,
                  'tool_calls': [
                    {
                      'id': 'call_1',
                      'type': 'function',
                      'function': {
                        'name': 'trim_clip',
                        'arguments': jsonEncode({'clip_id': 'clip_1'}),
                      },
                    },
                  ],
                },
              },
            ],
          },
        );
      }
      // Round 2: final summary after the tool result round-trips.
      return Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/chat/completions'),
        statusCode: 200,
        data: {
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {
                'role': 'assistant',
                'content': 'Trimmed the first 5 seconds.',
              },
            },
          ],
        },
      );
    });

    final keys = _MockKeyStore();
    when(() => keys.readApiKey(any())).thenAnswer((_) async => null);
    final provider = OllamaProvider(
      config: const OllamaConfig(model: 'llama3.1'),
      keyStore: keys,
      dio: dio,
    );
    expect(provider.id.startsWith('ollama:'), isTrue);
    expect(provider.supportsToolCalling, isTrue);

    final (validated, _) = InputValidator.validate(
      'Trim the first 5 seconds then mute',
      null,
      projectClips: const [
        ClipSnapshot(
          id: 'clip_1',
          trackId: 't1',
          label: 'intro',
          startMs: 0,
          endMs: 60000,
          positionMs: 0,
        ),
      ],
    );
    final project = Project(
      id: 'p1',
      name: 'Test',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      sourceMediaPaths: const ['/v/input.mp4'],
      tracks: const [
        Track(
          id: 't1',
          type: TrackType.video,
          label: 'Video',
          clips: [
            Clip(
              id: 'clip_1',
              trackId: 't1',
              sourcePath: '/v/input.mp4',
              startMs: 0,
              endMs: 60000,
            ),
          ],
        ),
      ],
      durationMs: 60000,
      outputDir: '/out',
    );
    final agent = ToolCallingAgent(
      provider: provider,
      context: ToolExecutionContext(
        project: () => project,
        outputDir: '/out',
        projectDir: '/out',
        applier: AgentEditApplier(
            onApply: (_, _, {removeClipIds = const []}) async {}),
        ffmpegService: FfmpegService(),
        ffprobeService: FfprobeService(),
      ),
      registry: ToolRegistry(executors: {
        for (final d in ToolRegistry.defaultDefinitions())
          d.name: _OkExecutor(),
      }),
    );

    final result = await agent.run(validated: validated!);

    // Round 1 tool call executed, round 2 summarized: provider-agnostic.
    expect(calls, equals(2));
    expect(result.status, equals(AgentRunStatus.success));
    expect(result.message, equals('Trimmed the first 5 seconds.'));
    expect(result.records, hasLength(1));
    expect(result.records.single.success, isTrue);
    agent.dispose();
  });
}
