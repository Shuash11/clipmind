import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Cycle 8 Phase 2 Step 1: API-only release-digest live gate.
///
/// ONE GET to `/releases/latest` in [setUpAll] — the asset itself is NEVER
/// downloaded. Pins that GitHub still serves the `digest` field in the
/// verifier's parse contract (`^sha256:[0-9a-fA-F]{64}$`, see
/// `ReleaseAssetVerifier` in `lib/data/services/updates/asset_verifier.dart`).
///
/// A GitHub-side digest format change would otherwise flip the verifier's
/// fail-closed policy into "every future update rejected", so this gate
/// catches it early.
///
/// Skip-never-fail on network: any non-200/exception (or missing payload)
/// calls `markTestSkipped` — the `export_live_gates_test.dart` best-effort
/// convention. Windows-safe: pure `package:http`, no shell-outs, no files.
///
/// Live-verified 2026-10-02 against the real v1.30.0 release:
/// - `ClipMind-Setup-1.30.0.exe` → `sha256:fc3c3acd…a4e7`
/// - `clipmind-windows-v1.30.0.zip` → `sha256:addcf11a…a3fe`
/// (GitHub auto-populates `digest` server-side on upload; no workflow
/// emission step needed.)
void main() {
  const apiUrl =
      'https://api.github.com/repos/Shuash11/clipmind/releases/latest';
  final digestContract = RegExp(r'^sha256:[0-9a-fA-F]{64}$');

  Map<String, dynamic>? releaseJson;
  String? skipReason;

  /// Picks the update asset the checker would install: first `.exe`,
  /// then `.zip`. Returns null when neither exists.
  Map<String, dynamic>? pickAsset(List<dynamic> assets) {
    final typed = assets.whereType<Map<String, dynamic>>().toList();
    for (final suffix in ['.exe', '.zip']) {
      for (final asset in typed) {
        if ((asset['name'] as String? ?? '').endsWith(suffix)) {
          return asset;
        }
      }
    }
    return null;
  }

  setUpAll(() async {
    try {
      final response = await http
          .get(
            Uri.parse(apiUrl),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'clipmind/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        skipReason = 'GitHub API HTTP ${response.statusCode}';
        return;
      }
      releaseJson = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      skipReason = 'GitHub API unreachable: $e';
    }
  });

  group('release digest live gate (API-only, best effort)', () {
    test(
      'latest release asset carries a verifier-compatible sha256 digest',
      timeout: const Timeout(Duration(minutes: 1)),
      () async {
        if (skipReason != null || releaseJson == null) {
          markTestSkipped(skipReason ?? 'GitHub API unreachable');
          return;
        }
        final assets = releaseJson!['assets'] as List<dynamic>? ?? [];
        if (assets.isEmpty) {
          markTestSkipped('latest release has no assets');
          return;
        }
        final asset = pickAsset(assets);
        if (asset == null) {
          markTestSkipped('latest release has no .exe/.zip asset');
          return;
        }
        final downloadUrl =
            asset['browser_download_url'] as String? ?? '';
        expect(
          downloadUrl,
          isNotEmpty,
          reason: 'asset ${asset['name']} has no browser_download_url',
        );
        final digest = asset['digest'] as String?;
        expect(
          digest,
          isNotNull,
          reason: 'asset ${asset['name']} carries no digest field',
        );
        expect(
          digest!,
          matches(digestContract),
          reason:
              'asset ${asset['name']} digest "$digest" breaks the '
              'verifier contract ^sha256:[0-9a-fA-F]{64}\$',
        );
      },
    );
  });
}
