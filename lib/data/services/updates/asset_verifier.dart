import 'dart:io';

import 'package:crypto/crypto.dart';

/// Outcome of verifying a downloaded release asset against the digest
/// published by GitHub's release-asset API.
class AssetVerificationResult {
  /// `ok` — hashes match; `no-digest` — asset carries no digest (fail-open);
  /// `malformed-digest` — digest is present but unparsable (fail-closed);
  /// `mismatch` — hashes differ (fail-closed).
  final String reason;
  final bool passed;
  final String? expectedDigest;
  final String? actualDigest;

  const AssetVerificationResult({
    required this.reason,
    required this.passed,
    this.expectedDigest,
    this.actualDigest,
  });
}

/// Verifies a downloaded update asset against GitHub's `digest` field
/// (format `sha256:<hex>`).
///
/// Policy: fail-closed on `mismatch` and `malformed-digest` (a malformed
/// digest on a release asset is suspicious and must not install);
/// fail-open only on `no-digest` for backward compatibility with releases
/// published before GitHub populated the field.
///
/// The file is hashed in 64 KB blocks via `RandomAccessFile.readSync`, so
/// even a large installer is never held in memory.
class ReleaseAssetVerifier {
  static const _chunkSize = 64 * 1024;
  static final _hexPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  const ReleaseAssetVerifier();

  AssetVerificationResult verify(File file, String? digest) {
    final raw = digest?.trim() ?? '';
    if (raw.isEmpty) {
      return const AssetVerificationResult(
        reason: 'no-digest',
        passed: true,
      );
    }

    final expected = _parseSha256Hex(raw);
    if (expected == null) {
      return AssetVerificationResult(
        reason: 'malformed-digest',
        passed: false,
        expectedDigest: raw,
      );
    }

    final actual = _hashFile(file);
    if (actual.toLowerCase() == expected.toLowerCase()) {
      return AssetVerificationResult(
        reason: 'ok',
        passed: true,
        expectedDigest: expected.toLowerCase(),
        actualDigest: actual.toLowerCase(),
      );
    }
    return AssetVerificationResult(
      reason: 'mismatch',
      passed: false,
      expectedDigest: expected.toLowerCase(),
      actualDigest: actual.toLowerCase(),
    );
  }

  /// Returns the normalized hex part, or null when [digest] is not a
  /// well-formed `sha256:<64 hex chars>` value.
  String? _parseSha256Hex(String digest) {
    final colon = digest.indexOf(':');
    if (colon <= 0) return null;
    if (digest.substring(0, colon).toLowerCase() != 'sha256') return null;
    final hex = digest.substring(colon + 1);
    if (!_hexPattern.hasMatch(hex)) return null;
    return hex;
  }

  String _hashFile(File file) {
    final output = _DigestCollector();
    final input = sha256.startChunkedConversion(output);
    final handle = file.openSync();
    try {
      while (true) {
        final chunk = handle.readSync(_chunkSize);
        if (chunk.isEmpty) break;
        input.add(chunk);
      }
    } finally {
      handle.closeSync();
    }
    input.close();
    return output.digest.toString();
  }
}

class _DigestCollector implements Sink<Digest> {
  late Digest digest;

  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}
