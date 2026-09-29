import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// One bundled OFL font family (Regular weight).
///
/// The actual `.ttf` files live under `assets/fonts/` (committed by the
/// frontend track); the OFL permits bundling with the `OFL.txt` license
/// alongside each family.
class BundledFont {
  /// Stable panel id (e.g. `inter`).
  final String id;

  /// Display label (e.g. `Inter`).
  final String label;

  /// Asset file name under `assets/fonts/` (e.g. `inter_regular.ttf`).
  final String fileName;

  const BundledFont({
    required this.id,
    required this.label,
    required this.fileName,
  });
}

/// Resolves bundled-font families to FFmpeg `fontfile` paths.
///
/// First use extracts the asset via `rootBundle` into the app-support
/// directory and caches the filesystem path (the `ffmpeg_binary_resolver`
/// pattern); later calls hit the cache. Returns null when the family is
/// unknown or its font file is missing (not yet downloaded) — graceful
/// degradation, never throws.
class FontResolver {
  static const List<BundledFont> catalog = [
    BundledFont(
      id: 'inter',
      label: 'Inter',
      fileName: 'inter_regular.ttf',
    ),
    BundledFont(
      id: 'montserrat',
      label: 'Montserrat',
      fileName: 'montserrat_regular.ttf',
    ),
    BundledFont(
      id: 'roboto',
      label: 'Roboto',
      fileName: 'roboto_regular.ttf',
    ),
    BundledFont(id: 'lato', label: 'Lato', fileName: 'lato_regular.ttf'),
    BundledFont(
      id: 'source_code_pro',
      label: 'Source Code Pro',
      fileName: 'source_code_pro_regular.ttf',
    ),
    BundledFont(
      id: 'eb_garamond',
      label: 'EB Garamond',
      fileName: 'eb_garamond_regular.ttf',
    ),
  ];

  final Map<String, String> _cache = {};

  /// Asset loader seam (defaults to [rootBundle.load]) for unit tests.
  final Future<ByteData> Function(String key) _loadAsset;

  /// App-support directory seam for unit tests (path_provider hangs in
  /// the test sandbox, so tests inject a temp dir).
  final Future<Directory> Function() _supportDir;

  FontResolver({
    Future<ByteData> Function(String key)? loadAsset,
    Future<Directory> Function()? supportDir,
  }) : _loadAsset = loadAsset ?? rootBundle.load,
       _supportDir = supportDir ?? getApplicationSupportDirectory;

  /// True for the 6 catalogued family ids.
  static bool isKnownFamily(String familyId) {
    return catalog.any((f) => f.id == familyId);
  }

  /// Cached filesystem path for [familyId], or null when not yet
  /// resolved.
  String? cachedPath(String familyId) => _cache[familyId];

  /// Resolve [familyId] to a cached filesystem `.ttf` path.
  ///
  /// Extracts the bundled asset on first use; returns null for unknown
  /// families, missing asset files, or any IO failure.
  Future<String?> resolve(String familyId) async {
    final cached = _cache[familyId];
    if (cached != null) return cached;
    BundledFont? font;
    for (final entry in catalog) {
      if (entry.id == familyId) {
        font = entry;
        break;
      }
    }
    if (font == null) return null;
    try {
      final dir = await _supportDir();
      final out = File('${dir.path}/fonts/${font.fileName}');
      if (await out.exists()) {
        return _cache[familyId] = out.path;
      }
      final data = await _loadAsset('assets/fonts/${font.fileName}');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      return _cache[familyId] = out.path;
    } catch (e, s) {
      debugPrint('FontResolver error: $e\n$s');
      return null;
    }
  }

  void invalidateCache() => _cache.clear();
}
