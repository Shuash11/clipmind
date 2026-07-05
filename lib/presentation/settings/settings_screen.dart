import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/presentation/settings/widgets/update_dialog.dart';

import 'package:clipmind/state/update_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '...';
  bool _checkOnStartup = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = '${info.version}+${info.buildNumber}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updateState = ref.watch(updateNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('App Version', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('ClipMind $_appVersion', style: theme.textTheme.bodyMedium),
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
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: () => ref.read(updateNotifierProvider.notifier).checkForUpdate(currentVersion: _appVersion.split('+')[0]),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.autorenew),
                  title: const Text('Check on startup'),
                  subtitle: const Text('Automatically check for updates when the app opens'),
                  value: _checkOnStartup,
                  onChanged: (v) => setState(() => _checkOnStartup = v),
                ),
              ],
            ),
          ),
          if (updateState.status == UpdateStatus.available && updateState.release != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${updateState.release!.tagName} Available',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Text(updateState.release!.releaseNotes,
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        onPressed: () => UpdateDialog.show(context, updateState.release!),
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
      case UpdateStatus.idle: return 'Tap to check';
      case UpdateStatus.checking: return 'Checking...';
      case UpdateStatus.available: return 'Update available!';
      case UpdateStatus.upToDate: return 'You have the latest version';
      case UpdateStatus.error: return 'Check failed';
    }
  }
}
