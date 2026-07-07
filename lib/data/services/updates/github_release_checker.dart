import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'release_info.dart';

class GithubReleaseChecker {
  static const _repo = 'Shuash11/clipmind';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';
  static const _userAgent = 'clipmind/1.0';

  ReleaseInfo? _cachedRelease;

  Future<ReleaseInfo?> checkForUpdate() async {
    if (_cachedRelease != null) {
      return _cachedRelease;
    }

    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('GithubReleaseChecker: HTTP ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final parsed = _parseTag(tagName);
      if (parsed == null) {
        debugPrint('GithubReleaseChecker: failed to parse tag "$tagName"');
        return null;
      }

      final assets = json['assets'] as List<dynamic>? ?? [];
      String downloadUrl = '';
      if (assets.isNotEmpty) {
        final typed = assets.cast<Map<String, dynamic>>();
        final zip = typed.where(
          (a) => (a['name'] as String? ?? '').endsWith('.zip'),
        );
        final asset = zip.isNotEmpty ? zip.first : typed.first;
        downloadUrl = asset['browser_download_url'] as String? ?? '';
        if (downloadUrl.isEmpty) {
          debugPrint('GithubReleaseChecker: asset has no browser_download_url');
        }
      }

      _cachedRelease = ReleaseInfo(
        tagName: tagName,
        major: parsed.$1,
        minor: parsed.$2,
        patch: parsed.$3,
        releaseNotes: json['body'] as String? ?? '',
        downloadUrl: downloadUrl,
        publishedAt: DateTime.tryParse(
              json['published_at'] as String? ?? '',
            ) ??
            DateTime.now(),
      );
      return _cachedRelease;
    } catch (e) {
      debugPrint('GithubReleaseChecker: $e');
      return null;
    }
  }

  (int, int, int)? _parseTag(String tag) {
    var clean = tag.startsWith('v') ? tag.substring(1) : tag;
    final plusIdx = clean.indexOf('+');
    if (plusIdx >= 0) clean = clean.substring(0, plusIdx);
    final parts = clean.split('.');
    if (parts.length != 3) return null;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);
    if (major == null || minor == null || patch == null) return null;
    return (major, minor, patch);
  }

  bool isNewer(ReleaseInfo latest, String currentVersion) {
    final current = _parseTag(currentVersion);
    if (current == null) return false;
    if (latest.major > current.$1) return true;
    if (latest.major == current.$1 && latest.minor > current.$2) return true;
    if (latest.major == current.$1 &&
        latest.minor == current.$2 &&
        latest.patch > current.$3) {
      return true;
    }
    return false;
  }

  void clearCache() {
    _cachedRelease = null;
  }
}