/// FFmpeg filter string escaping and validation helpers.
///
/// Single source of truth for safely interpolating user/LLM-provided values
/// into FFmpeg `drawtext` / `overlay` filtergraphs.
class FilterEscaping {
  static final RegExp _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// Escape text for use inside `drawtext=text='...'`.
  ///
  /// Per FFmpeg drawtext rules, the characters `\`, `'`, `:`, and `%`
  /// must be backslash-escaped. Backslashes are escaped first so existing
  /// escapes are not double-processed in the wrong order.
  static String escapeDrawtext(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(':', r'\:')
        .replaceAll('%', r'\%');
  }

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

  /// Escape a subtitle file path for `subtitles=filename='...'`.
  ///
  /// Standard FFmpeg-on-Windows practice: normalize `\` to `/` first
  /// (FFmpeg accepts forward slashes on Windows), then escape `'` and
  /// `:` (the filter value separator) with `\`. The caller wraps the
  /// result in single quotes, which protects `[]=;,` inside the value.
  /// Verify visually on a live run.
  static String escapeSubtitlePath(String path) {
    return path
        .replaceAll(r'\', '/')
        .replaceAll("'", r"\'")
        .replaceAll(':', r'\:');
  }

  /// Escape an app-resolved font file path for `drawtext:fontfile=...`.
  ///
  /// Same Windows-safe treatment as [escapeSubtitlePath]: normalize `\`
  /// to `/` (FFmpeg accepts forward slashes on Windows), then escape `'`
  /// and `:` (the filter value separator). The path is app-resolved
  /// (bundled-font extraction) — never model-provided.
  static String escapeFontFilePath(String path) {
    return path
        .replaceAll(r'\', '/')
        .replaceAll("'", r"\'")
        .replaceAll(':', r'\:');
  }

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
