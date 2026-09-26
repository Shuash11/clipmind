import 'dart:io';

import 'package:clipmind/app.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/services/updates/github_release_checker.dart';
import 'package:clipmind/data/services/updates/release_info.dart';
import 'package:clipmind/features/projects/data/project_document_codec.dart';
import 'package:clipmind/features/projects/data/project_document_migrator.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/providers/data/catalog/provider_catalog.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/data/provider_registry_impl.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/update_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Windows normal app opens the custom provider form without network access',
    (tester) async {
      _verifyLegacyFixture();

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWith((ref) {
              final database = AppDatabase(NativeDatabase.memory());
              ref.onDispose(database.close);
              return database;
            }),
            providerPlatformBootstrapResultProvider.overrideWithValue(
              _offlineProviderBootstrap(),
            ),
            githubReleaseCheckerProvider.overrideWithValue(
              _OfflineGithubReleaseChecker(),
            ),
          ],
          child: const ClipMindApp(),
        ),
      );
      await _pumpFrames(tester);

      final settingsButton = find.byKey(const ValueKey('project-hub-settings'));
      expect(settingsButton, findsOneWidget);
      await tester.tap(settingsButton);
      await _pumpFrames(tester);

      expect(find.text('Settings'), findsOneWidget);
      final aiProvidersTile = find.byKey(
        const ValueKey('settings-ai-providers'),
      );
      expect(aiProvidersTile, findsOneWidget);
      await tester.tap(aiProvidersTile);
      await _pumpFrames(tester);

      expect(find.byKey(const ValueKey('ai-providers-screen')), findsOneWidget);
      final addProfile = find.byKey(const ValueKey('add-provider-profile'));
      expect(addProfile, findsOneWidget);
      await tester.tap(addProfile);
      await _pumpFrames(tester);

      final preset = find.byKey(const ValueKey('provider-preset-new-openai'));
      expect(preset, findsOneWidget);
      await tester.tap(preset);
      await _pumpFrames(tester, frames: 2);
      await tester.tap(find.text('Custom OpenAI-compatible').last);
      await _pumpFrames(tester);

      expect(
        find.byKey(const ValueKey('custom-provider-form')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 16));
    },
  );
}

void _verifyLegacyFixture() {
  final source = File(
    'test/fixtures/projects/legacy_v1_smoke_project.cmproj',
  ).readAsStringSync();
  expect(source, contains('"label": "legacy-smoke.mp4"'));

  final result = ProjectDocumentMigrator(
    ProjectDocumentCodec(),
  ).migrateJson(source);
  expect(result, isA<Success<ProjectDocument>>());
  final document = (result as Success<ProjectDocument>).value;
  final track = document.currentState.tracks.single;
  final clip = track.clips.single;
  final asset = document.currentState.assets.singleWhere(
    (candidate) => candidate.id == clip.assetId,
  );

  expect(document.schemaVersion, 2);
  expect(track.clips, hasLength(1));
  expect(clip.startMs, 120);
  expect(clip.endMs, 1320);
  expect(clip.positionMs, 480);
  expect(asset.displayName, 'legacy-smoke.mp4');
  expect(asset.sourcePath, r'C:\media\legacy-smoke.mp4');
}

Success<ProviderPlatformBootstrapResult> _offlineProviderBootstrap() =>
    Success<ProviderPlatformBootstrapResult>(
      ProviderPlatformBootstrapResult(
        ProviderRegistryImpl(
          definitions: ProviderCatalog.presets,
          adapters: const <String, ModelProviderAdapter>{},
        ),
      ),
    );

final class _OfflineGithubReleaseChecker extends GithubReleaseChecker {
  @override
  Future<ReleaseInfo?> checkForUpdate() async => null;
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 4}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
