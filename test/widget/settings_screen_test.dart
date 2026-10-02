import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/models/app_settings.dart';
import 'package:clipmind/data/repositories/settings_repository.dart';
import 'package:clipmind/presentation/settings/settings_screen.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:clipmind/state/settings_providers.dart';

/// Settings repository double: records saves (the notifier's `update`
/// persists through it); loads defaults.
class _RecordingSettingsRepository extends SettingsRepository {
  int saves = 0;
  AppSettings? lastSaved;

  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {
    saves++;
    lastSaved = settings;
  }
}

/// The settings screen reads the app version from the platform channel.
void _mockPackageInfo() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async => {
      'appName': 'ClipMind',
      'packageName': 'dev.clipmind',
      'version': '1.8.0',
      'buildNumber': '1',
    },
  );
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      null,
    );
  });
}

Future<void> _pumpSettings(WidgetTester tester, ProviderContainer container) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
}

void main() {
  testWidgets('settings renders Editing and Transcription sections', (
    tester,
  ) async {
    _mockPackageInfo();
    final repo = _RecordingSettingsRepository();
    final container = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await _pumpSettings(tester, container);
    await _settle(tester);

    expect(find.text('Editing'), findsOneWidget);
    expect(find.text('Confirm each edit'), findsOneWidget);
    expect(find.text('Show edit plan before applying'), findsOneWidget);
    expect(find.text('Transcription (whisper.cpp)'), findsOneWidget);
    expect(find.text('Binary path'), findsOneWidget);
    expect(find.text('Model path'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('show edit plan switch persists via the settings path', (
    tester,
  ) async {
    _mockPackageInfo();
    final repo = _RecordingSettingsRepository();
    final container = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await _pumpSettings(tester, container);
    await _settle(tester);

    expect(container.read(settingsProvider).value?.planEditsBeforeApply,
        isFalse);
    final savesBefore = repo.saves;

    await tester.tap(find.byKey(const ValueKey('settings-plan-edits')));
    await _settle(tester);

    expect(container.read(settingsProvider).value?.planEditsBeforeApply,
        isTrue);
    expect(repo.saves, greaterThan(savesBefore));
    expect(repo.lastSaved?.planEditsBeforeApply, isTrue);
  });

  testWidgets('confirm each edit switch updates the flag and persists', (
    tester,
  ) async {
    _mockPackageInfo();
    final repo = _RecordingSettingsRepository();
    final container = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await _pumpSettings(tester, container);
    await _settle(tester);

    expect(container.read(agentConfirmEditsProvider), isFalse);
    final savesBefore = repo.saves;

    await tester.tap(find.byKey(const ValueKey('settings-confirm-edits')));
    await _settle(tester);

    expect(container.read(agentConfirmEditsProvider), isTrue);
    expect(repo.saves, greaterThan(savesBefore));
    expect(repo.lastSaved?.confirmAgentEdits, isTrue);
  });

  testWidgets('whisper path fields persist on submit and tolerate empty', (
    tester,
  ) async {
    _mockPackageInfo();
    final repo = _RecordingSettingsRepository();
    final container = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await _pumpSettings(tester, container);
    await _settle(tester);

    // Enter a binary path and submit (done action on the focused field).
    await tester.enterText(
      find.byKey(const ValueKey('settings-whisper-binary')),
      r'C:\w\whisper-cli.exe',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(
      container.read(settingsProvider).value?.whisperBinaryPath,
      r'C:\w\whisper-cli.exe',
    );
    expect(repo.lastSaved?.whisperBinaryPath, r'C:\w\whisper-cli.exe');

    // Focus loss persists too: edit the model field, then move focus away.
    await tester.enterText(
      find.byKey(const ValueKey('settings-whisper-model')),
      r'C:\w\ggml-base.bin',
    );
    await tester.tap(find.byKey(const ValueKey('settings-whisper-binary')));
    await _settle(tester);

    expect(
      container.read(settingsProvider).value?.whisperModelPath,
      r'C:\w\ggml-base.bin',
    );

    // Empty values are tolerated (auto-detect) — no error, setting cleared.
    await tester.enterText(
      find.byKey(const ValueKey('settings-whisper-binary')),
      '',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(
      container.read(settingsProvider).value?.whisperBinaryPath,
      '',
    );
    expect(tester.takeException(), isNull);
  });
}
