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
