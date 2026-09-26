import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/ffmpeg/filter_escaping.dart';

void main() {
  group('FilterEscaping.escapeDrawtext', () {
    test('escapes single quotes', () {
      expect(FilterEscaping.escapeDrawtext("it's"), equals(r"it\'s"));
    });

    test('escapes colons', () {
      expect(FilterEscaping.escapeDrawtext('a:b'), equals(r'a\:b'));
    });

    test('escapes percent signs', () {
      expect(FilterEscaping.escapeDrawtext('100%'), equals(r'100\%'));
    });

    test('escapes backslashes first', () {
      expect(FilterEscaping.escapeDrawtext(r'a\b'), equals(r'a\\b'));
    });

    test('neutralises filtergraph injection attempt', () {
      const malicious = "Hello');scale=-1:-1";
      final escaped = FilterEscaping.escapeDrawtext(malicious);
      // The raw payload must not survive verbatim in the filter string.
      expect(escaped, isNot(equals(malicious)));
      // Colons and quotes are escaped so the filtergraph cannot break out.
      expect(escaped, contains(r"\'"));
      expect(escaped, contains(r'\:'));
      // Reconstructing a drawtext filter with the escaped value keeps a
      // single text= assignment (no extra unescaped filter separator).
      final filter = "drawtext=text='$escaped':fontsize=48";
      expect(filter, contains(r"Hello\'"));
    });

    test('plain text passes through unchanged', () {
      expect(FilterEscaping.escapeDrawtext('Hello World'), equals('Hello World'));
    });
  });

  group('FilterEscaping.validateColor', () {
    test('accepts valid #RRGGBB', () {
      expect(FilterEscaping.validateColor('#FFFFFF'), equals('#FFFFFF'));
      expect(FilterEscaping.validateColor('#00ff00'), equals('#00ff00'));
    });

    test('rejects named colors', () {
      expect(
        () => FilterEscaping.validateColor('red'),
        throwsA(isA<FilterValidationException>()),
      );
    });

    test('rejects short hex', () {
      expect(
        () => FilterEscaping.validateColor('#FFF'),
        throwsA(isA<FilterValidationException>()),
      );
    });

    test('rejects non-hex digits with clear message', () {
      expect(
        () => FilterEscaping.validateColor('#GGGGGG'),
        throwsA(
          isA<FilterValidationException>().having(
            (e) => e.message,
            'message',
            contains('#RRGGBB'),
          ),
        ),
      );
    });
  });

  group('FilterEscaping.validateImagePath', () {
    test('accepts plain relative path', () {
      expect(
        FilterEscaping.validateImagePath('watermark.png'),
        equals('watermark.png'),
      );
    });

    test('rejects empty path', () {
      expect(
        () => FilterEscaping.validateImagePath('  '),
        throwsA(isA<FilterValidationException>()),
      );
    });

    test('rejects path traversal', () {
      expect(
        () => FilterEscaping.validateImagePath('../secrets/key.png'),
        throwsA(
          isA<FilterValidationException>().having(
            (e) => e.message,
            'message',
            contains('traversal'),
          ),
        ),
      );
    });

    test('rejects absolute path outside project dir', () {
      expect(
        () => FilterEscaping.validateImagePath(
          r'C:\evil\wm.png',
          projectDir: r'C:\projects\clipmind\output',
        ),
        throwsA(isA<FilterValidationException>()),
      );
    });

    test('accepts absolute path inside project dir', () {
      expect(
        FilterEscaping.validateImagePath(
          r'C:\projects\clipmind\output\wm.png',
          projectDir: r'C:\projects\clipmind\output',
        ),
        equals(r'C:\projects\clipmind\output\wm.png'),
      );
    });
  });
}
