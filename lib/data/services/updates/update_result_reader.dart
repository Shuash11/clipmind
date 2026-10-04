import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';

/// Classification of the last update result consumed on startup.
enum UpdateResultKind { success, failed, versionMismatch }

/// The classified outcome of the last update attempt, with user-facing
/// text for surfacing on the hub ([message] is null for clean installs —
/// the what's-new flow owns that UX via lastSeenVersion).
class UpdateResult {
  final UpdateResultKind kind;
  final String? reason;
  final String? expectedVersion;
  final String? currentVersion;

  const UpdateResult.success()
      : kind = UpdateResultKind.success,
        reason = null,
        expectedVersion = null,
        currentVersion = null;

  const UpdateResult.failed(this.reason)
      : kind = UpdateResultKind.failed,
        expectedVersion = null,
        currentVersion = null;

  const UpdateResult.versionMismatch({
    required this.expectedVersion,
    required this.currentVersion,
  }) : kind = UpdateResultKind.versionMismatch,
       reason = null;

  String? get message {
    switch (kind) {
      case UpdateResultKind.success:
        return null;
      case UpdateResultKind.failed:
        return reason ?? 'The last update attempt failed. Please try again.';
      case UpdateResultKind.versionMismatch:
        return "Update installed but you're running version $currentVersion "
            '— open it from the new install location.';
    }
  }
}

/// Reads and consumes the last update result from the stable updates dir.
///
/// The helper scripts write update-result.json (success/failed + reason +
/// expectedVersion) before relaunching the app; [consume] reads it once
/// on startup, deletes it, and classifies the outcome so the hub can
/// surface failures and mismatches honestly.
class UpdateResultReader {
  /// Test seam: overrides the app-support directory. Defaults to the real
  /// [getApplicationSupportDirectory].
  final String? appSupportOverride;

  const UpdateResultReader({this.appSupportOverride});

  @visibleForTesting
  String resultPathFor(String appSupport) =>
      '${appSupport.replaceAll('\\', '/')}/updates/update-result.json';

  /// Reads, deletes, and classifies the last update result.
  ///
  /// File IO is synchronous: the result file is tiny, this runs once at
  /// startup, and a synchronous read cannot wedge on a pending event.
  /// Returns null when there is no result file (the common case), the
  /// payload is unrecognized, or anything goes wrong — startup must
  /// never block on this.
  Future<UpdateResult?> consume({required String currentVersion}) async {
    try {
      final appSupport = appSupportOverride ??
          (await getApplicationSupportDirectory()).path;
      final file = File(resultPathFor(appSupport));
      if (!file.existsSync()) return null;

      Map<String, dynamic> json;
      try {
        json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } finally {
        try {
          file.deleteSync();
        } catch (_) {}
      }

      final status = json['status'] as String?;
      switch (status) {
        case 'failed':
          return UpdateResult.failed(
            json['reason'] as String? ?? 'Unknown error',
          );
        case 'success':
          final expected = json['expectedVersion'] as String? ?? '';
          if (expected.isNotEmpty && expected != currentVersion) {
            return UpdateResult.versionMismatch(
              expectedVersion: expected,
              currentVersion: currentVersion,
            );
          }
          return const UpdateResult.success();
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}
