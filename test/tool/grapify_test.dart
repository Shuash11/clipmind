import 'package:flutter_test/flutter_test.dart';

import '../../tool/grapify.dart';

const _fixture = '''
import 'package:example/core.dart';

class ActiveLlmConfig {
  final String providerId;
  final String? model;

  const ActiveLlmConfig({required this.providerId, this.model});

  String describe() => providerId;
  String get label => providerId;
}

typedef ActiveProfileResolver = Future<ActiveLlmConfig?> Function();

abstract class Base extends Super with Mixin implements Face {
  void run();
}

TopLevelResult topLevelFn(String arg) {
  return TopLevelResult();
}
''';

void main() {
  group('extractSymbols', () {
    test('finds classes, members, getters, typedefs and functions', () {
      final symbols = extractSymbols(splitSourceLines(_fixture));
      final byName = {for (final s in symbols) s.name: s};

      final config = byName['ActiveLlmConfig']!;
      expect(config.kind, equals('class'));
      expect(config.line, equals(3));
      expect(config.fields, equals(['providerId', 'model']));
      final members = {
        for (final m in config.members) m.name: m.line,
      };
      expect(
        members.keys.any((name) => name.startsWith('ActiveLlmConfig(')),
        isTrue,
      );
      expect(members['describe()'], equals(9));
      expect(
        config.members
            .singleWhere((m) => m.name == 'label')
            .isGetter,
        isTrue,
      );

      final resolver = byName['ActiveProfileResolver']!;
      expect(resolver.kind, equals('typedef'));

      final base = byName['Base']!;
      expect(
        base.parents,
        equals('extends Super with Mixin implements Face'),
      );

      final fn = byName['topLevelFn']!;
      expect(fn.kind, equals('function'));
      expect(
        extractSymbols(splitSourceLines(_fixture))
            .firstWhere((s) => s.name == 'topLevelFn')
            .line,
        equals(19),
      );
    });

    test('skips imports and control-flow lookalikes', () {
      final symbols = extractSymbols(splitSourceLines('''
import 'package:example/core.dart';

void real() {
  if (true) {}
  for (var i = 0; i < 1; i++) {}
}
'''));
      expect(symbols.map((s) => s.name), equals(['real']));
    });

    test('normalizes CRLF before matching', () {
      final symbols = extractSymbols(
        splitSourceLines('class CrLf {\r\n  void run() {}\r\n}\r\n'),
      );
      expect(symbols.single.name, equals('CrLf'));
      expect(symbols.single.members.single.name, equals('run()'));
    });
  });

  group('renderFileSection', () {
    test('renders the compact one-line-per-symbol shape', () {
      final section = renderFileSection(
        'lib/data/x.dart',
        10,
        extractSymbols(splitSourceLines(_fixture)),
      );
      expect(section, contains('## lib/data/x.dart (10 lines)'));
      expect(
        section,
        contains('- L3  class ActiveLlmConfig (providerId, model)'),
      );
      expect(section, contains('typedef ActiveProfileResolver'));
      expect(section, contains('describe() L9'));
    });
  });

  group('walk helpers', () {
    test('generated files are skipped', () {
      expect(isGeneratedFile('a.g.dart'), isTrue);
      expect(isGeneratedFile('a.freezed.dart'), isTrue);
      expect(isGeneratedFile('a.dart'), isFalse);
    });

    test('layerOf groups lib subdirs and roots', () {
      expect(layerOf('lib/data/x.dart'), equals('data'));
      expect(layerOf('test/unit/x_test.dart'), equals('test'));
      expect(layerOf('tool/grapify.dart'), equals('tool'));
    });
  });
}
