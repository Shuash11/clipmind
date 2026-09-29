import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/llm/openai_provider.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart'
    hide providerRegistryProvider;
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_profile_repository.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart'
    as genb;
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:clipmind/state/player_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';

class _FakeGenBRegistry implements genb.ProviderRegistry {
  @override
  Iterable<ProviderDefinition> get definitions => const [];

  @override
  ProviderDefinition? definitionFor(String providerId) => null;

  @override
  ModelProviderAdapter? adapterFor(String providerId) => null;
}

class _FakeRepository implements ProviderProfileRepository {
  _FakeRepository(this.document);

  final ProviderProfilesDocument document;

  @override
  Future<Result<ProviderProfilesDocument>> load() async =>
      Success(document);

  @override
  Future<Result<void>> save(ProviderProfilesDocument document) async =>
      const Success(null);

  @override
  Future<Result<void>> deleteProfile(
    String profileId,
    CredentialStore credentials,
  ) async => const Success(null);

  @override
  Future<Result<void>> resumePendingDeletions(
    CredentialStore credentials,
  ) async => const Success(null);
}

class _FakeCredentials implements CredentialStore {
  @override
  Future<Result<String?>> read(String credentialId) async =>
      const Success('key-123');

  @override
  Future<Result<void>> write(String credentialId, String secret) async =>
      const Success(null);

  @override
  Future<Result<void>> delete(String credentialId) async =>
      const Success(null);
}

void main() {
  group('runtime provider wiring (P0 regression)', () {
    test(
        'real provider graph resolves the active profile provider '
        'with the profile model', () async {
      final profile = ProviderProfile(
        id: 'profile-1',
        providerId: 'openai',
        displayName: 'Test OpenAI',
        endpoint: Uri.parse('https://api.openai.com'),
        credentialId: 'cred-1',
        selectedModelId: 'test-model',
      );
      final container = ProviderContainer(
        overrides: [
          providerPlatformBootstrapResultProvider.overrideWithValue(
            Success(
              ProviderPlatformBootstrapResult(
                _FakeGenBRegistry(),
                profiles: [profile],
                activeProfileId: profile.id,
                repository: _FakeRepository(
                  ProviderProfilesDocument(
                    schemaVersion: 1,
                    profiles: [profile],
                    activeProfileId: profile.id,
                  ),
                ),
                credentials: _FakeCredentials(),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = await container
          .read(providerRegistryProvider)
          .getActiveProvider();

      expect(provider, isNotNull);
      expect((provider as OpenAiProvider).modelName, equals('test-model'));
    });
  });

  group('loopback end-to-end capstone', () {
    test(
        'custom profile over loopback HTTP runs the agentic path '
        'and applies the edit', () async {
      // Scripted OpenAI-compatible server: first round emits a trim
      // tool call, later rounds report completion. Real HTTP, no mocks.
      var requests = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((HttpRequest request) async {
        requests++;
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        if (requests == 1) {
          request.response.write(jsonEncode({
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
                        'arguments': jsonEncode({
                          'clip_id': 'clip_1',
                          'start': '00:00:00.000',
                          'end': '00:00:02.000',
                        }),
                      },
                    },
                  ],
                },
              },
            ],
          }));
        } else {
          request.response.write(jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {
                  'role': 'assistant',
                  'content': 'Trimmed via loopback.',
                },
              },
            ],
          }));
        }
        await request.response.close();
      });

      // FFmpeg is faked at the service seam (writes the output file);
      // everything else — profile resolution, HTTP, agent loop, command
      // mapping with real paths, applier, chat — is real.
      final tmp =
          await Directory.systemTemp.createTemp('clipmind_loopback_');
      addTearDown(() => tmp.delete(recursive: true));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final input = File('${tmp.path}/in.mp4')..writeAsStringSync('src');
      final outDir = Directory('${tmp.path}/out')..createSync();

      final profile = ProviderProfile(
        id: 'profile-loopback',
        providerId: 'custom',
        displayName: 'Loopback',
        endpoint:
            Uri.parse('http://127.0.0.1:${server.port}/api/v1'),
        credentialId: 'cred-1',
        selectedModelId: 'loopback-model',
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ffmpegServiceProvider.overrideWithValue(_WritingFfmpeg()),
          providerPlatformBootstrapResultProvider.overrideWithValue(
            Success(
              ProviderPlatformBootstrapResult(
                _FakeGenBRegistry(),
                profiles: [profile],
                activeProfileId: profile.id,
                repository: _FakeRepository(
                  ProviderProfilesDocument(
                    schemaVersion: 1,
                    profiles: [profile],
                    activeProfileId: profile.id,
                  ),
                ),
                credentials: _FakeCredentials(),
              ),
            ),
          ),
          projectMetadataProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(
            Project(
              id: 'p1',
              name: 'Loopback',
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
              sourceMediaPaths: [input.path],
              tracks: [
                Track(
                  id: 't1',
                  type: TrackType.video,
                  label: 'Video',
                  clips: [
                    Clip(
                      id: 'clip_1',
                      trackId: 't1',
                      sourcePath: input.path,
                      startMs: 0,
                      endMs: 10000,
                    ),
                  ],
                ),
              ],
              durationMs: 10000,
              outputDir: outDir.path,
            ),
          );

      await container
          .read(agentRunControllerProvider.notifier)
          .submit('trim the first clip to 0-2s');

      expect(requests, greaterThanOrEqualTo(2));
      final reply = container.read(chatMessagesProvider).lastWhere(
            (m) => m.role == ChatRole.agent,
          );
      expect(reply.status, equals(MessageStatus.applied));
      expect(reply.content, equals('Trimmed via loopback.'));
      expect(reply.resultingOperationIds, equals(['call_1']));
      final clip = container
          .read(projectProvider)
          .valueOrNull!
          .tracks
          .expand((t) => t.clips)
          .singleWhere((c) => c.id == 'clip_1');
      expect(clip.sourcePath.startsWith(outDir.path), isTrue);
      expect(
        container.read(currentVideoPathProvider),
        equals(clip.sourcePath),
      );
    });
  });
}

class _WritingFfmpeg extends FfmpegService {
  _WritingFfmpeg() : super(tempDir: Directory.systemTemp.path);

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    final out = File(job.outputPath);
    await out.parent.create(recursive: true);
    await out.writeAsString('fake');
    return FfmpegResult(
      success: true,
      outputPath: job.outputPath,
      exitCode: 0,
    );
  }
}
