import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static TextTheme build(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final Color primary = dark ? const Color(0xFFF3F5F8) : const Color(0xFF0F1720);
    final Color secondary = dark ? const Color(0xFFB7C3CF) : const Color(0xFF5C6675);

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 54,
        height: 1.06,
        letterSpacing: -1.0,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontSize: 44,
        height: 1.1,
        letterSpacing: -0.7,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      displaySmall: TextStyle(
        fontSize: 34,
        height: 1.12,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.3,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );
  }
}
