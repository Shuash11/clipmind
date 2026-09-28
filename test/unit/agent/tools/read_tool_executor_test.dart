import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';

class _MockFfprobe extends Mock implements FfprobeService {}

Project _project() {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: [r'C:\v\input.mp4'],
    tracks: const [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip_1',
            trackId: 't1',
            sourcePath: r'C:\v\input.mp4',
            startMs: 0,
            endMs: 60000,
            label: 'intro',
          ),
          Clip(
            id: 'clip_2',
            trackId: 't1',
            sourcePath: r'C:\v\second.mp4',
            startMs: 0,
            endMs: 30000,
          ),
        ],
      ),
    ],
    durationMs: 90000,
    outputDir: r'C:\out',
    editHistory: [
      EditOperation(
        id: 'op_old',
        type: EditOperationType.trim,
        targetClipIds: const ['clip_1'],
        createdAt: DateTime(2026, 1, 2),
      ),
    ],
  );
}

ToolExecutionContext _ctx(Project project, FfprobeService ffprobe) {
  return ToolExecutionContext(
    project: () => project,
    outputDir: r'C:\out',
    projectDir: r'C:\out',
    applier: AgentEditApplier(
        onApply: (_, _, {removeClipIds = const []}) async {}),
    ffmpegService: FfmpegService(),
    ffprobeService: ffprobe,
  );
}

void main() {
  group('ReadToolExecutor', () {
    test('list_project_clips reflects the context project', () async {
      final executor = ReadToolExecutor(_ctx(_project(), _MockFfprobe()));
      final result = await executor.execute(
        const ToolCall(id: 'c1', name: 'list_project_clips'),
      );

      expect(result.success, isTrue);
      final clips = result.data['clips'] as List;
      expect(clips, hasLength(2));
      expect(clips.first['id'], equals('clip_1'));
      expect(clips.first['label'], equals('intro'));
      expect(result.data['count'], equals(2));
    });

    test('probe_video returns ffprobe metadata', () async {
      final ffprobe = _MockFfprobe();
      when(() => ffprobe.extractMetadata(any())).thenAnswer(
        (_) async => const VideoMetadata(
          durationMs: 60000,
          width: 1920,
          height: 1080,
          fps: 30.0,
          codec: 'h264',
          hasAudio: true,
          bitrate: 5000000,
        ),
      );
      final executor = ReadToolExecutor(_ctx(_project(), ffprobe));
      final result = await executor.execute(
        const ToolCall(
          id: 'c2',
          name: 'probe_video',
          args: {'clip_id': 'clip_1'},
        ),
      );

      expect(result.success, isTrue);
      expect(result.data['width'], equals(1920));
      expect(result.data['fps'], equals(30.0));
      expect(result.data['has_audio'], isTrue);
      verify(() => ffprobe.extractMetadata(r'C:\v\input.mp4')).called(1);
    });

    test('probe_video with unknown ID fails actionably', () async {
      final executor = ReadToolExecutor(_ctx(_project(), _MockFfprobe()));
      final result = await executor.execute(
        const ToolCall(
          id: 'c3',
          name: 'probe_video',
          args: {'clip_id': 'nope'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown clip ID'));
      expect(result.error, contains('list_project_clips'));
    });

    test('get_edit_history returns operations', () async {
      final executor = ReadToolExecutor(_ctx(_project(), _MockFfprobe()));
      final result = await executor.execute(
        const ToolCall(id: 'c4', name: 'get_edit_history'),
      );

      expect(result.success, isTrue);
      final ops = result.data['operations'] as List;
      expect(ops, hasLength(1));
      expect(ops.first['id'], equals('op_old'));
      expect(result.data['count'], equals(1));
    });
  });
}

