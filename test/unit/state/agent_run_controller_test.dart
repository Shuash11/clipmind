import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/app_settings.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/chat_step.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/repositories/settings_repository.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/data/services/transcription/whisper_service.dart';
import 'package:clipmind/domain/agent/agent_confirmation.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
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
  bool? seenDryRun;
  Map<String, dynamic>? Function(String kind)? seenReadAnalysis;
  void Function(String kind, Map<String, dynamic> payload)? seenWriteAnalysis;
  WhisperPaths? Function()? seenWhisperConfig;
  Future<String?> Function(String familyId)? seenResolveFont;
  Future<String?> Function(String familyId)? seenPlannedResolveFont;
  SubmitResult result =
      const SubmitResult(status: SubmitStatus.success, message: 'ok');

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
    ConfirmationGate? gate,
    bool dryRun = false,
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) async {
    seenHistory = recentHistory;
    seenDryRun = dryRun;
    seenReadAnalysis = readAnalysis;
    seenWriteAnalysis = writeAnalysis;
    seenWhisperConfig = whisperConfig;
    seenResolveFont = resolveFont;
    return result;
  }

  @override
  Future<SubmitResult> executePlanned(
    List<ToolCall> planned,
    Project project, {
    AgentEditApplier? applier,
    Project Function()? liveProject,
    CancellationToken? cancellation,
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) async {
    seenPlannedResolveFont = resolveFont;
    return result;
  }
}

class _GatedSettingsRepo extends SettingsRepository {
  final Completer<void> gate;
  _GatedSettingsRepo(this.gate);

  @override
  Future<AppSettings> load() async {
    await gate.future;
    return const AppSettings(planEditsBeforeApply: true);
  }
}

/// Filesystem-free settings double for plain sandbox tests.
///
/// The real repository prints a binding error there (caught degradation
/// path); the stub keeps the same observable behavior (defaults on load,
/// state update on save) without the noise.
class _TestSettingsRepository extends SettingsRepository {
  AppSettings? saved;

  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {
    saved = settings;
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
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(_TestSettingsRepository()),
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

    test('submit wires tool-context callbacks into the pipeline', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final pipeline = _CapturingPipeline();
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(_TestSettingsRepository()),
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

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('Detect scenes');

      expect(pipeline.seenReadAnalysis, isNotNull,
          reason: 'readAnalysis should reach the pipeline');
      expect(pipeline.seenWriteAnalysis, isNotNull,
          reason: 'writeAnalysis should reach the pipeline');
      expect(pipeline.seenWhisperConfig, isNotNull,
          reason: 'whisperConfig should reach the pipeline');
      expect(pipeline.seenResolveFont, isNotNull,
          reason: 'resolveFont should reach the pipeline');
      // Default settings carry empty whisper paths (unset).
      final paths = pipeline.seenWhisperConfig!();
      expect(paths, isNotNull);
      expect(paths!.binaryPath, isEmpty);
      expect(paths.modelPath, isEmpty);
      // The port callbacks are live: a write is readable back.
      pipeline.seenWriteAnalysis!('scenes:clip_1', {'ok': true});
      expect(
        pipeline.seenReadAnalysis!('scenes:clip_1'),
        equals({'ok': true}),
      );
    });

    test('approvePlan passes resolveFont to the replay', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final pipeline = _CapturingPipeline();
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(_TestSettingsRepository()),
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
      container.read(pendingPlanProvider.notifier).set(const PendingPlan(
            command: 'Add a title',
            projectId: 'p1',
            calls: [
              ToolCall(id: 'c1', name: 'overlay_text', args: {'font': 'bold'}),
            ],
          ));
      container.read(agentRunControllerProvider.notifier).state =
          AgentRunState.planReady;

      await container.read(agentRunControllerProvider.notifier).approvePlan();

      expect(pipeline.seenPlannedResolveFont, isNotNull,
          reason: 'resolveFont should reach the replay for overlay_text');
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
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(_TestSettingsRepository()),
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
            AgentEditApplier(onApply: (op, path, {List<String> removeClipIds = const []}) async {
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
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(_TestSettingsRepository()),
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
          equals(AgentRunState.idle));
    });

    test('loadHistory restores persisted messages incl. steps', () async {
      final tmp = await Directory.systemTemp.createTemp('clipmind_hist_');
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await tmp.delete(recursive: true);
        await db.close();
      });
      final input = File('${tmp.path}/in.mp4')..writeAsStringSync('src');
      final outDir = Directory('${tmp.path}/out')..createSync();
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(_TestSettingsRepository()),
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
            AgentEditApplier(onApply: (_, _, {List<String> removeClipIds = const []}) async {}),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(
            _project(input.path, outDir.path),
          );

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('Trim it');
      expect(
        container.read(chatMessagesProvider).last.steps,
        hasLength(1),
      );

      // Simulate reopening the project: drop memory, reload from DB.
      container.read(chatMessagesProvider.notifier).clear();
      expect(container.read(chatMessagesProvider), isEmpty);
      await container
          .read(agentRunControllerProvider.notifier)
          .loadHistory('p1');

      final restored = container.read(chatMessagesProvider);
      expect(restored, hasLength(2));
      expect(restored.first.role, equals(ChatRole.user));
      final reply = restored.last;
      expect(reply.content, equals('Trimmed it.'));
      expect(reply.resultingOperationIds, equals(['call_1']));
      expect(reply.steps, hasLength(1));
      expect(reply.steps.single.toolName, equals('trim_clip'));
      expect(reply.steps.single.kind, equals(ChatStepKind.edit));
    });

  group('AgentConfirmEditsFlag persistence', () {
    Future<ProviderContainer> makeContainer() async {
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(
            AppDatabase(NativeDatabase.memory()),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _TestSettingsRepository(),
          ),
        ],
      );
      addTearDown(() async {
        await container.read(appDatabaseProvider).close();
        container.dispose();
      });
      for (var i = 0; i < 200; i++) {
        if (container.read(settingsProvider).value != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return container;
    }

    test('reads through to settings and persists writes', () async {
      final container = await makeContainer();
      expect(container.read(agentConfirmEditsProvider), isFalse);

      await container.read(settingsProvider.notifier).update(
            container
                .read(settingsProvider)
                .value!
                .copyWith(confirmAgentEdits: true),
          );
      expect(container.read(agentConfirmEditsProvider), isTrue);

      container.read(agentConfirmEditsProvider.notifier).state = false;
      for (var i = 0; i < 200; i++) {
        if (container.read(settingsProvider).value?.confirmAgentEdits ==
            false) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(
        container.read(settingsProvider).value?.confirmAgentEdits,
        isFalse,
      );
    });

    test('new settings fields default backward-compatibly', () {
      const settings = AppSettings();
      expect(settings.confirmAgentEdits, isFalse);
      expect(settings.planEditsBeforeApply, isFalse);
      expect(settings.whisperBinaryPath, isEmpty);
      expect(settings.whisperModelPath, isEmpty);

      final restored = AppSettings.fromJson(const {});
      expect(restored.confirmAgentEdits, isFalse);
      expect(restored.planEditsBeforeApply, isFalse);
      expect(restored.whisperBinaryPath, isEmpty);
      expect(restored.whisperModelPath, isEmpty);

      final roundTripped = AppSettings.fromJson(
        const AppSettings(
          confirmAgentEdits: true,
          planEditsBeforeApply: true,
          whisperBinaryPath: '/usr/bin/whisper',
          whisperModelPath: '/models/ggml.bin',
        ).toJson(),
      );
      expect(roundTripped.confirmAgentEdits, isTrue);
      expect(roundTripped.planEditsBeforeApply, isTrue);
      expect(roundTripped.whisperBinaryPath, equals('/usr/bin/whisper'));
      expect(roundTripped.whisperModelPath, equals('/models/ggml.bin'));
    });
  });

    test('no provider configured replies with an error bubble', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(_TestSettingsRepository()),
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

  group('AgentRunController confirmation gate', () {
    late Directory tmp;
    late AppDatabase db;
    late File inputFile;
    late Directory outDir;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_gate_');
      db = AppDatabase(NativeDatabase.memory());
      inputFile = File('${tmp.path}/in.mp4')..writeAsStringSync('src');
      outDir = Directory('${tmp.path}/out')..createSync();
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
      await db.close();
    });

    Future<ProviderContainer> makeContainer(
      _ScriptTools script, {
      bool perEdit = false,
    }) async {
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(_TestSettingsRepository()),
          ffmpegServiceProvider.overrideWithValue(_FakeFfmpeg()),
          providerRegistryProvider.overrideWithValue(
            _FakeRegistry(script),
          ),
          projectMetadataProvider.overrideWith((ref) async => null),
          agentEditApplierProvider.overrideWithValue(
            AgentEditApplier(onApply: (_, _, {List<String> removeClipIds = const []}) async {}),
          ),
        ],
      );
      container.read(projectProvider.notifier).setProject(
            _project(inputFile.path, outDir.path),
          );
      if (perEdit) {
        // Wait for settings to finish loading first: the flag mirrors
        // settings, so a late load would revert an early write.
        for (var i = 0; i < 200; i++) {
          if (container.read(settingsProvider).value != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        container.read(agentConfirmEditsProvider.notifier).state = true;
        expect(container.read(agentConfirmEditsProvider), isTrue);
      }
      return container;
    }

    Future<void> untilPending(ProviderContainer container) async {
      for (var i = 0; i < 200; i++) {
        if (container.read(pendingConfirmationProvider) != null) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('confirmation was never requested');
    }

    _ScriptTools makeBulkScript() => _ScriptTools([
          const AgentTurnResult(
            toolCalls: [
              AgentToolCall(
                id: 'c1',
                name: 'trim_clip',
                args: {
                  'clip_id': 'clip_1',
                  'start': '00:00:05.000',
                  'end': '00:00:15.000',
                },
              ),
              AgentToolCall(
                id: 'c2',
                name: 'mute_clip',
                args: {'clip_id': 'clip_1'},
              ),
              AgentToolCall(
                id: 'c3',
                name: 'change_volume',
                args: {'clip_id': 'clip_1', 'factor': 0.5},
              ),
            ],
            stopReason: AgentTurnStopReason.toolCalls,
          ),
          const AgentTurnResult(
            text: 'All three done.',
            stopReason: AgentTurnStopReason.stop,
          ),
        ]);

    test('bulk approve executes the whole batch', () async {
      final container = await makeContainer(makeBulkScript());
      addTearDown(container.dispose);

      final run = container
          .read(agentRunControllerProvider.notifier)
          .submit('Do three edits');
      await untilPending(container);

      final pending = container.read(pendingConfirmationProvider)!;
      expect(pending.kind, equals(ConfirmationKind.bulk));
      expect(pending.toolCalls, hasLength(3));
      container
          .read(agentRunControllerProvider.notifier)
          .approvePendingConfirmation(true);
      await run;

      final reply = container.read(chatMessagesProvider).last;
      expect(reply.status, equals(MessageStatus.applied));
      expect(reply.resultingOperationIds,
          equals(['c1', 'c2', 'c3']));
      expect(
        reply.steps.map((s) => s.toolName),
        equals(['trim_clip', 'mute_clip', 'change_volume']),
      );
      expect(reply.steps.every((s) => s.success), isTrue);
      expect(reply.steps.every((s) => s.kind == ChatStepKind.edit), isTrue);
      expect(container.read(pendingConfirmationProvider), isNull);
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.idle));
    });

    test('bulk deny records skips and finishes', () async {
      final container = await makeContainer(makeBulkScript());
      addTearDown(container.dispose);

      final run = container
          .read(agentRunControllerProvider.notifier)
          .submit('Do three edits');
      await untilPending(container);

      container
          .read(agentRunControllerProvider.notifier)
          .approvePendingConfirmation(false);
      await run;

      final reply = container.read(chatMessagesProvider).last;
      expect(reply.content, equals('All three done.'));
      expect(reply.resultingOperationIds, isEmpty);
      expect(reply.steps, hasLength(3));
      expect(reply.steps.every((s) => !s.success), isTrue);
      expect(
        reply.steps.every((s) => s.summary == 'Skipped by user'),
        isTrue,
      );
      expect(container.read(pendingConfirmationProvider), isNull);
    });

    test('per-edit mode pauses every edit call', () async {
      final container = await makeContainer(
        _ScriptTools([
          const AgentTurnResult(
            toolCalls: [
              AgentToolCall(
                id: 'c1',
                name: 'mute_clip',
                args: {'clip_id': 'clip_1'},
              ),
            ],
            stopReason: AgentTurnStopReason.toolCalls,
          ),
          const AgentTurnResult(
            text: 'Muted.',
            stopReason: AgentTurnStopReason.stop,
          ),
        ]),
        perEdit: true,
      );
      addTearDown(container.dispose);

      final run = container
          .read(agentRunControllerProvider.notifier)
          .submit('Mute it');
      await untilPending(container);

      final pending = container.read(pendingConfirmationProvider)!;
      expect(pending.kind, equals(ConfirmationKind.perEdit));
      expect(pending.toolCalls, hasLength(1));
      container
          .read(agentRunControllerProvider.notifier)
          .approvePendingConfirmation(true);
      await run;

      final reply = container.read(chatMessagesProvider).last;
      expect(reply.status, equals(MessageStatus.applied));
      expect(reply.resultingOperationIds, equals(['c1']));
      expect(container.read(pendingConfirmationProvider), isNull);
    });

    test('cancel while paused denies and cancels the token', () async {
      final container = await makeContainer(makeBulkScript());
      addTearDown(container.dispose);

      final run = container
          .read(agentRunControllerProvider.notifier)
          .submit('Do three edits');
      await untilPending(container);

      container.read(agentRunControllerProvider.notifier).cancel();
      await run;

      final reply = container.read(chatMessagesProvider).last;
      expect(reply.content, contains('Cancelled'));
      expect(reply.resultingOperationIds, isEmpty);
      expect(container.read(pendingConfirmationProvider), isNull);
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.idle));
    });


    test('steps map read tools to read kind', () async {
      final container = await makeContainer(_ScriptTools([
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(
              id: 'c1',
              name: 'list_project_clips',
              args: {},
            ),
            AgentToolCall(
              id: 'c2',
              name: 'mute_clip',
              args: {'clip_id': 'clip_1'},
            ),
          ],
          stopReason: AgentTurnStopReason.toolCalls,
        ),
        const AgentTurnResult(
          text: 'Listed and muted.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]));
      addTearDown(container.dispose);

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('List then mute');

      final reply = container.read(chatMessagesProvider).last;
      expect(reply.steps, hasLength(2));
      expect(reply.steps[0].kind, equals(ChatStepKind.read));
      expect(reply.steps[1].kind, equals(ChatStepKind.edit));
      // Persisted steps survive a reload.
      final stored = await db.getChatMessages('p1');
      expect(stored.last.steps, hasLength(2));
      expect(stored.last.steps[0].toolName, equals('list_project_clips'));
    });
  });

  group('AgentRunController plan preview', () {
    late Directory tmp;
    late AppDatabase db;
    late String input;
    late Directory outDir;
    late List<EditOperation> applied;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_plan_');
      db = AppDatabase(NativeDatabase.memory());
      input = (File('${tmp.path}/in.mp4')..writeAsStringSync('src')).path;
      outDir = Directory('${tmp.path}/out')..createSync();
      applied = [];
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
      await db.close();
    });

    _ScriptTools makePlanScript() => _ScriptTools([
          const AgentTurnResult(
            toolCalls: [
              AgentToolCall(
                id: 'c1',
                name: 'trim_clip',
                args: {
                  'clip_id': 'clip_1',
                  'start': '00:00:05.000',
                  'end': '00:00:15.000',
                },
              ),
              AgentToolCall(
                id: 'c2',
                name: 'mute_clip',
                args: {'clip_id': 'clip_1'},
              ),
            ],
            stopReason: AgentTurnStopReason.toolCalls,
          ),
          const AgentTurnResult(
            text: 'Planned two edits.',
            stopReason: AgentTurnStopReason.stop,
          ),
        ]);

    Future<ProviderContainer> makePlanContainer({
      AgentEditApplier? applier,
      LlmProvider? provider,
    }) async {
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(_TestSettingsRepository()),
          ffmpegServiceProvider.overrideWithValue(_FakeFfmpeg()),
          providerRegistryProvider.overrideWithValue(
            _FakeRegistry(provider ?? makePlanScript()),
          ),
          projectMetadataProvider.overrideWith((ref) async => null),
          agentEditApplierProvider.overrideWithValue(
            applier ??
                AgentEditApplier(onApply: (op, path, {List<String> removeClipIds = const []}) async {
                  applied.add(op);
                }),
          ),
        ],
      );
      container.read(projectProvider.notifier).setProject(
            _project(input, outDir.path),
          );
      for (var i = 0; i < 200; i++) {
        if (container.read(settingsProvider).value != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await container.read(settingsProvider.notifier).update(
            container
                .read(settingsProvider)
                .value!
                .copyWith(planEditsBeforeApply: true),
          );
      return container;
    }

    test('dry-run parks a pending plan without executing', () async {
      final container = await makePlanContainer();
      addTearDown(container.dispose);

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('Trim and mute');

      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.planReady));
      final plan = container.read(pendingPlanProvider)!;
      expect(plan.command, equals('Trim and mute'));
      expect(plan.projectId, equals('p1'));
      expect(plan.calls, hasLength(2));
      expect(
        plan.calls.map((c) => c.name),
        equals(['trim_clip', 'mute_clip']),
      );
      expect(plan.steps, hasLength(2));
      final reply = container.read(chatMessagesProvider).last;
      expect(reply.content, contains('Plan ready'));
      expect(reply.status, equals(MessageStatus.needsClarification));
      expect(reply.steps, hasLength(2));
      // Dry run executes nothing.
      expect(applied, isEmpty);
      expect(container.read(currentVideoPathProvider), isNull);
    });

    test('loader steps are read-only: no replay call, no skip record',
        () async {
      final provider = _ScriptTools([
        const AgentTurnResult(
          toolCalls: [
            AgentToolCall(
              id: 'load_1',
              name: 'load_tools',
              args: {
                'tools': ['resize_clip'],
              },
            ),
            AgentToolCall(
              id: 'c1',
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
          text: 'Planned one edit.',
          stopReason: AgentTurnStopReason.stop,
        ),
      ]);
      final container = await makePlanContainer(provider: provider);
      addTearDown(container.dispose);

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('Load then trim');

      final plan = container.read(pendingPlanProvider)!;
      // The loader is visible in the trace as a read step...
      final loaderStep =
          plan.steps.singleWhere((s) => s.toolName == 'load_tools');
      expect(loaderStep.kind, equals(ChatStepKind.read));
      // ...but it is not a replayable call and does not inflate the count.
      expect(plan.calls.map((c) => c.name), equals(['trim_clip']));
      final planReply = container.read(chatMessagesProvider).last;
      expect(planReply.content, contains('1 edit(s) proposed'));

      await container.read(agentRunControllerProvider.notifier).approvePlan();

      expect(container.read(pendingPlanProvider), isNull);
      expect(applied, hasLength(1));
      final replayReply = container.read(chatMessagesProvider).last;
      expect(
        replayReply.steps.any((s) => s.summary.contains('Skipped in replay')),
        isFalse,
      );
      expect(
        replayReply.steps.any((s) => s.toolName == 'load_tools'),
        isFalse,
      );
    });

    test('approvePlan replays deterministically', () async {
      final container = await makePlanContainer();
      addTearDown(container.dispose);

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('Trim and mute');
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.planReady));

      await container.read(agentRunControllerProvider.notifier).approvePlan();

      expect(container.read(pendingPlanProvider), isNull);
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.idle));
      expect(applied, hasLength(2));
      final reply = container.read(chatMessagesProvider).last;
      expect(reply.status, equals(MessageStatus.applied));
      expect(reply.resultingOperationIds, equals(['c1', 'c2']));
      expect(reply.steps, hasLength(2));
      final preview = container.read(currentVideoPathProvider);
      expect(preview, isNotNull);
      expect(preview!.startsWith(outDir.path), isTrue);
    });

    test('discardPlan clears with a reply', () async {
      final container = await makePlanContainer();
      addTearDown(container.dispose);

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('Trim and mute');
      expect(container.read(pendingPlanProvider), isNotNull);

      await container.read(agentRunControllerProvider.notifier).discardPlan();

      expect(container.read(pendingPlanProvider), isNull);
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.idle));
      expect(
        container.read(chatMessagesProvider).last.content,
        equals('Plan discarded.'),
      );
      expect(applied, isEmpty);
    });

    test('cancel during replay keeps applied edits', () async {
      final gate = Completer<void>();
      final container = await makePlanContainer(
        applier: AgentEditApplier(onApply: (op, path, {List<String> removeClipIds = const []}) async {
          applied.add(op);
          await gate.future;
        }),
      );
      addTearDown(container.dispose);

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('Trim and mute');
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.planReady));

      final replay = container
          .read(agentRunControllerProvider.notifier)
          .approvePlan();
      while (applied.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      container.read(agentRunControllerProvider.notifier).cancel();
      gate.complete();
      await replay;

      expect(applied, hasLength(1));
      expect(
        container.read(chatMessagesProvider).last.content,
        contains('Cancelled'),
      );
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.idle));
    });

    test('first submit awaits settings load for the plan flag', () async {
      final loadGate = Completer<void>();
      final pipeline = _CapturingPipeline()
        ..result = const SubmitResult(
          status: SubmitStatus.success,
          message: 'Planned.',
          records: [
            AgentToolCallRecord(
              id: 'c1',
              name: 'trim_clip',
              args: {'clip_id': 'clip_1'},
              success: true,
              summary: 'Trim planned.',
            ),
          ],
        );
      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWithValue(
            _GatedSettingsRepo(loadGate),
          ),
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

      final run = container
          .read(agentRunControllerProvider.notifier)
          .submit('Trim it');
      // Settings still loading: submit must park here, not race ahead
      // with the default (planEditsBeforeApply: false).
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(pipeline.seenDryRun, isNull);
      loadGate.complete();
      await run;

      expect(pipeline.seenDryRun, isTrue);
      expect(container.read(agentRunControllerProvider),
          equals(AgentRunState.planReady));
      expect(
        container.read(pendingPlanProvider)!.calls.map((c) => c.name),
        equals(['trim_clip']),
      );
    });
  });
}




