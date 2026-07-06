import 'package:flutter/material.dart';
import 'package:clipmind/data/services/updates/release_info.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatelessWidget {
  final ReleaseInfo release;

  const UpdateDialog({super.key, required this.release});

  static Future<void> show(BuildContext context, ReleaseInfo release) {
    return showDialog(
      context: context,
      builder: (_) => UpdateDialog(release: release),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Version Available'),
      content: Text('Version ${release.tagName} is ready to download.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            final uri = Uri.parse(release.downloadUrl);
            canLaunchUrl(uri).then((ok) {
              if (ok) launchUrl(uri, mode: LaunchMode.externalApplication);
            });
          },
          icon: const Icon(Icons.download),
          label: const Text('Update'),
        ),
      ],
    );
  }
}
