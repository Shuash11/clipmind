/// FFmpeg filter string escaping and validation helpers.
///
/// Single source of truth for safely interpolating user/LLM-provided values
/// into FFmpeg `drawtext` / `overlay` filtergraphs.
class FilterEscaping {
  static final RegExp _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// Level-2 (whole filter description) escaping, shared by every escaper:
  /// double the escape backslashes FIRST, then escape `'` and the graph
  /// specials `[ ] , ;`. Apply to the LEVEL-1 output only.
  static String _escapeDescriptionLevel(String value) {
    var out = value.replaceAll(r'\', r'\\');
    out = out.replaceAll("'", r"\'");
    out = out.replaceAll('[', r'\[');
    out = out.replaceAll(']', r'\]');
    out = out.replaceAll(',', r'\,');
    out = out.replaceAll(';', r'\;');
    return out;
  }

  /// Shared unquoted path-value escaping (`drawtext:fontfile`,
  /// `subtitles:filename`). `%` and spaces are intentionally not escaped.
  static String _escapePathForFilter(String path) {
    final level1 = path
        .replaceAll(r'\', '/')
        .replaceAll("'", r"\'")
        .replaceAll(':', r'\:');
    return _escapeDescriptionLevel(level1);
  }

  /// Escape text for the UNQUOTED `drawtext=text=...` option (two levels).
  ///
  /// Per the FFmpeg Filters "Notes on filtergraph escaping" the value is
  /// interpolated without quotes, so it needs both levels:
  /// 1. Filter option value: escape `\` first, then `'`, `:`, `%`; escape
  ///    every space so leading/trailing ones survive the parser's
  ///    whitespace trimming.
  /// 2. Whole filter description: double the escape backslashes FIRST, then
  ///    escape `'` and the graph specials `[ ] , ;` (each adds a backslash
  ///    that must not be doubled).
  ///
  /// Consume via [drawtextTextOption] — the complete
  /// `text=<escaped>:expansion=none` option. `expansion=none` is mandatory:
  /// with the default expansion any `%` renders NOTHING (exit 0, blank
  /// frame; live-verified 2026-08/10 on FFmpeg 8.1.1-essentials).
  static String escapeDrawtext(String text) {
    // Level 1 — option value: '\' first, then specials; every space is
    // escaped so leading/trailing ones survive the parser's whitespace
    // trimming.
    var s = text.replaceAll(r'\', r'\\');
    s = s.replaceAll("'", r"\'");
    s = s.replaceAll(':', r'\:');
    s = s.replaceAll('%', r'\%');
    s = s.replaceAll(' ', r'\ ');
    // Level 2 — whole filter description (shared helper).
    return _escapeDescriptionLevel(s);
  }

  /// Complete unquoted drawtext text option:
  /// `text=<escaped>:expansion=none`.
  ///
  /// `expansion=none` prints the text verbatim — without it any `%` renders
  /// NOTHING (live-verified 2026-08/10 on FFmpeg 8.1.1-essentials).
  /// Consequence: literal `\x` sequences print verbatim and `%{...}`
  /// expansion is disabled for overlay text.
  static String drawtextTextOption(String text) =>
      'text=${escapeDrawtext(text)}:expansion=none';

  /// Validate a `#RRGGBB` font color. Returns the value unchanged.
  /// Throws [FilterValidationException] on mismatch.
  static String validateColor(String color) {
    if (!_hexColor.hasMatch(color)) {
      throw FilterValidationException(
        'Invalid color "$color". Expected #RRGGBB (e.g. #FFFFFF).',
      );
    }
    return color;
  }

  /// Convert `#RRGGBB` to ASS color `&H00BBGGRR` (Blue Green Red order,
  /// opposite of HTML; leading `00` alpha = opaque). Used for the
  /// `subtitles` filter `force_style` `PrimaryColour`.
  ///
  /// Validates first; throws [FilterValidationException] on mismatch.
  static String assColorFromHex(String color) {
    validateColor(color);
    final hex = color.substring(1);
    final red = hex.substring(0, 2).toUpperCase();
    final green = hex.substring(2, 4).toUpperCase();
    final blue = hex.substring(4, 6).toUpperCase();
    return '&H00$blue$green$red';
  }

  /// Escape a subtitle file path for `subtitles=filename=...`.
  ///
  /// Unquoted two-level contract (same shape as [escapeFontFilePath]):
  /// 1. Filter option value: normalize `\` to `/` (FFmpeg accepts forward
  ///    slashes on Windows), then escape `'` and `:` (the value separator).
  /// 2. Whole filter description: the escape backslashes double and the
  ///    graph specials `[ ] , ;` are escaped (shared
  ///    [_escapePathForFilter] helper).
  ///
  /// `%` and spaces are intentionally NOT escaped: no expansion applies to
  /// file paths, `%20` passes through, and interior spaces load fine
  /// (leading/trailing spaces are trimmed by the parser — accepted policy).
  ///
  /// Live-verified 2026-10-09 on FFmpeg 8.1.1-essentials: paths containing
  /// spaces, apostrophes, brackets, commas and semicolons load, including
  /// the `filename=…` + `:force_style='…'` adjacency.
  static String escapeSubtitlePath(String path) => _escapePathForFilter(path);

  /// Escape an app-resolved font file path for `drawtext:fontfile=...`.
  ///
  /// Two escaping levels per the FFmpeg Filters "Notes on filtergraph
  /// escaping", because the value is interpolated UNQUOTED:
  /// 1. Filter option value: normalize `\` to `/` (FFmpeg accepts forward
  ///    slashes on Windows), then escape `'` and `:` (the value separator).
  /// 2. Whole filter description: escape the escape characters `\` and `'`
  ///    again plus the graph specials `[ ] , ;` (backslash-doubling runs
  ///    first, before any replacement that introduces a backslash).
  ///
  /// Live-verified 2026-10-09 on FFmpeg 8.1.1-essentials with spaces,
  /// apostrophes, brackets, commas and semicolons in the directory path.
  /// `%` is intentionally NOT escaped — a bare `%` passes through this
  /// unquoted interpolation (live-verified).
  ///
  /// The path is app-resolved (bundled-font extraction) — never
  /// model-provided.
  static String escapeFontFilePath(String path) => _escapePathForFilter(path);

  /// Validate a watermark image path.
  ///
  /// Rejects path traversal (`..`) and, when [projectDir] is provided,
  /// rejects absolute paths that escape the project directory.
  /// Returns the value unchanged when valid.
  static String validateImagePath(String imagePath, {String? projectDir}) {
    final trimmed = imagePath.trim();
    if (trimmed.isEmpty) {
      throw const FilterValidationException('image_path cannot be empty.');
    }
    if (trimmed.contains('..')) {
      throw FilterValidationException(
        'Invalid image_path "$trimmed": path traversal (..) is not allowed.',
      );
    }
    if (projectDir != null && projectDir.isNotEmpty) {
      final normalizedProject =
          projectDir.replaceAll(r'\', '/').toLowerCase();
      final normalizedPath = trimmed.replaceAll(r'\', '/').toLowerCase();
      final isAbsolute = RegExp(r'^([a-z]:/|/)').hasMatch(normalizedPath);
      if (isAbsolute && !normalizedPath.startsWith(normalizedProject)) {
        throw FilterValidationException(
          'Invalid image_path "$trimmed": must be inside the project directory.',
        );
      }
    }
    return trimmed;
  }
}

/// Typed error for rejected filter values (bad color, traversal, ...).
class FilterValidationException implements Exception {
  final String message;
  const FilterValidationException(this.message);

  @override
  String toString() => message;
}
