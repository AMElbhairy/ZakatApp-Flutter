import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String englishFamily = 'Inter';
  static const String arabicFamily = 'IBMPlexSansArabic';

  static bool isArabicLocale(Locale? locale) {
    return locale?.languageCode.toLowerCase() == 'ar';
  }

  static String familyFor(Locale? locale) {
    return isArabicLocale(locale) ? arabicFamily : englishFamily;
  }

  static TextTheme build({
    required Brightness brightness,
    required Locale? locale,
  }) {
    final String family = familyFor(locale);
    final String fallback = isArabicLocale(locale)
        ? englishFamily
        : arabicFamily;
    final Color primary = brightness == Brightness.dark
        ? const Color(0xFFF3F5F8)
        : const Color(0xFF0F1720);
    final Color secondary = brightness == Brightness.dark
        ? const Color(0xFFB7C3CF)
        : const Color(0xFF5C6675);

    return TextTheme(
      displayLarge: displayLarge(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      displayMedium: displayMedium(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      displaySmall: displaySmall(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      headlineLarge: headlineLarge(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      headlineMedium: headlineMedium(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      headlineSmall: headlineSmall(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      titleLarge: titleLarge(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      titleMedium: titleMedium(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      titleSmall: titleSmall(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      bodyLarge: bodyLarge(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      bodyMedium: bodyMedium(
        color: secondary,
        family: family,
        fallbackFamily: fallback,
      ),
      bodySmall: bodySmall(
        color: secondary,
        family: family,
        fallbackFamily: fallback,
      ),
      labelLarge: labelLarge(
        color: primary,
        family: family,
        fallbackFamily: fallback,
      ),
      labelMedium: labelMedium(
        color: secondary,
        family: family,
        fallbackFamily: fallback,
      ),
      labelSmall: labelSmall(
        color: secondary,
        family: family,
        fallbackFamily: fallback,
      ),
    );
  }

  static TextStyle displayLarge({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 30,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle pageTitle({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 30,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle displayMediumStyle({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return displayMedium(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle sectionTitle({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return headlineLarge(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle cardTitle({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return titleLarge(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle cardSubtitle({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return bodyMedium(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle body({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return bodyLarge(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle caption({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return bodySmall(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle label({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return labelMedium(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle button({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return labelLarge(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle chip({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return labelSmall(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle badge({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return labelSmall(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle navigationLabel({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return labelSmall(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle navigationLabelCompact({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 10.5,
      height: 1.2,
      fontWeight: FontWeight.w500,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle financialAmountXLStyle({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return financialValue(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
      large: true,
    );
  }

  static TextStyle financialAmountLargeStyle({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return financialValue(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
      large: false,
    );
  }

  static TextStyle financialAmountStyle({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return financialStat(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle dialogTitle({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return titleLarge(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle dialogBody({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return bodyLarge(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle tableHeader({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return titleMedium(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle tableCell({
    required Color color,
    required String family,
    required String fallbackFamily,
    bool bold = false,
  }) {
    return bodyMedium(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    ).copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w500);
  }

  static TextStyle emptyState({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return bodyLarge(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle error({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return bodyMedium(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle helper({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return bodySmall(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle hint({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return bodyMedium(
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle displayMedium({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 28,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle displaySmall({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 26,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle headlineLarge({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle headlineMedium({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 20,
      height: 1.22,
      fontWeight: FontWeight.w600,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle headlineSmall({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 18,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle titleLarge({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 18,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle titleMedium({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 17,
      height: 1.28,
      fontWeight: FontWeight.w500,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle titleSmall({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 15,
      height: 1.32,
      fontWeight: FontWeight.w500,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle bodyLarge({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 15,
      height: 1.42,
      fontWeight: FontWeight.w400,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle bodyMedium({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle bodySmall({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle labelLarge({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle labelMedium({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w400,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle labelSmall({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w400,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle financialValue({
    required Color color,
    required String family,
    required String fallbackFamily,
    bool large = true,
  }) {
    return _base(
      fontSize: large ? 34 : 30,
      height: 1.08,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle financialStat({
    required Color color,
    required String family,
    required String fallbackFamily,
  }) {
    return _base(
      fontSize: 20,
      height: 1.18,
      fontWeight: FontWeight.w600,
      color: color,
      family: family,
      fallbackFamily: fallbackFamily,
    );
  }

  static TextStyle monospace({
    required Color color,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: 1.35,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle _base({
    required double fontSize,
    required double height,
    required FontWeight fontWeight,
    required Color color,
    required String family,
    required String fallbackFamily,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: <String>[fallbackFamily],
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }
}
