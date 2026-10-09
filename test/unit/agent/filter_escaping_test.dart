import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/services/ffmpeg/filter_escaping.dart';

void main() {
  group('FilterEscaping.escapeDrawtext', () {
    test('escapes single quotes', () {
      expect(FilterEscaping.escapeDrawtext("it's"), equals(r"it\\\'s"));
    });

    test('escapes colons', () {
      expect(FilterEscaping.escapeDrawtext('a:b'), equals(r'a\\:b'));
    });

    test('escapes percent signs', () {
      expect(FilterEscaping.escapeDrawtext('100%'), equals(r'100\\%'));
    });

    test('escapes backslashes before anything else', () {
      expect(FilterEscaping.escapeDrawtext(r'a\b'), equals(r'a\\\\b'));
    });

    test('escapes interior spaces', () {
      expect(FilterEscaping.escapeDrawtext('a b c'), equals(r'a\\ b\\ c'));
    });

    test('escapes boundary spaces so they survive trimming', () {
      expect(
        FilterEscaping.escapeDrawtext('  pad  '),
        equals(r'\\ \\ pad\\ \\ '),
      );
    });

    test('escapes graph specials at level two', () {
      expect(FilterEscaping.escapeDrawtext('[x],y;z'), equals(r'\[x\]\,y\;z'));
    });

    test('real newlines pass through unchanged', () {
      expect(
        FilterEscaping.escapeDrawtext('line1\nline2'),
        equals('line1\nline2'),
      );
    });

    test('neutralises filtergraph injection attempt', () {
      const malicious = "Hello');scale=-1:-1";
      final escaped = FilterEscaping.escapeDrawtext(malicious);
      // Exact two-level form: quote/colon escaped at level one, then the
      // escape backslashes doubled and the ';' graph separator escaped.
      expect(escaped, equals(r"Hello\\\')\;scale=-1\\:-1"));
      // The raw payload must not survive verbatim.
      expect(escaped, isNot(equals(malicious)));
      // Every quote carries its escape backslash.
      expect("'".allMatches(escaped).length, equals(1));
      expect(r"\'".allMatches(escaped).length, equals(1));
      // The ';' cannot split the filtergraph chain (escaped at level two).
      expect(escaped.contains(r'\;'), isTrue);
      expect(escaped.contains(');scale'), isFalse);
      // The complete option keeps exactly one text= assignment.
      final filter =
          'drawtext=${FilterEscaping.drawtextTextOption(malicious)}:fontsize=48';
      final option = filter.substring('drawtext='.length);
      expect('text='.allMatches(option).length, equals(1));
    });
  });

  group('FilterEscaping.drawtextTextOption', () {
    test('wraps plain text with expansion disabled', () {
      expect(
        FilterEscaping.drawtextTextOption('plain'),
        equals('text=plain:expansion=none'),
      );
    });

    test('apostrophe text uses the unquoted two-level form', () {
      expect(
        FilterEscaping.drawtextTextOption("it's"),
        equals(r"text=it\\\'s:expansion=none"),
      );
    });

    test('percent and spaces render verbatim under expansion=none', () {
      expect(
        FilterEscaping.drawtextTextOption('50% off'),
        equals(r'text=50\\%\\ off:expansion=none'),
      );
    });

    test('always ends with the expansion=none suffix', () {
      for (final text in ['a b', '[x],y;z', 'line1\nline2']) {
        expect(
          FilterEscaping.drawtextTextOption(text),
          endsWith(':expansion=none'),
        );
      }
    });
  });

  group('FilterEscaping.escapeFontFilePath', () {
    test('plain forward-slash path passes through unchanged', () {
      expect(
        FilterEscaping.escapeFontFilePath('/fonts/x.ttf'),
        equals('/fonts/x.ttf'),
      );
    });

    test('windows drive path gets the two-level escaped form', () {
      expect(
        FilterEscaping.escapeFontFilePath(r'C:\fonts\inter_regular.ttf'),
        equals(r'C\\:/fonts/inter_regular.ttf'),
      );
    });

    test('backslashes are normalized to forward slashes', () {
      expect(
        FilterEscaping.escapeFontFilePath(r'\fonts\x.ttf'),
        equals('/fonts/x.ttf'),
      );
    });

    test('worst case: apostrophe, brackets, comma and semicolon', () {
      expect(
        FilterEscaping.escapeFontFilePath(r"C:\Users\O'Brien [a],b;c\f.ttf"),
        equals(r"C\\:/Users/O\\\'Brien \[a\]\,b\;c/f.ttf"),
      );
    });

    test('percent is intentionally not escaped', () {
      expect(
        FilterEscaping.escapeFontFilePath('/fonts/100%.ttf'),
        equals('/fonts/100%.ttf'),
      );
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
