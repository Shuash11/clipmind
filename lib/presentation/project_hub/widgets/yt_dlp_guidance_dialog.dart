import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

/// Guidance shown when the yt-dlp availability preflight reports the binary
/// missing. A runtime missing-binary race (the probe passed but the spawn
/// failed) surfaces the SnackBar fallback instead; the dialog is the
/// recovery path the next attempt's preflight offers.
///
/// Content follows the Carbon progress/status guidance: one short title,
/// scannable steps, and a single primary action. The standalone build is
/// the recommended install (a pip install may additionally need a JS
/// runtime); no winget assumption and no nonexistent path setting.
class YtDlpGuidanceDialog extends StatelessWidget {
  /// Official release page: the standalone `yt-dlp.exe` / `yt-dlp_macos`
  /// assets live under the latest release.
  static const downloadPageUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest';

  /// Called after the dialog closes when the browser launch failed, so the
  /// hub can surface a fallback notice (the URL stays copyable from here).
  final VoidCallback? onLaunchFailed;

  const YtDlpGuidanceDialog({super.key, this.onLaunchFailed});

  /// Shows the dialog and resolves when it closes. The caller stays idle —
  /// the dialog is informative, never destructive.
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onLaunchFailed,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => YtDlpGuidanceDialog(onLaunchFailed: onLaunchFailed),
    );
  }

  Future<void> _openDownloadPage(BuildContext context) async {
    // Close first so the browser opens against a clean hub; the launch
    // continues after this widget is gone and only touches the callback.
    Navigator.of(context).pop();
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(downloadPageUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Missing platform implementation or an OS refusal: fall through to
      // the fallback notice instead of throwing into the UI.
      launched = false;
    }
    if (!launched) onLaunchFailed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('yt-dlp is required for YouTube links'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ClipMind downloads YouTube videos with yt-dlp, a free tool '
              'that runs on your machine. Install it once:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const _GuidanceStep(
              number: '1',
              text: 'Download the official standalone build — yt-dlp.exe '
                  'for Windows or yt-dlp_macos for macOS.',
            ),
            const SizedBox(height: 10),
            const _GuidanceStep(
              number: '2',
              text: 'Put the file on your PATH (for example, in your user '
                  'bin folder) so ClipMind can find it.',
            ),
            const SizedBox(height: 10),
            const _GuidanceStep(
              number: '3',
              text: 'Paste the YouTube link again — no restart needed.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ClipMindColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ClipMindColors.borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: ClipMindColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Installed with pip? YouTube support may also need a '
                      'JavaScript runtime — deno is recommended.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ClipMindColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => _openDownloadPage(context),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Open download page'),
        ),
      ],
    );
  }
}

/// Numbered step: small accent badge + primary-weight instruction.
class _GuidanceStep extends StatelessWidget {
  final String number;
  final String text;

  const _GuidanceStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: ClipMindColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: theme.textTheme.labelSmall?.copyWith(
              color: ClipMindColors.accentPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ClipMindColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
