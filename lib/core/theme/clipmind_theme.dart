import 'package:flutter/material.dart';

class ClipMindColors {
  ClipMindColors._();

  static const Color bgBase = Color(0xFF0B0F14);
  static const Color bgSurface = Color(0xFF111820);
  static const Color bgElevated = Color(0xFF17212B);
  static const Color accentPrimary = Color(0xFF38D9C3);
  static const Color accentHover = Color(0xFF5AE6D4);
  static const Color accentSoft = Color(0x2638D9C3);
  static const Color textPrimary = Color(0xFFF4F7FA);
  static const Color textSecondary = Color(0xFF9CAAB8);
  static const Color textMuted = Color(0xFF697786);
  static const Color borderColor = Color(0xFF253342);
  static const Color trackVideo = Color(0xFF4F8CFF);
  static const Color trackAudio = Color(0xFF35C779);
  static const Color trackText = Color(0xFFE7B84E);
  static const Color trackFx = Color(0xFFFF6B8A);
  static const Color statusReady = Color(0xFF35C779);
  static const Color statusError = Color(0xFFFF5C6C);
  static const Color statusWarning = Color(0xFFE7B84E);
  static const Color surfaceCard = Color(0xFF151E27);
  static const Color surfaceHover = Color(0xFF1B2733);
}

class ClipMindTheme {
  ClipMindTheme._();

  static const _radius = 8.0;

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ClipMindColors.bgBase,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        surface: ClipMindColors.bgBase,
        primary: ClipMindColors.accentPrimary,
        secondary: ClipMindColors.accentPrimary,
        onSurface: ClipMindColors.textPrimary,
        error: ClipMindColors.statusError,
      ),
      cardColor: ClipMindColors.bgSurface,
      dividerColor: ClipMindColors.borderColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: ClipMindColors.bgBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: ClipMindColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: ClipMindColors.textPrimary,
          letterSpacing: 0,
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: ClipMindColors.textPrimary,
          letterSpacing: 0,
        ),
        displaySmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ClipMindColors.textPrimary,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ClipMindColors.textPrimary,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ClipMindColors.textPrimary,
          letterSpacing: 0,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: ClipMindColors.textPrimary,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: ClipMindColors.textSecondary,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: ClipMindColors.textMuted,
          letterSpacing: 0,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ClipMindColors.textPrimary,
          letterSpacing: 0,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: ClipMindColors.textMuted,
          letterSpacing: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ClipMindColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: ClipMindColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: ClipMindColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(
            color: ClipMindColors.accentPrimary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: ClipMindColors.textMuted),
      ),
      iconTheme: const IconThemeData(
        color: ClipMindColors.textSecondary,
        size: 20,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ClipMindColors.bgElevated,
        contentTextStyle: const TextStyle(color: ClipMindColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ClipMindColors.accentPrimary,
          foregroundColor: ClipMindColors.bgBase,
          disabledBackgroundColor: ClipMindColors.bgElevated,
          disabledForegroundColor: ClipMindColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ClipMindColors.textPrimary,
          side: const BorderSide(color: ClipMindColors.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ClipMindColors.accentPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ClipMindColors.textSecondary,
          disabledForegroundColor: ClipMindColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ClipMindColors.bgElevated,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: ClipMindColors.borderColor),
        ),
        textStyle: const TextStyle(
          color: ClipMindColors.textPrimary,
          fontSize: 12,
        ),
      ),
    );
  }
}
