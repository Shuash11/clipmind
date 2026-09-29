import 'dart:io';

/// Generates the committed code-graph slices under `docs/codegraph/`.
///
/// Run: `dart run tool/grapify.dart` (pure `dart:io`, no shell-out,
/// Windows-safe). Deterministic apart from the staleness timestamp.
///
/// The slices are a navigation aid, not a resolved call graph:
/// relationships are `extends`/`implements`/`with` from the class line
/// plus the member list with line refs. Generated files (`*.g.dart`,
/// `*.freezed.dart`) are skipped everywhere.
void main() {
  final root = Directory.current.path;
  final files = _dartFiles(root);
  final layers = _groupByLayer(files);
  final stamp = _timestamp();

  final outDir = Directory('$root/docs/codegraph');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final summaries = <_LayerSummary>[];
  for (final entry in layers.entries) {
    var lines = 0;
    final sections = <String>[];
    for (final file in entry.value) {
      final source = File(file).readAsStringSync();
      final fileLines = splitSourceLines(source);
      lines += fileLines.length;
      final relative = _relative(root, file);
      sections.add(renderFileSection(
        relative,
        fileLines.length,
        extractSymbols(fileLines),
      ));
    }
    final title = entry.key == 'test' || entry.key == 'tool'
        ? entry.key
        : 'lib/${entry.key}';
    final body = StringBuffer()
      ..writeln(
        '# Code Graph — $title '
        '(${entry.value.length} files, ${_formatCount(lines)} lines; '
        'generated $stamp; DO NOT EDIT)',
      )
      ..writeln(
        '_Generated files (*.g.dart, *.freezed.dart) excluded. '
        'Relationships are extends/implements/with hints + member line '
        'refs — navigate, then read the file for details._',
      )
      ..writeln()
      ..writeAll(sections, '\n');
    File('${outDir.path}/${entry.key}.md')
        .writeAsStringSync('${body.toString().trimRight()}\n');
    summaries.add(_LayerSummary(entry.key, entry.value.length, lines));
  }

  File('${outDir.path}/README.md').writeAsStringSync(_readme(summaries, stamp));
  stdout.writeln(
    'grapify: wrote ${summaries.length} slices '
    '(${summaries.fold<int>(0, (sum, s) => sum + s.lines)} lines indexed).',
  );
}

/// A 2-space-indented member (method incl. constructors, or getter).
class GrapifyMember {
  const GrapifyMember(this.name, this.line, {this.isGetter = false});

  final String name;
  final int line;
  final bool isGetter;
}

/// A column-0 declaration: class/enum/mixin/extension/typedef or a
/// top-level function.
class GrapifySymbol {
  GrapifySymbol(this.kind, this.name, this.line, {this.parents = ''});

  final String kind;
  final String name;
  final int line;
  final String parents;
  final List<String> fields = <String>[];
  final List<GrapifyMember> members = <GrapifyMember>[];
}

/// Generated sources are noise for navigation — skip them everywhere.
bool isGeneratedFile(String path) =>
    path.endsWith('.g.dart') || path.endsWith('.freezed.dart');

/// Split source into lines, normalizing CRLF/CR first: the extractor's
/// `$`-anchored patterns never match a trailing `\r` (`.` excludes it),
/// and the repo mixes LF and CRLF files.
List<String> splitSourceLines(String source) =>
    source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

/// Layer key: `lib/<layer>/…` → `<layer>`; anything else → top segment
/// (`test`, `tool`).
String layerOf(String relativePath) {
  final parts = relativePath.replaceAll(r'\', '/').split('/');
  if (parts.length > 2 && parts[0] == 'lib') return parts[1];
  return parts[0];
}

/// Extract column-0 declarations plus their 2-space members from lines.
List<GrapifySymbol> extractSymbols(List<String> lines) {
  final symbols = <GrapifySymbol>[];
  GrapifySymbol? current;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty || line.startsWith(' ') || line.startsWith('\t')) {
      final member =
          _parseMember(line, i + 1, enclosing: current?.name);
      if (member == null) continue;
      if (member.isField) {
        current?.fields.add(member.name);
      } else {
        current?.members
            .add(GrapifyMember(member.name, member.line,
                isGetter: member.isGetter));
      }
      continue;
    }
    final symbol = _parseDeclaration(line, i + 1);
    if (symbol == null) {
      current = null;
      continue;
    }
    symbols.add(symbol);
    current = symbol.kind == 'function' ? null : symbol;
  }
  return symbols;
}

/// One rendered `## file` section with `- L…` symbol lines.
String renderFileSection(
  String relativePath,
  int totalLines,
  List<GrapifySymbol> symbols,
) {
  final out = StringBuffer()
    ..writeln('## $relativePath ($totalLines lines)');
  for (final symbol in symbols) {
    final detail = StringBuffer(symbol.kind);
    if (symbol.kind == 'class' ||
        symbol.kind == 'enum' ||
        symbol.kind == 'mixin' ||
        symbol.kind == 'extension') {
      detail.write(' ${symbol.name}');
      if (symbol.parents.isNotEmpty) detail.write(' ${symbol.parents}');
      if (symbol.fields.isNotEmpty) {
        detail.write(' (${symbol.fields.take(8).join(', ')})');
      }
    } else {
      detail.write(' ${symbol.name}');
    }
    if (symbol.members.isNotEmpty) {
      detail.write(' — ');
      detail.write(symbol.members
          .map((m) => '${m.name} L${m.line}')
          .join(', '));
    }
    out.writeln('- L${symbol.line}  $detail');
  }
  return out.toString();
}

final _declPattern = RegExp(
  r'^(?:(?:abstract|final|sealed|base|mixin)\s+)*'
  r'(class|mixin|enum|extension|typedef)\b\s*(\w+)?(.*)$',
);
final _importPattern =
    RegExp(r'^(?:import|export|part|library)\b');
final _controlPattern =
    RegExp(r'^(?:if|for|while|switch|catch|return|await|throw)\b');

GrapifySymbol? _parseDeclaration(String line, int lineNumber) {
  if (_importPattern.hasMatch(line)) return null;
  final decl = _declPattern.firstMatch(line);
  if (decl != null) {
    final kind = decl.group(1)!;
    final name = decl.group(2) ?? '';
    if (name.isEmpty) return null;
    return GrapifySymbol(kind, name, lineNumber,
        parents: _parents(decl.group(3) ?? ''));
  }
  // Top-level function: `ReturnType name(` (excluding control keywords).
  if (_controlPattern.hasMatch(line)) return null;
  final fn = RegExp(r'^[\w<>?,\s\.]+\s+([A-Za-z_]\w*)\s*\(')
      .firstMatch(line);
  if (fn == null) return null;
  return GrapifySymbol('function', fn.group(1)!, lineNumber);
}

/// Keep `extends`/`implements`/`with` (the call-graph HINT); drop bodies.
String _parents(String rest) {
  final cleaned = rest.split('//').first.trim();
  final match = RegExp(
    r'^(?:extends\s+([\w<>,\s]+?))?'
    r'(?:\s+implements\s+([\w<>,\s]+?))?'
    r'(?:\s+with\s+([\w<>,\s]+?))?'
    r'\s*(?:\{|$)',
  ).firstMatch(cleaned);
  if (match == null) return '';
  final parts = <String>[];
  if ((match.group(1) ?? '').trim().isNotEmpty) {
    parts.add('extends ${match.group(1)!.trim()}');
  }
  if ((match.group(2) ?? '').trim().isNotEmpty) {
    parts.add('implements ${match.group(2)!.trim()}');
  }
  if ((match.group(3) ?? '').trim().isNotEmpty) {
    parts.add('with ${match.group(3)!.trim()}');
  }
  return parts.join(' ');
}

final _skipMemberPattern = RegExp(
  r'^(?://|\*|/\*|\} |\}|\]|\)|@|'
  r'assert\s|break|case\s|catch|continue|do\s|else|'
  r'for\s|if\s|return\s|await\s|switch\s|throw\s|try|while\s|'
  r'import\s|export\s|part\s|library\s)',
);
final _constCtorPattern = RegExp(r'^const\s+([A-Za-z_]\w*)');
final _memberPattern = RegExp(
  r'^(?:static\s+)?(?:[\w<>?,\s\.]+\s+)?(?:(get)\s+)?([A-Za-z_]\w*)',
);

({String name, int line, bool isGetter, bool isField})? _parseMember(
  String line,
  int lineNumber, {
  String? enclosing,
}) {
  if (!line.startsWith('  ') || line.startsWith('   ')) return null;
  var trimmed = line.trim();
  if (trimmed.isEmpty || _skipMemberPattern.hasMatch(trimmed)) return null;
  // `const Name(` is a constructor declaration only when Name is the
  // enclosing class (or after `factory`); otherwise it is invocation
  // noise and stays skipped.
  final ctor = _constCtorPattern.firstMatch(trimmed);
  if (ctor != null) {
    final target = ctor.group(1)!;
    if (target == 'factory' || target == enclosing) {
      trimmed = trimmed.substring('const'.length).trimLeft();
    } else {
      return null;
    }
  }
  final match = _memberPattern.firstMatch(trimmed);
  if (match == null) return null;
  final name = match.group(2)!;
  if (match.group(1) != null) {
    return (name: name, line: lineNumber, isGetter: true, isField: false);
  }
  final after = trimmed.substring(match.end).trimLeft();
  if (after.startsWith('(')) {
    final signature = _signature(trimmed, name);
    return (
      name: signature,
      line: lineNumber,
      isGetter: false,
      isField: false
    );
  }
  // No parens: field (`final X name;`) or bare getter-ish. Fields feed
  // the class preview; getters join the member list.
  if (trimmed.endsWith(';') && !trimmed.contains('=>')) {
    return (name: name, line: lineNumber, isGetter: false, isField: true);
  }
  return (name: name, line: lineNumber, isGetter: true, isField: false);
}

/// `name` plus the inline parameter list: body fragments (`=>`, `{`,
/// `;`, trailing `async`) are cut so slices stay one line per symbol.
String _signature(String trimmed, String name) {
  final start = trimmed.indexOf('$name(');
  if (start < 0) return name;
  var text = trimmed.substring(start);
  for (final stop in ['=>', '{', ';']) {
    final index = text.indexOf(stop);
    if (index >= 0) text = text.substring(0, index).trimRight();
  }
  text = text.replaceAll(RegExp(r'\s+async\s*$'), '');
  var opens = 0;
  var closes = 0;
  for (final rune in text.runes) {
    if (rune == 0x28) opens++;
    if (rune == 0x29) closes++;
  }
  if (closes < opens) text = '$text…)';
  const cap = 80;
  if (text.length > cap) text = '${text.substring(0, cap)}…';
  return text;
}

List<String> _dartFiles(String root) {
  final files = <String>[];
  for (final dir in ['lib', 'test', 'tool']) {
    final base = Directory('$root/$dir');
    if (!base.existsSync()) continue;
    for (final entity in base.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (isGeneratedFile(entity.path)) continue;
      files.add(entity.path);
    }
  }
  files.sort();
  return files;
}

Map<String, List<String>> _groupByLayer(List<String> files) {
  final layers = <String, List<String>>{};
  for (final file in files) {
    final relative = _relative(Directory.current.path, file);
    layers.putIfAbsent(layerOf(relative), () => []).add(relative);
  }
  return Map.fromEntries(
    layers.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

String _relative(String root, String path) {
  final normalizedRoot = root.replaceAll(r'\', '/');
  final normalized = path.replaceAll(r'\', '/');
  if (normalized.startsWith('$normalizedRoot/')) {
    return normalized.substring(normalizedRoot.length + 1);
  }
  return normalized;
}

String _timestamp() {
  final now = DateTime.now();
  String pad(int v, [int width = 2]) =>
      v.toString().padLeft(width, '0');
  return '${now.year}-${pad(now.month)}-${pad(now.day)}'
      'T${pad(now.hour)}:${pad(now.minute)}';
}

String _formatCount(int lines) {
  final text = lines.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

class _LayerSummary {
  const _LayerSummary(this.layer, this.files, this.lines);

  final String layer;
  final int files;
  final int lines;
}

String _readme(List<_LayerSummary> summaries, String stamp) {
  final totalFiles =
      summaries.fold<int>(0, (sum, s) => sum + s.files);
  final totalLines =
      summaries.fold<int>(0, (sum, s) => sum + s.lines);
  final rows = summaries
      .map((s) =>
          '| `${s.layer}` | ${s.files} | ${_formatCount(s.lines)} | '
          '`docs/codegraph/${s.layer}.md` |')
      .join('\n');
  return '''
# ClipMind Code Graph (generated $stamp; DO NOT EDIT)

Per-layer navigation slices — load only what you need (~1–4k tokens
each vs ~10–25k for reading the layer's files). Generated files
(`*.g.dart`, `*.freezed.dart`) are excluded from every slice.

Regenerate: `dart run tool/grapify.dart`
Staleness: compare this timestamp with your last structural change;
regenerate after any structural change (new files, renames, API moves).

| Layer | Files | Lines | Slice |
| --- | --- | --- | --- |
$rows

_Total: $totalFiles files, ${_formatCount(totalLines)} lines indexed._
''';
}
