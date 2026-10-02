import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/updates/asset_verifier.dart';

void main() {
  group('ReleaseAssetVerifier', () {
    late Directory tmp;
    const verifier = ReleaseAssetVerifier();

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_verify_');
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    Future<File> writeBytes(List<int> bytes, [String name = 'asset.bin']) {
      final file = File('${tmp.path}/$name');
      return file.writeAsBytes(bytes);
    }

    test('matching digest passes with reason ok', () async {
      final file = await writeBytes([1, 2, 3, 4, 5]);
      final hex = sha256.convert([1, 2, 3, 4, 5]).toString();

      final result = verifier.verify(file, 'sha256:$hex');

      expect(result.passed, isTrue);
      expect(result.reason, 'ok');
      expect(result.expectedDigest, hex);
      expect(result.actualDigest, hex);
    });

    test('digest compare is case-insensitive on hex and algorithm', () async {
      final file = await writeBytes([9, 8, 7]);
      final hex = sha256.convert([9, 8, 7]).toString().toUpperCase();

      final result = verifier.verify(file, 'SHA256:$hex');

      expect(result.passed, isTrue);
      expect(result.reason, 'ok');
    });

    test('absent digest fails open with reason no-digest', () async {
      final file = await writeBytes([1, 2, 3]);

      for (final digest in <String?>[null, '', '   ']) {
        final result = verifier.verify(file, digest);
        expect(result.passed, isTrue, reason: 'digest: $digest');
        expect(result.reason, 'no-digest', reason: 'digest: $digest');
      }
    });

    test('malformed digests fail closed', () async {
      final file = await writeBytes([1, 2, 3]);
      const validHex =
          '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';

      final malformed = [
        'not-a-digest',
        'md5:$validHex',
        'sha256:xyz',
        'sha256:abc', // too short
        'sha256:$validHex' '00', // too long
        'sha256', // missing separator
        ':deadbeef', // missing algorithm
      ];

      for (final digest in malformed) {
        final result = verifier.verify(file, digest);
        expect(result.passed, isFalse, reason: 'digest: $digest');
        expect(result.reason, 'malformed-digest', reason: 'digest: $digest');
      }
    });

    test('mismatched digest fails closed with both hashes reported',
        () async {
      final file = await writeBytes([1, 2, 3]);
      final actual = sha256.convert([1, 2, 3]).toString();
      final wrong = sha256.convert([4, 5, 6]).toString();
      expect(wrong, isNot(actual));

      final result = verifier.verify(file, 'sha256:$wrong');

      expect(result.passed, isFalse);
      expect(result.reason, 'mismatch');
      expect(result.expectedDigest, wrong);
      expect(result.actualDigest, actual);
    });

    test('streams a multi-megabyte file without loading it at once',
        () async {
      // 6 MB of deterministic pseudo-random bytes: spans many 64 KB
      // blocks so the chunked path is genuinely exercised.
      final random = Random(42);
      final bytes = List<int>.generate(6 * 1024 * 1024, (_) => random.nextInt(256));
      final file = await writeBytes(bytes, 'large.bin');
      final hex = sha256.convert(bytes).toString();

      final result = verifier.verify(file, 'sha256:$hex');

      expect(result.passed, isTrue);
      expect(result.reason, 'ok');
      expect(result.actualDigest, hex);
    });
  });
}
