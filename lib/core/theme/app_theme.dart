import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../motion/app_motion.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_theme_extensions.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData lightForLocale({Locale? locale}) =>
      _build(Brightness.light, locale: locale);
  static ThemeData darkForLocale({Locale? locale}) =>
      _build(Brightness.dark, locale: locale);

  static ThemeData _build(Brightness brightness, {Locale? locale}) {
    final bool isDark = brightness == Brightness.dark;
    final AppColorTokens c = isDark ? AppColors.dark : AppColors.light;
    final PremiumThemeTokens preset = isDark
        ? PremiumThemePresets.dark
        : PremiumThemePresets.light;
    final String family = AppTypography.familyFor(locale);
    final TextTheme textTheme = AppTypography.build(
      brightness: brightness,
      locale: locale,
    );
    final Typography baseTypography = Typography.material2021(
      platform: defaultTargetPlatform,
    );

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: c.emerald,
      onPrimary: AppColors.white,
      secondary: c.gold,
      onSecondary: isDark ? AppColors.black : AppColors.white,
      error: c.danger,
      onError: AppColors.white,
      surface: c.surface,
      onSurface: c.primaryText,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: family,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.primarySurface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      typography: baseTypography,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
          TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
        },
      ),
      dividerColor: c.border,
      extensions: <ThemeExtension<dynamic>>[preset],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: c.primarySurface,
        foregroundColor: c.primaryText,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        toolbarTextStyle: textTheme.titleMedium,
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge,
          foregroundColor: c.emerald,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      chipTheme: ChipThemeData(
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        side: BorderSide(color: c.border),
        backgroundColor: c.secondarySurface,
        selectedColor: c.gold.withValues(alpha: isDark ? 0.18 : 0.22),
      ),
      dataTableTheme: DataTableThemeData(
        dataTextStyle: textTheme.bodyMedium,
        headingTextStyle: textTheme.titleMedium,
      ),
      menuTheme: const MenuThemeData(),
      tooltipTheme: TooltipThemeData(
        textStyle: textTheme.bodySmall?.copyWith(color: AppColors.white),
        decoration: BoxDecoration(
          color: c.primaryText,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: c.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
          borderSide: BorderSide(color: c.emerald, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        filled: true,
        fillColor: c.secondarySurface,
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.secondaryText),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadii.sm)),
            ),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.heroSurface,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.secondarySurface,
        indicatorColor: c.gold.withValues(alpha: isDark ? 0.18 : 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.emerald : c.secondaryText,
          );
        }),
      ),
    );
  }
}
