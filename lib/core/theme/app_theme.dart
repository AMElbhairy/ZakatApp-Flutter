import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
      onPrimary: Colors.white,
      secondary: c.gold,
      onSecondary: isDark ? Colors.black : Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: family,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      typography: baseTypography,
      dividerColor: c.divider,
      extensions: <ThemeExtension<dynamic>>[preset],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
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
        side: BorderSide(color: c.divider),
        backgroundColor: c.surface,
        selectedColor: c.gold.withValues(alpha: isDark ? 0.18 : 0.22),
      ),
      dataTableTheme: DataTableThemeData(
        dataTextStyle: textTheme.bodyMedium,
        headingTextStyle: textTheme.titleMedium,
      ),
      menuTheme: const MenuThemeData(),
      tooltipTheme: TooltipThemeData(
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        decoration: BoxDecoration(
          color: c.textPrimary,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: c.divider),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
          borderSide: BorderSide(color: c.divider),
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
        fillColor: c.surface,
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
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
        backgroundColor: c.hero,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.gold.withValues(alpha: isDark ? 0.18 : 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.emerald : c.textSecondary,
          );
        }),
      ),
    );
  }
}
