import 'package:flutter/material.dart';

class ClipMindColors {
  ClipMindColors._();

  static const Color bgBase = Color(0xFF0D0D10);
  static const Color bgSurface = Color(0xFF18181C);
  static const Color bgElevated = Color(0xFF1E1E24);
  static const Color accentPrimary = Color(0xFF6C63FF);
  static const Color accentHover = Color(0xFF7B73FF);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF9090A0);
  static const Color textMuted = Color(0xFF606070);
  static const Color borderColor = Color(0xFF2A2A30);
  static const Color trackVideo = Color(0xFF7C3AED);
  static const Color trackAudio = Color(0xFF22C55E);
  static const Color trackText = Color(0xFF3B82F6);
  static const Color trackFx = Color(0xFFEF4444);
  static const Color statusReady = Color(0xFF22C55E);
  static const Color statusError = Color(0xFFEF4444);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color surfaceCard = Color(0xFF202024);
  static const Color surfaceHover = Color(0xFF26262C);
}

class ClipMindTheme {
  ClipMindTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ClipMindColors.bgBase,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        surface: ClipMindColors.bgBase,
        primary: ClipMindColors.accentPrimary,
        secondary: ClipMindColors.accentPrimary,
        onSurface: ClipMindColors.textPrimary,
        error: ClipMindColors.statusError,
      ),
      cardColor: ClipMindColors.bgSurface,
      dividerColor: ClipMindColors.borderColor,
      appBarTheme: AppBarTheme(
        backgroundColor: ClipMindColors.bgBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: ClipMindColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: ClipMindColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: ClipMindColors.textPrimary,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ClipMindColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ClipMindColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: ClipMindColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: ClipMindColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: ClipMindColors.textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ClipMindColors.textPrimary,
          letterSpacing: -0.2,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: ClipMindColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ClipMindColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ClipMindColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ClipMindColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ClipMindColors.accentPrimary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: TextStyle(color: ClipMindColors.textMuted),
      ),
      iconTheme: IconThemeData(
        color: ClipMindColors.textSecondary,
        size: 20,
      ),
    );
  }
}
