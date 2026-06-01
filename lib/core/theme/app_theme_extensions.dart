import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shadows.dart';

@immutable
class PremiumThemeTokens extends ThemeExtension<PremiumThemeTokens> {
  const PremiumThemeTokens({
    required this.colors,
    required this.softShadow,
    required this.mediumShadow,
    required this.heroShadow,
    required this.floatingShadow,
  });

  final AppColorTokens colors;
  final List<BoxShadow> softShadow;
  final List<BoxShadow> mediumShadow;
  final List<BoxShadow> heroShadow;
  final List<BoxShadow> floatingShadow;

  @override
  PremiumThemeTokens copyWith({
    AppColorTokens? colors,
    List<BoxShadow>? softShadow,
    List<BoxShadow>? mediumShadow,
    List<BoxShadow>? heroShadow,
    List<BoxShadow>? floatingShadow,
  }) {
    return PremiumThemeTokens(
      colors: colors ?? this.colors,
      softShadow: softShadow ?? this.softShadow,
      mediumShadow: mediumShadow ?? this.mediumShadow,
      heroShadow: heroShadow ?? this.heroShadow,
      floatingShadow: floatingShadow ?? this.floatingShadow,
    );
  }

  @override
  PremiumThemeTokens lerp(covariant ThemeExtension<PremiumThemeTokens>? other, double t) {
    if (other is! PremiumThemeTokens) return this;
    return t < 0.5 ? this : other;
  }
}

extension PremiumThemeX on BuildContext {
  PremiumThemeTokens get premiumTokens => Theme.of(this).extension<PremiumThemeTokens>()!;
}

class PremiumThemePresets {
  PremiumThemePresets._();

  static const PremiumThemeTokens light = PremiumThemeTokens(
    colors: AppColors.light,
    softShadow: AppShadows.lightSoft,
    mediumShadow: AppShadows.lightMedium,
    heroShadow: AppShadows.lightHero,
    floatingShadow: AppShadows.lightFloating,
  );

  static const PremiumThemeTokens dark = PremiumThemeTokens(
    colors: AppColors.dark,
    softShadow: AppShadows.darkSoft,
    mediumShadow: AppShadows.darkMedium,
    heroShadow: AppShadows.darkHero,
    floatingShadow: AppShadows.darkFloating,
  );
}
