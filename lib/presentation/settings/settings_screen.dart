import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/presentation/settings/widgets/update_dialog.dart';
import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';

import 'package:clipmind/data/models/app_settings.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/update_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '...';
  bool _checkOnStartup = true;
  final _binaryController = TextEditingController();
  final _modelController = TextEditingController();
  final _binaryFocus = FocusNode();
  final _modelFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _syncWhisperFields(ref.read(settingsProvider).valueOrNull);
    _binaryFocus.addListener(_onBinaryFocusLost);
    _modelFocus.addListener(_onModelFocusLost);
  }

  @override
  void dispose() {
    _binaryController.dispose();
    _modelController.dispose();
    _binaryFocus.dispose();
    _modelFocus.dispose();
    super.dispose();
  }

  /// Persist when either path field loses focus (also covers submit).
  void _onBinaryFocusLost() {
    if (!mounted) return;
    if (!_binaryFocus.hasFocus) _persistWhisper();
  }

  void _onModelFocusLost() {
    if (!mounted) return;
    if (!_modelFocus.hasFocus) _persistWhisper();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = '${info.version}+${info.buildNumber}');
  }

  /// Persist the whisper path fields (empty tolerated — auto-detect).
  void _persistWhisper() {
    unawaited(
      _updateSettings(
        (s) => s.copyWith(
          whisperBinaryPath: _binaryController.text.trim(),
          whisperModelPath: _modelController.text.trim(),
        ),
      ),
    );
  }

  void _syncWhisperFields(AppSettings? settings) {
    if (settings == null) return;
    if (!_binaryFocus.hasFocus &&
        _binaryController.text != settings.whisperBinaryPath) {
      _binaryController.text = settings.whisperBinaryPath;
    }
    if (!_modelFocus.hasFocus &&
        _modelController.text != settings.whisperModelPath) {
      _modelController.text = settings.whisperModelPath;
    }
  }

  /// Read + update through [settingsProvider]; persists via
  /// `SettingsRepository.save`. No-op when settings have not loaded yet.
  Future<void> _updateSettings(AppSettings Function(AppSettings) mutate) async {
    try {
      final current = ref.read(settingsProvider).valueOrNull;
      if (current == null) return;
      await ref.read(settingsProvider.notifier).update(mutate(current));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updateState = ref.watch(updateNotifierProvider);
    final providerState = ref.watch(providerProfileNotifierProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;

    // Sync the whisper path fields whenever settings (re)load while the
    // fields are not being edited.
    ref.listen<AsyncValue<AppSettings>>(settingsProvider, (previous, next) {
      _syncWhisperFields(next.valueOrNull);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('App Version', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('ClipMind $_appVersion', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text('AI', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('settings-ai-providers'),
                  leading: const Icon(Icons.hub_outlined),
                  title: const Text('AI Providers'),
                  subtitle: Text(
                    providerState.failureMessage != null
                        ? 'Provider platform unavailable'
                        : '${providerState.profiles.length} profile${providerState.profiles.length == 1 ? '' : 's'} configured',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(aiProvidersPath),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Editing', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey('settings-confirm-edits'),
                  secondary: const Icon(Icons.fact_check_outlined),
                  title: const Text('Confirm each edit'),
                  subtitle: const Text(
                    'Every AI edit asks for your approval before it runs',
                  ),
                  value: ref.watch(agentConfirmEditsProvider),
                  onChanged: (v) =>
                      ref.read(agentConfirmEditsProvider.notifier).state = v,
                ),
                SwitchListTile(
                  key: const ValueKey('settings-plan-edits'),
                  secondary: const Icon(Icons.playlist_add_check_rounded),
                  title: const Text('Show edit plan before applying'),
                  subtitle: const Text(
                    'Review the AI\u2019s planned steps and approve or discard them',
                  ),
                  value: settings?.planEditsBeforeApply ?? false,
                  onChanged: (v) =>
                      unawaited(_updateSettings((s) => s.copyWith(planEditsBeforeApply: v))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Transcription (whisper.cpp)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Optional — leave empty to auto-detect whisper-cli on PATH',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('settings-whisper-binary'),
                    controller: _binaryController,
                    focusNode: _binaryFocus,
                    decoration: const InputDecoration(
                      labelText: 'Binary path',
                      hintText: r'C:\whisper\whisper-cli.exe',
                    ),
                    onSubmitted: (_) => _persistWhisper(),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('settings-whisper-model'),
                    controller: _modelController,
                    focusNode: _modelFocus,
                    decoration: const InputDecoration(
                      labelText: 'Model path',
                      hintText: r'C:\whisper\models\ggml-base.bin',
                    ),
                    onSubmitted: (_) => _persistWhisper(),
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Updates', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.update),
                  title: const Text('Check for updates'),
                  subtitle: Text(_updateSubtitle(updateState)),
                  trailing: updateState.status == UpdateStatus.checking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () => ref
                      .read(updateNotifierProvider.notifier)
                      .checkForUpdate(
                        currentVersion: _appVersion.split('+')[0],
                      ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.autorenew),
                  title: const Text('Check on startup'),
                  subtitle: const Text(
                    'Automatically check for updates when the app opens',
                  ),
                  value: _checkOnStartup,
                  onChanged: (v) => setState(() => _checkOnStartup = v),
                ),
              ],
            ),
          ),
          if (updateState.status == UpdateStatus.available &&
              updateState.release != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${updateState.release!.tagName} Available',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        updateState.release!.releaseNotes,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        onPressed: () =>
                            UpdateDialog.show(context, updateState.release!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _updateSubtitle(UpdateState state) {
    switch (state.status) {
      case UpdateStatus.idle:
        return 'Tap to check';
      case UpdateStatus.checking:
        return 'Checking...';
      case UpdateStatus.available:
        return 'Update available!';
      case UpdateStatus.upToDate:
        return 'You have the latest version';
      case UpdateStatus.error:
        return 'Check failed';
    }
  }
}
