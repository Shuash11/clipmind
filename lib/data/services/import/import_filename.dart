import 'package:dio/dio.dart';

/// Derives the on-disk filename for a direct-URL download.
///
/// HTTP precedence: Content-Disposition `filename*` (RFC 5987) →
/// `filename` → last URL path segment → `video`. The candidate is then
/// hardened into a portable filename: path separators and `..` cannot
/// escape the target directory, control characters and quoted-string
/// artifacts are stripped, Windows-forbidden characters are replaced,
/// the stem is capped, and reserved device names (`CON`, `LPT1`, …) are
/// renamed.
class ImportFilename {
  const ImportFilename();

  static const _fallbackStem = 'video';
  static const _maxStemLength = 100;

  static const _extensionByContentType = <String, String>{
    'video/mp4': '.mp4',
    'video/webm': '.webm',
    'video/quicktime': '.mov',
    'video/x-matroska': '.mkv',
  };

  static const _reservedStems = <String>{
    'CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5',
    'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5',
    'LPT6', 'LPT7', 'LPT8', 'LPT9',
  };

  static final _filenameStarPattern = RegExp(
    r'filename\*\s*=\s*([^;]+)',
    caseSensitive: false,
  );
  static final _plainFilenamePattern = RegExp(
    r'filename(?!\*)\s*=\s*(?:"([^"]*)"|([^;]+))',
    caseSensitive: false,
  );
  static final _rfc5987PrefixPattern = RegExp(
    "^utf-8'[^']*'",
    caseSensitive: false,
  );

  /// Resolves the filename for a download described by [headers] and
  /// [requestUri].
  ///
  /// A candidate with its own extension keeps it; a candidate without one
  /// takes the extension mapped from the response Content-Type, else
  /// `.mp4`. Never returns an empty name or one containing a path
  /// separator.
  String resolve({required Headers headers, required Uri requestUri}) {
    final candidate =
        _fromContentDisposition(headers) ??
        _fromUrlPath(requestUri) ??
        _fallbackStem;
    final sanitized = _sanitize(candidate);
    return _ensureExtension(
      sanitized,
      headers.value(Headers.contentTypeHeader),
    );
  }

  /// `filename*` (RFC 5987), e.g. `UTF-8''caf%C3%A9%20clip.mp4`.
  String? _fromContentDisposition(Headers headers) {
    final value = headers.value('content-disposition');
    if (value == null || value.trim().isEmpty) return null;
    return _filenameStar(value) ?? _plainFilename(value);
  }

  String? _filenameStar(String value) {
    final match = _filenameStarPattern.firstMatch(value);
    if (match == null) return null;
    var encoded = match.group(1)!.trim();
    // Some servers quote the ext-value even though RFC 5987 requires it
    // unquoted; tolerate both.
    if (encoded.length >= 2 &&
        encoded.startsWith('"') &&
        encoded.endsWith('"')) {
      encoded = encoded.substring(1, encoded.length - 1);
    }
    // charset'language'value — the common `UTF-8''` prefix is covered.
    encoded = encoded.replaceFirst(_rfc5987PrefixPattern, '');
    final decoded = _decodePercent(encoded).trim();
    return decoded.isEmpty ? null : decoded;
  }

  String? _plainFilename(String value) {
    final match = _plainFilenamePattern.firstMatch(value);
    if (match == null) return null;
    final raw = (match.group(1) ?? match.group(2) ?? '').trim();
    return raw.isEmpty ? null : raw;
  }

  String? _fromUrlPath(Uri requestUri) {
    if (requestUri.pathSegments.isEmpty) return null;
    final last = requestUri.pathSegments.last.trim();
    return last.isEmpty ? null : last;
  }

  String _decodePercent(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      // Malformed percent-escapes: keep the raw text rather than failing
      // the whole import on a bad header.
      return value;
    }
  }

  /// Hardens [raw] into a single filename component. Returns a non-empty
  /// name whose extension (if any) survives untrimmed.
  String _sanitize(String raw) {
    var name = raw.trim();
    // Control characters (including NUL/newlines) and quoted-string artifacts.
    name = name.replaceAll(RegExp(r'[\x00-\x1f\x7f"]'), '');
    // Path smuggling: separators become literals, traversal dies here.
    name = name.replaceAll(RegExp(r'[\\/]'), '_');
    name = name.replaceAll('..', '_');
    // Windows-forbidden characters.
    name = name.replaceAll(RegExp(r'[<>:"|?*]'), '_');

    // Split the extension first so stem hardening cannot eat it.
    var stem = name;
    var extension = '';
    final dot = name.lastIndexOf('.');
    if (dot >= 0) {
      stem = name.substring(0, dot);
      extension = name.substring(dot);
    }
    final safe = '${_hardenStem(stem)}$extension'
        .replaceAll(RegExp(r'[. ]+$'), '');
    return safe.isEmpty ? _fallbackStem : safe;
  }

  /// Trims trailing dots/spaces, caps the length, guarantees non-empty,
  /// and renames Windows reserved device names.
  String _hardenStem(String stem) {
    var result = stem.replaceAll(RegExp(r'[. ]+$'), '');
    if (result.length > _maxStemLength) {
      result = result
          .substring(0, _maxStemLength)
          .replaceAll(RegExp(r'[. ]+$'), '');
    }
    if (result.isEmpty) result = _fallbackStem;
    if (_reservedStems.contains(result.toUpperCase())) {
      result = '${result}_import';
    }
    return result;
  }

  String _ensureExtension(String name, String? contentType) {
    if (_hasExtension(name)) return name;
    return '$name${_extensionFor(contentType)}';
  }

  bool _hasExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 && dot < name.length - 1;
  }

  String _extensionFor(String? contentType) {
    if (contentType == null) return '.mp4';
    final mediaType = contentType.split(';').first.trim().toLowerCase();
    return _extensionByContentType[mediaType] ?? '.mp4';
  }
}
