import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:clipmind/state/player_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';

class _LegacyStub extends LlmProvider {
  final EditOperationSet response;
  _LegacyStub(this.response);

  @override
  String get id => 'stub';

  @override
  Future<List<String>> availableModels() async => ['stub'];

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) async =>
      response;

  @override
  Stream<ConnectionStatus> watchConnection() =>
      Stream.value(ConnectionStatus.connected);
}

class _ScriptTools extends LlmProvider {
  final List<AgentTurnResult> script;
  final Completer<void> gate;
  int calls = 0;

  _ScriptTools(this.script, [Completer<void>? gate])
      : gate = gate ?? (Completer<void>()..complete());

  @override
  String get id => 'script-tools';

  @override
  bool get supportsToolCalling => true;

  @override
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) async {
    calls++;
    await gate.future;
    return script[calls - 1];
  }

  @override
  Future<List<String>> availableModels() async => ['script'];

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) =>
      throw UnimplementedError();

  @override
  Stream<ConnectionStatus> watchConnection() =>
      Stream.value(ConnectionStatus.connected);
}

class _FakeRegistry extends ProviderRegistry {
  final LlmProvider? active;
  _FakeRegistry(this.active);

  @override
  Future<LlmProvider?> getActiveProvider() async => active;
}

class _CapturingPipeline extends Nl2VecPipeline {
  List<AgentRequest>? seenHistory;

  _CapturingPipeline() : super(ffmpegService: FfmpegService());

  @override
  Future<SubmitResult> submitCommand(
    String text,
    Project project, {
    LlmProvider? provider,
    VideoMetadata? metadata,
    List<AgentRequest>? recentHistory,
    AgentEditApplier? applier,
    Project Function()? liveProject,
    CancellationToken? cancellation,
  }) async {
    seenHistory = recentHistory;
    return const SubmitResult(status: SubmitStatus.success, message: 'ok');
  }
}

class _FakeFfmpeg extends FfmpegService {
  int cancelCalls = 0;

  _FakeFfmpeg() : super(tempDir: Directory.systemTemp.path);

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    final out = File(job.outputPath);
    await out.parent.create(recursive: true);
    await out.writeAsString('fake');
    return FfmpegResult(success: true, outputPath: job.outputPath, exitCode: 0);
  }

  @override
  void cancel() {
    cancelCalls++;
    super.cancel();
  }
}

Project _project(String input, String outDir) {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: [input],
    tracks: [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip_1',
            trackId: 't1',
            sourcePath: input,
            startMs: 0,
            endMs: 60000,
          ),
        ],
      ),
    ],
    durationMs: 60000,
    outputDir: outDir,
  );
}

void main() {
  group('AgentRunController', () {
    test('recentHistory maps only user content to userCommand', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final pipeline = _CapturingPipeline();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          nl2vecPipelineProvider.overrideWithValue(pipeline),
          providerRegistryProvider.overrideWithValue(_FakeRegistry(
            _LegacyStub(
              const EditOperationSet(operations: [], summary: 'noop'),
            ),
          )),
          projectMetadataProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(
            _project('/v/in.mp4', '/out'),
          );
      container.read(chatMessagesProvider.notifier).add(ChatMessage(
            id: 'u-old',
            role: ChatRole.user,
            content: 'First command',
            timestamp: DateTime(2026, 1, 1),
          ));
      container.read(chatMessagesProvider.notifier).add(ChatMessage(
            id: 'a-old',
            role: ChatRole.agent,
            content: 'First reply',
            timestamp: DateTime(2026, 1, 1),
            status: MessageStatus.applied,
          ));

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('Second command');

      final history = pipeline.seenHistory!;
      final userEntries =
          history.where((r) => r.userCommand.isNotEmpty).toList();
      expect(
        userEntries.map((r) => r.userCommand),
        containsAll(['First command', 'Second command']),
      );
      final agentEntry =
          history.firstWhere((r) => r.systemPrompt == 'First reply');
      expect(agentEntry.userCommand, isEmpty);
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.idle));
    });

    test('submit runs the tool path and attaches operation IDs', () async {
      final tmp = await Directory.systemTemp.createTemp('clipmind_run_ctl_');
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await tmp.delete(recursive: true);
        await db.close();
      });
      final input = File('${tmp.path}/in.mp4')..writeAsStringSync('src');
      final outDir = Directory('${tmp.path}/out')..createSync();
      final applied = <EditOperation>[];
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ffmpegServiceProvider.overrideWithValue(_FakeFfmpeg()),
          providerRegistryProvider.overrideWithValue(_FakeRegistry(
            _ScriptTools([
              const AgentTurnResult(
                toolCalls: [
                  AgentToolCall(
                    id: 'call_1',
                    name: 'trim_clip',
                    args: {
                      'clip_id': 'clip_1',
                      'start': '00:00:05.000',
                      'end': '00:00:15.000',
                    },
                  ),
                ],
                stopReason: AgentTurnStopReason.toolCalls,
              ),
              const AgentTurnResult(
                text: 'Trimmed it.',
                stopReason: AgentTurnStopReason.stop,
              ),
            ]),
          )),
          projectMetadataProvider.overrideWith((ref) async => null),
          agentEditApplierProvider.overrideWithValue(
            AgentEditApplier(onApply: (op, path) async {
              applied.add(op);
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(
            _project(input.path, outDir.path),
          );

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('Trim the first 5 seconds');

      final messages = container.read(chatMessagesProvider);
      expect(messages, hasLength(2));
      final reply = messages.last;
      expect(reply.role, equals(ChatRole.agent));
      expect(reply.status, equals(MessageStatus.applied));
      expect(reply.content, equals('Trimmed it.'));
      expect(reply.resultingOperationIds, equals(['call_1']));
      expect(applied, hasLength(1));
      final preview = container.read(currentVideoPathProvider);
      expect(preview, isNotNull);
      expect(preview!.startsWith(outDir.path), isTrue);
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.idle));
    });

    test('cancel stops the run and kills FFmpeg', () async {
      final tmp = await Directory.systemTemp.createTemp('clipmind_cancel_');
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await tmp.delete(recursive: true);
        await db.close();
      });
      final input = File('${tmp.path}/in.mp4')..writeAsStringSync('src');
      final outDir = Directory('${tmp.path}/out')..createSync();
      final gate = Completer<void>();
      final script = _ScriptTools(
        [
          const AgentTurnResult(
            text: 'Never reached.',
            stopReason: AgentTurnStopReason.stop,
          ),
        ],
        gate,
      );
      final ffmpeg = _FakeFfmpeg();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ffmpegServiceProvider.overrideWithValue(ffmpeg),
          providerRegistryProvider.overrideWithValue(_FakeRegistry(script)),
          projectMetadataProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(
            _project(input.path, outDir.path),
          );

      final run = container
          .read(agentRunControllerProvider.notifier)
          .submit('Trim it');
      while (script.calls == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.running));
      container.read(agentRunControllerProvider.notifier).cancel();
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.cancelled));
      expect(ffmpeg.cancelCalls, equals(1));
      gate.complete();
      await run;

      final reply = container.read(chatMessagesProvider).last;
      expect(reply.content, contains('Cancelled'));
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.cancelled));
    });

    test('no provider configured replies with an error bubble', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          providerRegistryProvider.overrideWithValue(_FakeRegistry(null)),
          projectMetadataProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(
            _project('/v/in.mp4', '/out'),
          );

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('Do something');

      final reply = container.read(chatMessagesProvider).last;
      expect(reply.status, equals(MessageStatus.error));
      expect(reply.content, contains('No LLM provider'));
    });
  });
}

