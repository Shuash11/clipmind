import 'package:flutter/material.dart';
import 'package:clipmind/data/services/updates/release_info.dart';
import 'package:clipmind/data/services/updates/update_downloader.dart';

class UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;

  const UpdateDialog({super.key, required this.release});

  static Future<void> show(BuildContext context, ReleaseInfo release) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(release: release),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String _status = '';
  String? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorDialog();
    }
    if (_isDownloading) {
      return _buildProgressDialog();
    }
    return _buildInitialDialog();
  }

  Widget _buildInitialDialog() {
    return AlertDialog(
      title: const Text('New Version Available'),
      content: Text('Version ${widget.release.tagName} is ready to download.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: _startUpdate,
          icon: const Icon(Icons.download),
          label: const Text('Update'),
        ),
      ],
    );
  }

  Widget _buildProgressDialog() {
    return AlertDialog(
      title: const Text('Updating...'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 12),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDialog() {
    return AlertDialog(
      title: const Text('Update Failed'),
      content: Text(_error!),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _status = 'Starting...';
    });

    try {
      final downloader = UpdateDownloader(
        downloadUrl: widget.release.downloadUrl,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _status = status;
            });
          }
        },
      );
      await downloader.downloadAndInstall();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isDownloading = false;
        });
      }
    }
  }
}
