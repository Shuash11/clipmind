import 'dart:io';

import 'package:clipmind/data/services/fonts/font_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FontResolver.catalog', () {
    test('catalogues the 6 OFL families with Regular files', () {
      final resolver = FontResolver(
        loadAsset: (_) async => ByteData(0),
        supportDir: () async => Directory.systemTemp,
      );
      expect(FontResolver.catalog, hasLength(6));
      expect(
        FontResolver.catalog.map((f) => f.id),
        equals([
          'inter',
          'montserrat',
          'roboto',
          'lato',
          'source_code_pro',
          'eb_garamond',
        ]),
      );
      for (final font in FontResolver.catalog) {
        expect(font.label, isNotEmpty);
        expect(font.fileName, endsWith('_regular.ttf'));
      }
      expect(resolver.cachedPath('inter'), isNull);
    });

    test('isKnownFamily matches the catalog', () {
      expect(FontResolver.isKnownFamily('roboto'), isTrue);
      expect(FontResolver.isKnownFamily('eb_garamond'), isTrue);
      expect(FontResolver.isKnownFamily('comic-sans'), isFalse);
    });
  });

  group('FontResolver.resolve', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clipmind_fonts_');
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    ByteData bytes(String text) =>
        ByteData.sublistView(Uint8List.fromList(text.codeUnits));

    test('extracts the asset on first use and caches the path', () async {
      var loads = 0;
      final resolver = FontResolver(
        loadAsset: (key) async {
          loads++;
          expect(key, equals('assets/fonts/inter_regular.ttf'));
          return bytes('fake-ttf');
        },
        supportDir: () async => tmp,
      );

      final first = await resolver.resolve('inter');
      expect(first, equals('${tmp.path}/fonts/inter_regular.ttf'));
      expect(File(first!).existsSync(), isTrue);
      expect(resolver.cachedPath('inter'), equals(first));

      final second = await resolver.resolve('inter');
      expect(second, equals(first));
      expect(loads, equals(1));
    });

    test('reuses an already-extracted file without loading', () async {
      final existing = File('${tmp.path}/fonts/roboto_regular.ttf');
      await existing.parent.create(recursive: true);
      await existing.writeAsString('pre-existing');
      final resolver = FontResolver(
        loadAsset: (_) async {
          fail('must not load when the file already exists');
        },
        supportDir: () async => tmp,
      );

      expect(await resolver.resolve('roboto'), equals(existing.path));
    });

    test('unknown family yields null without touching seams', () async {
      final resolver = FontResolver(
        loadAsset: (_) async {
          fail('must not load for unknown families');
        },
        supportDir: () async {
          fail('must not resolve dirs for unknown families');
        },
      );
      expect(await resolver.resolve('nope'), isNull);
    });

    test('missing asset file yields null (not yet downloaded)', () async {
      final resolver = FontResolver(
        loadAsset: (_) async {
          throw FlutterError('Unable to load asset');
        },
        supportDir: () async => tmp,
      );
      expect(await resolver.resolve('lato'), isNull);
      expect(resolver.cachedPath('lato'), isNull);
    });

    test('invalidateCache forces re-resolution', () async {
      var loads = 0;
      final resolver = FontResolver(
        loadAsset: (_) async {
          loads++;
          return bytes('fake-ttf');
        },
        supportDir: () async => tmp,
      );
      // Sound-preset ids are not font families.
      expect(await resolver.resolve('hum'), isNull);
      expect(loads, equals(0));
      final mont = await resolver.resolve('montserrat');
      expect(mont, isNotNull);
      resolver.invalidateCache();
      expect(resolver.cachedPath('montserrat'), isNull);
      // File now exists on disk, so no reload is needed.
      expect(await resolver.resolve('montserrat'), equals(mont));
      expect(loads, equals(1));
    });
  });
}
