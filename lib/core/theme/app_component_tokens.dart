import 'package:flutter/material.dart';

import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_theme_extensions.dart';

class AppComponentTokens {
  AppComponentTokens._();

  static BoxDecoration heroCard(BuildContext context) {
    final tokens = context.premiumTokens;
    return BoxDecoration(
      borderRadius: AppRadii.hero,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[tokens.colors.hero, tokens.colors.emerald],
      ),
      boxShadow: tokens.heroShadow,
    );
  }

  static BoxDecoration premiumCard(BuildContext context) {
    final tokens = context.premiumTokens;
    return BoxDecoration(
      color: tokens.colors.card,
      borderRadius: AppRadii.card,
      border: Border.all(color: tokens.colors.divider),
      boxShadow: tokens.softShadow,
    );
  }

  static BoxDecoration actionTile(BuildContext context) {
    final tokens = context.premiumTokens;
    return BoxDecoration(
      color: tokens.colors.card,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
      border: Border.all(color: tokens.colors.divider),
      boxShadow: tokens.softShadow,
    );
  }

  static BoxDecoration statusBadge(BuildContext context) {
    final tokens = context.premiumTokens;
    return BoxDecoration(
      color: tokens.colors.surface,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadii.x2l)),
      border: Border.all(color: tokens.colors.divider),
    );
  }

  static NavigationBarThemeData bottomNavTheme(BuildContext context) {
    final tokens = context.premiumTokens;
    return NavigationBarThemeData(
      backgroundColor: tokens.colors.surface,
      indicatorColor: tokens.colors.gold.withValues(alpha: 0.2),
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final bool selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? tokens.colors.emerald : tokens.colors.textSecondary,
        );
      }),
    );
  }

  static FloatingActionButtonThemeData floatingButton(BuildContext context) {
    final tokens = context.premiumTokens;
    return FloatingActionButtonThemeData(
      backgroundColor: tokens.colors.hero,
      foregroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.x2l)),
      ),
      elevation: 0,
      extendedPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
    );
  }
}
