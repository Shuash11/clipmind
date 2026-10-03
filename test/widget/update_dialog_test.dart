import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/updates/asset_verifier.dart';
import 'package:clipmind/data/services/updates/release_info.dart';
import 'package:clipmind/data/services/updates/update_downloader.dart';
import 'package:clipmind/presentation/settings/widgets/update_dialog.dart';

/// Fake downloader: `downloadAndInstall` throws immediately, so error
/// paths are drivable without a real network or an admin-owned install
/// folder. The real construction path (empty-URL test) never reaches IO.
class _ThrowingDownloader extends UpdateDownloader {
  _ThrowingDownloader(this.error) : super(downloadUrl: '');

  final Object error;

  @override
  Future<void> downloadAndInstall() async => throw error;
}

UpdateDialog _dialog({
  String downloadUrl = 'https://example.com/update.zip',
  UpdateDownloader? overrideDownloader,
}) {
  return UpdateDialog(
    release: ReleaseInfo(
      tagName: 'v1.2.3',
      major: 1,
      minor: 2,
      patch: 3,
      releaseNotes: 'notes',
      downloadUrl: downloadUrl,
      assetType: 'zip',
      publishedAt: DateTime(2026, 10, 1),
    ),
    overrideDownloader: overrideDownloader,
  );
}

Future<void> _pumpDialog(WidgetTester tester, UpdateDialog dialog) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: dialog)));
  await tester.pump();
}

/// Pumps the initial state, taps Update, and lets the erroring future's
/// microtask chain land the dialog on the error state (no pumpAndSettle:
/// the throw happens synchronously-wrapped, no real async gaps).
Future<void> _driveError(WidgetTester tester, UpdateDialog dialog) async {
  await _pumpDialog(tester, dialog);
  await tester.tap(find.text('Update'));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('UpdateDialog', () {
    testWidgets('initial state renders title, version copy, and actions', (
      tester,
    ) async {
      await _pumpDialog(tester, _dialog());

      expect(find.text('New Version Available'), findsOneWidget);
      expect(find.textContaining('Version v1.2.3 is ready'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      // Neither progress nor error states are visible yet.
      expect(find.text('Updating...'), findsNothing);
      expect(find.text('Update Failed'), findsNothing);
    });

    testWidgets(
        'access-denied install error shows the actionable folder message', (
      tester,
    ) async {
      // A Dart FileSystemException from a non-elevated write into the
      // admin-owned install folder: "OS Error: Access is denied.".
      await _driveError(
        tester,
        _dialog(
          overrideDownloader: _ThrowingDownloader(
            const FileSystemException('Access is denied while copying'),
          ),
        ),
      );

      expect(find.text('Update Failed'), findsOneWidget);
      expect(
        find.text(
          'ClipMind could not write to the installation folder. '
          'Try running the app as administrator, or reinstall to a '
          'per-user folder.',
        ),
        findsOneWidget,
      );
      // Not the generic fallback.
      expect(
        find.textContaining('An unexpected error occurred'),
        findsNothing,
      );
    });

    testWidgets(
        'PowerShell access-denied wrapped in Extraction failed takes '
        'precedence over the corrupted message', (tester) async {
      // The ZIP install script's Copy-Item -ErrorAction Stop surfaces
      // PowerShell's "Access to the path ... is denied" stderr, which the
      // downloader wraps in "Extraction failed: ...".
      await _driveError(
        tester,
        _dialog(
          overrideDownloader: _ThrowingDownloader(
            Exception(
              'Extraction failed: Access to the path '
              r"'C:\Program Files\ClipMind\clipmind.exe' is denied.",
            ),
          ),
        ),
      );

      expect(
        find.textContaining('could not write to the installation folder'),
        findsOneWidget,
      );
      // The access-denied branch wins over "Extraction failed"'s
      // corrupted-file mapping.
      expect(find.textContaining('was corrupted'), findsNothing);
    });

    testWidgets('security-check failure keeps its message', (tester) async {
      await _driveError(
        tester,
        _dialog(
          overrideDownloader: _ThrowingDownloader(
            const UpdateVerificationException(
              'The update failed a security check and was not installed.',
              result: AssetVerificationResult(
                reason: 'mismatch',
                passed: false,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('security check'), findsOneWidget);
    });

    testWidgets('HTTP 404 keeps the not-found message', (tester) async {
      await _driveError(
        tester,
        _dialog(
          overrideDownloader: _ThrowingDownloader(
            Exception('Download failed (HTTP 404)'),
          ),
        ),
      );

      expect(find.textContaining('Could not find the update file'), findsOneWidget);
    });

    testWidgets(
        'unmapped error falls back to the generic message with Retry/Close', (
      tester,
    ) async {
      await _driveError(
        tester,
        _dialog(
          overrideDownloader: _ThrowingDownloader(
            Exception('Something went sideways'),
          ),
        ),
      );

      expect(find.text('Update Failed'), findsOneWidget);
      expect(
        find.text('An unexpected error occurred. Please try again later.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets(
        'empty download URL via the real downloader maps to the '
        'corrupted-data message', (tester) async {
      // Empty download URL: downloadAndInstall throws before any IO, so
      // the REAL construction path is drivable deterministically. The
      // existing "empty" branch catches it (not the generic fallback).
      await _driveError(tester, _dialog(downloadUrl: ''));

      expect(find.text('Update Failed'), findsOneWidget);
      expect(
        find.text(
          'The update data is corrupted. Please try again or download '
          'from the website.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });
  });
}
