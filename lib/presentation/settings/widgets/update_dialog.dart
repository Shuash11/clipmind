import 'package:flutter/material.dart';
import 'package:clipmind/data/services/updates/release_info.dart';
import 'package:clipmind/data/services/updates/update_downloader.dart';

class UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;

  /// Test-only: replaces the internally created downloader so error paths
  /// are drivable without a real network or an admin-owned install folder.
  @visibleForTesting
  final UpdateDownloader? overrideDownloader;

  const UpdateDialog({
    super.key,
    required this.release,
    this.overrideDownloader,
  });

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
  double? _progress;
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
      content: Text('Version ${widget.release.tagName} is ready to download. ClipMind will close briefly to install it.'),
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
            LinearProgressIndicator(value: _progress),
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
      content: Text(_userFriendlyError(_error!)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            setState(() {
              _error = null;
              _isDownloading = false;
              _progress = 0;
              _status = '';
            });
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  String _userFriendlyError(String error) {
    if (error.contains('could not start')) {
      // UpdateStartException: the detached helper script never started
      // (UAC declined, blocked, or missing interpreter). The app stayed
      // alive — no silent death — so a retry is safe.
      return 'The update could not start. Please try again, or download '
          'the installer from the website.';
    }
    if (error.contains('HTTP 404') || error.contains('HTTP 403')) {
      return 'Could not find the update file. Please try again later or download from the website.';
    }
    if (error.contains('HTTP')) {
      return 'Download failed due to a network error. Please check your connection and try again.';
    }
    if (error.contains('timeout') || error.contains('Timeout')) {
      return 'The download timed out. Please check your internet connection and try again.';
    }
    if (error.contains('security check')) {
      return 'The update failed a security check and was not installed. Please try again or download from the official website.';
    }
    if (error.contains('Access is denied') ||
        error.contains('Access to the path')) {
      // Non-elevated ZIP installs into the admin-owned install folder
      // (e.g. C:\Program Files\ClipMind) fail at Copy-Item with an
      // access-denied error, which surfaces here either as a Dart
      // FileSystemException ("Access is denied") or wrapped in
      // "Extraction failed" with PowerShell's "Access to the path" stderr.
      return 'ClipMind could not write to the installation folder. Try running the app as administrator, or reinstall to a per-user folder.';
    }
    if (error.contains('Extraction failed')) {
      return 'The downloaded file was corrupted. Please try downloading again.';
    }
    if (error.contains('ZIP') ||
        error.contains('empty') ||
        error.contains('Copy failed')) {
      return 'The update data is corrupted. Please try again or download from the website.';
    }
    return 'An unexpected error occurred. Please try again later.';
  }

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _progress = 0;
      _status = 'Starting...';
    });

    try {
      final tag = widget.release.tagName;
      final targetVersion = tag.startsWith('v') ? tag.substring(1) : tag;
      final downloader = widget.overrideDownloader ??
          UpdateDownloader(
            downloadUrl: widget.release.downloadUrl,
            assetType: widget.release.assetType,
            digest: widget.release.digest,
            targetVersion: targetVersion,
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
